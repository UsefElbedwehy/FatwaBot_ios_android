package com.fatwabot.feature.prayer

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import android.view.WindowManager
import androidx.core.content.getSystemService
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

/**
 * Rotation-vector-sensor-based heading — mirror of iOS SystemHeadingProvider
 * (CLLocationManager.startUpdatingHeading).
 *
 * ## Why this reports TRUE north, not magnetic
 * The qibla bearing from the adhan library is a true-north bearing, but the
 * rotation vector's azimuth is relative to *magnetic* north. Mixing the two
 * put the needle off by the local magnetic declination — up to ~20° depending
 * on where the user is, and silently, since nothing about the display says
 * which north it means. iOS never had this: `CLHeading.trueHeading` is already
 * corrected. [latitude]/[longitude] exist purely to compute that correction
 * via [GeomagneticField]; without them this falls back to magnetic north.
 */
class SystemHeadingProvider(
    private val context: Context,
    private val latitude: Double? = null,
    private val longitude: Double? = null,
) : HeadingProviding {
    private val sensorManager = context.getSystemService<SensorManager>()
    private val rotationSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

    override val supportsHeading: Boolean get() = rotationSensor != null

    override fun headings(): Flow<HeadingUpdate> = callbackFlow {
        val manager = sensorManager
        val sensor = rotationSensor
        if (manager == null || sensor == null) {
            close()
            return@callbackFlow
        }

        val declination = declinationDegrees()
        val rotationMatrix = FloatArray(9)
        val remapped = FloatArray(9)
        val orientation = FloatArray(3)
        // Smoothed on the unit circle rather than on the degree value: a plain
        // average of 359° and 1° is 180°, i.e. exactly backwards. Tracking
        // sin/cos separately makes the wrap-around a non-event.
        var smoothedSin = Double.NaN
        var smoothedCos = Double.NaN

        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                // Without this the azimuth is off by 90° in landscape: the
                // rotation matrix is in the device's fixed frame, not the
                // frame the user is actually looking at.
                val (axisX, axisY) = displayAxes()
                SensorManager.remapCoordinateSystem(rotationMatrix, axisX, axisY, remapped)
                SensorManager.getOrientation(remapped, orientation)

                val magnetic = Math.toDegrees(orientation[0].toDouble())
                val trueHeading = magnetic + declination
                val radians = Math.toRadians(trueHeading)

                if (smoothedSin.isNaN()) {
                    smoothedSin = sin(radians)
                    smoothedCos = cos(radians)
                } else {
                    smoothedSin += SMOOTHING * (sin(radians) - smoothedSin)
                    smoothedCos += SMOOTHING * (cos(radians) - smoothedCos)
                }

                var azimuth = Math.toDegrees(atan2(smoothedSin, smoothedCos))
                if (azimuth < 0) azimuth += 360.0
                trySend(HeadingUpdate(heading = azimuth, accuracy = accuracyDegrees(event.accuracy)))
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
                // Was empty, so a device that went uncalibrated while held
                // still kept reporting the last good accuracy until it moved.
                //
                // Guarded on having a real reading: this fires on registration,
                // before any sample, and emitting a placeholder 0.0 there
                // yanked the needle to due north for a frame every time the
                // screen opened or the sensor re-reported its accuracy.
                if (smoothedSin.isNaN()) return
                var azimuth = Math.toDegrees(atan2(smoothedSin, smoothedCos))
                if (azimuth < 0) azimuth += 360.0
                trySend(HeadingUpdate(heading = azimuth, accuracy = accuracyDegrees(accuracy)))
            }
        }
        manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
        awaitClose { manager.unregisterListener(listener) }
    }

    private fun declinationDegrees(): Double {
        val lat = latitude ?: return 0.0
        val lon = longitude ?: return 0.0
        return GeomagneticField(
            lat.toFloat(), lon.toFloat(), 0f, System.currentTimeMillis(),
        ).declination.toDouble()
    }

    /** Axis remap pair for the current display rotation. */
    @Suppress("DEPRECATION")
    private fun displayAxes(): Pair<Int, Int> {
        val rotation = context.getSystemService<WindowManager>()?.defaultDisplay?.rotation
        return when (rotation) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
    }

    /** Maps Android's coarse accuracy tiers onto iOS's degrees-style scale
     * (negative = invalid/calibrating; large = unreliable/interference).
     *
     * UNRELIABLE is deliberately NOT mapped to a negative value: many devices
     * report it for the rotation vector indefinitely even while the compass
     * works fine, which pinned the "move the device in a figure 8" banner on
     * permanently. It maps to the interference tier instead — a warning, not a
     * claim that there is no reading at all. Only "no sample yet" is negative. */
    private fun accuracyDegrees(accuracy: Int): Double = when (accuracy) {
        SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> 5.0
        SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> 15.0
        SensorManager.SENSOR_STATUS_ACCURACY_LOW -> 40.0
        SensorManager.SENSOR_STATUS_UNRELIABLE -> 40.0
        else -> -1.0
    }

    private companion object {
        /** Exponential-moving-average weight for the raw sensor stream. Low
         *  enough to kill the jitter CLHeading filters out for iOS, high
         *  enough that the needle still feels attached to the device. */
        const val SMOOTHING = 0.18
    }
}
