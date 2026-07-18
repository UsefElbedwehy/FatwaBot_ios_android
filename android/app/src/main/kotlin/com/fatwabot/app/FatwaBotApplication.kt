package com.fatwabot.app

import android.app.Application
import com.fatwabot.app.auth.CurrentActivityHolder
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject

@HiltAndroidApp
class FatwaBotApplication : Application() {
    /** Supplies the foreground Activity to Credential Manager (Google Sign-In). */
    @Inject
    lateinit var activityHolder: CurrentActivityHolder

    override fun onCreate() {
        super.onCreate()
        registerActivityLifecycleCallbacks(activityHolder)
    }
}
