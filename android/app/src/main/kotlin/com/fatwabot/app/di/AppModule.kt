package com.fatwabot.app.di

import android.content.Context
import com.fatwabot.app.location.SystemLocationProvider
import com.fatwabot.core.config.ConfigService
import com.fatwabot.core.config.FileConfigStore
import com.fatwabot.core.network.AccountService
import com.fatwabot.core.network.AccountServicing
import com.fatwabot.core.network.ApiClient
import com.fatwabot.core.network.ApiClientProtocol
import com.fatwabot.app.auth.CompositeCredentialProvider
import com.fatwabot.app.auth.CurrentActivityHolder
import com.fatwabot.app.auth.GoogleCredentialProvider
import com.fatwabot.core.network.ProviderCredentialProviding
import com.fatwabot.core.network.AuthService
import com.fatwabot.core.network.AuthTokenProviding
import com.fatwabot.core.network.AuthenticatedApiClient
import com.fatwabot.core.network.AuthenticatedApiClientProtocol
import com.fatwabot.core.network.ClientContext
import com.fatwabot.core.network.DeviceInfo
import com.fatwabot.core.network.EncryptedPrefsAuthTokenStore
import com.fatwabot.core.common.ActivityEventRecording
import com.fatwabot.core.common.AuthTokenStoring
import com.fatwabot.core.common.GamificationWidgetSnapshotStore
import com.fatwabot.core.common.OnboardingCompletionStore
import com.fatwabot.core.common.SearchHistoryRecording
import com.fatwabot.feature.gamification.ActivityEventQueueStoring
import com.fatwabot.feature.gamification.FileActivityEventQueueStore
import com.fatwabot.feature.gamification.GamificationEventRecorder
import com.fatwabot.feature.gamification.GamificationViewModel
import com.fatwabot.feature.searchhistory.SearchHistoryRecorder
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import com.fatwabot.core.prayer.PrayerNotificationPreferences
import com.fatwabot.core.prayer.WidgetSnapshotStore
import com.fatwabot.feature.prayer.LocationProviding
import com.fatwabot.feature.prayer.PrayerNotificationScheduler
import com.fatwabot.feature.prayer.PrayerViewModel
import com.fatwabot.widget.DailyChallengeWidget
import com.fatwabot.widget.GamificationWidgetSnapshotAccess
import com.fatwabot.widget.StreakWidget
import com.fatwabot.app.tasbeeh.SystemHaptics
import com.fatwabot.core.common.HapticsProviding
import com.fatwabot.core.content.ContentFileStore
import com.fatwabot.core.content.ContentService
import com.fatwabot.feature.azkar.AzkarStoring
import com.fatwabot.feature.azkar.FileAzkarStore
import com.fatwabot.feature.awrad.FileWirdStore
import com.fatwabot.feature.awrad.WirdStoring
import com.fatwabot.feature.dua.DuaStoring
import com.fatwabot.feature.dua.FileDuaStore
import com.fatwabot.feature.hadith.FileHadithStore
import com.fatwabot.feature.hadith.HadithStoring
import com.fatwabot.feature.prayer.notificationString
import com.fatwabot.feature.tasbeeh.FileTasbeehHistoryStore
import com.fatwabot.feature.tasbeeh.TasbeehHistoryStoring
import com.fatwabot.widget.HijriDateWidget
import com.fatwabot.widget.NextPrayerWidget
import com.fatwabot.widget.PrayerDayWidget
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
            baseUrl = "https://nbeobnlgsbokomvkmzeq.supabase.co/functions/v1/api",
            context = ClientContext(
                appVersion = com.fatwabot.app.BuildConfig.VERSION_NAME,
                locale = Locale.getDefault().language,
            ),
        )

        @Provides
        @Singleton
        fun provideAuthTokenStore(@ApplicationContext context: Context): AuthTokenStoring =
            EncryptedPrefsAuthTokenStore(context)

        @Provides
        @Singleton
        fun provideAuthService(
            @ApplicationContext context: Context,
            store: AuthTokenStoring,
        ): AuthTokenProviding = AuthService(
            // Placeholder until the Supabase project exists (OPEN_QUESTIONS Q8).
            baseUrl = "https://nbeobnlgsbokomvkmzeq.supabase.co/functions/v1/api",
            device = DeviceInfo(
                platform = "android",
                appVersion = com.fatwabot.app.BuildConfig.VERSION_NAME,
                locale = Locale.getDefault().language,
                timezone = java.util.TimeZone.getDefault().id,
            ),
            store = store,
            nowEpochSeconds = { System.currentTimeMillis() / 1000 },
        )

        @Provides
        @Singleton
        fun provideAuthenticatedApiClient(tokens: AuthTokenProviding): AuthenticatedApiClientProtocol =
            AuthenticatedApiClient(
                baseUrl = "https://nbeobnlgsbokomvkmzeq.supabase.co/functions/v1/api",
                context = ClientContext(
                    appVersion = com.fatwabot.app.BuildConfig.VERSION_NAME,
                    locale = Locale.getDefault().language,
                ),
                tokens = tokens,
            )

        @Provides
        @Singleton
        fun provideAccountService(client: AuthenticatedApiClientProtocol): AccountServicing =
            AccountService(client)

        /** Real Google Sign-In via Credential Manager; Apple has no native
         * Android SDK so the composite reports it unconfigured and the UI
         * hides that button. */
        @Provides
        @Singleton
        fun provideProviderCredential(
            @ApplicationContext context: Context,
            activityHolder: CurrentActivityHolder,
        ): ProviderCredentialProviding =
            CompositeCredentialProvider(
                google = GoogleCredentialProvider(context, activityHolder),
            )

        @Provides
        @Singleton
        fun provideActivityEventQueueStore(
            @ApplicationContext context: Context,
        ): ActivityEventQueueStoring = FileActivityEventQueueStore(File(context.filesDir, "gamification-event-queue.json"))

        @Provides
        @Singleton
        fun provideGamificationEventRecorder(
            queueStore: ActivityEventQueueStoring,
            client: AuthenticatedApiClientProtocol,
        ): GamificationEventRecorder = GamificationEventRecorder(queueStore, client)

        @Provides
        @Singleton
        fun provideActivityEventRecording(recorder: GamificationEventRecorder): ActivityEventRecording = recorder

        @Provides
        @Singleton
        fun provideSearchHistoryRecorder(client: AuthenticatedApiClientProtocol): SearchHistoryRecorder =
            SearchHistoryRecorder(client)

        @Provides
        @Singleton
        fun provideSearchHistoryRecording(recorder: SearchHistoryRecorder): SearchHistoryRecording = recorder

        @Provides
        @Singleton
        fun provideGamificationWidgetStore(
            @ApplicationContext context: Context,
        ): GamificationWidgetSnapshotStore = GamificationWidgetSnapshotAccess.store(context)

        @Provides
        fun provideGamificationWidgetRefresh(
            @ApplicationContext context: Context,
        ): GamificationViewModel.WidgetRefresh = GamificationViewModel.WidgetRefresh {
            CoroutineScope(Dispatchers.Default).launch {
                StreakWidget().updateAll(context)
                DailyChallengeWidget().updateAll(context)
            }
        }

        @Provides
        @Singleton
        fun provideOnboardingCompletionStore(
            @ApplicationContext context: Context,
        ): OnboardingCompletionStore = OnboardingCompletionStore(File(context.filesDir, "onboarding-completion.json"))

        @Provides
        @Singleton
        fun provideNotificationPreferenceStore(
            @ApplicationContext context: Context,
        ): com.fatwabot.feature.prayer.NotificationPreferenceStore =
            com.fatwabot.feature.prayer.NotificationPreferenceStore(context)

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
                PrayerDayWidget().updateAll(context)
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
        fun provideHaptics(@ApplicationContext context: Context): HapticsProviding = SystemHaptics(context)

        @Provides
        @Singleton
        fun provideTasbeehHistoryStore(
            @ApplicationContext context: Context,
        ): TasbeehHistoryStoring = FileTasbeehHistoryStore(File(context.filesDir, "tasbeeh-history.json"))

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

        @Provides
        @Singleton
        fun provideContentService(
            @ApplicationContext context: Context,
            client: ApiClientProtocol,
        ): ContentService = ContentService(
            store = ContentFileStore(File(context.filesDir, "content")),
            client = client,
        )

        @Provides
        @Singleton
        fun provideAzkarStore(
            @ApplicationContext context: Context,
        ): AzkarStoring = FileAzkarStore(File(context.filesDir, "azkar"))

        @Provides
        @Singleton
        fun provideDuaStore(
            @ApplicationContext context: Context,
        ): DuaStoring = FileDuaStore(File(context.filesDir, "dua-favorites.json"))

        @Provides
        @Singleton
        fun provideWirdStore(
            @ApplicationContext context: Context,
        ): WirdStoring = FileWirdStore(File(context.filesDir, "awrad"))

        @Provides
        @Singleton
        fun provideHadithStore(
            @ApplicationContext context: Context,
        ): HadithStoring = FileHadithStore(File(context.filesDir, "hadith-progress.json"))
    }
}
