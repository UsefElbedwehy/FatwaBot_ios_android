package com.fatwabot.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.fatwabot.app.navigation.AppRoot
import com.fatwabot.core.designsystem.FatwaBotTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Swap the splash window background (Theme.FatwaBot.Splash) for the real
        // app theme once we're drawing Compose content.
        setTheme(R.style.Theme_FatwaBot)
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            FatwaBotTheme {
                AppRoot()
            }
        }
    }
}
