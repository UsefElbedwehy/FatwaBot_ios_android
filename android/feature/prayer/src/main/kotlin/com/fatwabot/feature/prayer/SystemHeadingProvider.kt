package com.fatwabot.feature.prayer

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.core.content.getSystemService
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

/** Rotation-vector-sensor-based heading — mirror of iOS SystemHeadingProvider
 * (CLLocationManager.startUpdatingHeading). */
class SystemHeadingProvider(context: Context) : HeadingProviding {
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
        val rotationMatrix = FloatArray(9)
        val orientation = FloatArray(3)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                SensorManager.getOrientation(rotationMatrix, orientation)
                var azimuth = Math.toDegrees(orientation[0].toDouble())
                if (azimuth < 0) azimuth += 360.0
                trySend(HeadingUpdate(heading = azimuth, accuracy = accuracyDegrees(event.accuracy)))
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
        awaitClose { manager.unregisterListener(listener) }
    }

    /** Maps Android's coarse accuracy tiers onto iOS's degrees-style scale
     * (negative = invalid/calibrating; large = unreliable/interference). */
    private fun accuracyDegrees(accuracy: Int): Double = when (accuracy) {
        SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> 5.0
        SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> 15.0
        SensorManager.SENSOR_STATUS_ACCURACY_LOW -> 40.0
        else -> -1.0
    }
}
