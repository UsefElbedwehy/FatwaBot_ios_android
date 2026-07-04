package com.fatwabot.app.di

import com.fatwabot.app.location.SystemLocationProvider
import com.fatwabot.feature.prayer.LocationProviding
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
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
    }
}
