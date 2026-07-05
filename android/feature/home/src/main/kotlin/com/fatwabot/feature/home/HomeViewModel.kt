package com.fatwabot.feature.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fatwabot.core.common.HomeLayout
import com.fatwabot.core.config.ConfigService
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Resolves the server Home layout + flags (ADR-0011) — mirror of iOS HomeViewModel.
 * Unknown section types are dropped by the renderer, never here.
 */
@HiltViewModel
class HomeViewModel @Inject constructor(
    private val config: ConfigService,
) : ViewModel() {

    data class UiState(
        val layout: HomeLayout? = null,
        val askEnabled: Boolean = false,
    )

    private val _state = MutableStateFlow(UiState(layout = config.homeLayout()))
    val state: StateFlow<UiState> = _state.asStateFlow()

    fun load(appVersion: String) {
        _state.value = UiState(
            layout = config.homeLayout(),
            askEnabled = config.isEnabled("module.ai_ask", appVersion),
        )
    }

    fun refresh(appVersion: String, locales: List<String>) {
        viewModelScope.launch {
            config.refresh(locales)
            load(appVersion)
        }
    }
}
