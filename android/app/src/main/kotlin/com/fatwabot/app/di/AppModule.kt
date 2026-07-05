package com.fatwabot.app.di

import android.content.Context
import com.fatwabot.app.location.SystemLocationProvider
import com.fatwabot.core.config.ConfigService
import com.fatwabot.core.config.FileConfigStore
import com.fatwabot.core.network.ApiClient
import com.fatwabot.core.network.ApiClientProtocol
import com.fatwabot.core.network.ClientContext
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import com.fatwabot.core.prayer.PrayerNotificationPreferences
import com.fatwabot.core.prayer.WidgetSnapshotStore
import com.fatwabot.feature.prayer.LocationProviding
import com.fatwabot.feature.prayer.PrayerNotificationScheduler
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.feature.prayer.notificationString
import com.fatwabot.widget.HijriDateWidget
import com.fatwabot.widget.NextPrayerWidget
import com.fatwabot.widget.WidgetSnapshotAccess
import dagger.Binds
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import java.util.Locale
import javax.inject.Singleton
import kotlinx.datetime.Clock

@Module
@InstallIn(SingletonComponent::class)
abstract class AppModule {
    @Binds
    @Singleton
    abstract fun bindLocationProvider(impl: SystemLocationProvider): LocationProviding

    companion object {
        @Provides
        fun provideClock(): Clock = Clock.System

        @Provides
        @Singleton
        fun provideApiClient(): ApiClientProtocol = ApiClient(
            // Placeholder until the Supabase project exists (OPEN_QUESTIONS Q8);
            // offline-first means the app is fully functional without it.
            baseUrl = "https://api.invalid/functions/v1/api",
            context = ClientContext(
                appVersion = com.fatwabot.app.BuildConfig.VERSION_NAME,
                locale = Locale.getDefault().language,
            ),
        )

        @Provides
        fun provideNotificationPreferences(): PrayerNotificationPreferences =
            PrayerNotificationPreferences()

        @Provides
        @Singleton
        fun provideWidgetStore(
            @ApplicationContext context: Context,
        ): WidgetSnapshotStore =
            WidgetSnapshotStore(File(context.filesDir, WidgetSnapshotAccess.FILE_NAME))

        @Provides
        fun provideWidgetRefresh(
            @ApplicationContext context: Context,
        ): PrayerViewModel.WidgetRefresh = PrayerViewModel.WidgetRefresh {
            CoroutineScope(Dispatchers.Default).launch {
                NextPrayerWidget().updateAll(context)
                HijriDateWidget().updateAll(context)
            }
        }

        @Provides
        @Singleton
        fun provideNotificationScheduler(
            @ApplicationContext context: Context,
        ): PrayerNotificationScheduler = PrayerNotificationScheduler(
            context = context,
            stringProvider = { key -> notificationString(context, key) },
        )

        @Provides
        @Singleton
        fun provideConfigService(
            @ApplicationContext context: Context,
            client: ApiClientProtocol,
        ): ConfigService = ConfigService(
            store = FileConfigStore(context.filesDir),
            client = client,
            nowEpochSeconds = { System.currentTimeMillis() / 1000 },
        )
    }
}
