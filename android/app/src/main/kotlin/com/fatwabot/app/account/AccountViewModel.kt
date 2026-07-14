package com.fatwabot.app.account

import androidx.lifecycle.ViewModel
import com.fatwabot.core.network.AccountException
import com.fatwabot.core.network.AccountProfile
import com.fatwabot.core.network.AccountProvider
import com.fatwabot.core.network.AccountServicing
import com.fatwabot.core.network.ProviderCredentialProviding
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Drives the account section of Settings (docs/features/accounts.md). */
@HiltViewModel
class AccountViewModel @Inject constructor(
    private val account: AccountServicing,
    private val credentials: ProviderCredentialProviding,
) : ViewModel() {
    enum class Message { NONE, ALREADY_LINKED, GENERIC }

    data class UiState(
        val profile: AccountProfile? = null,
        val isLoading: Boolean = false,
        val isBusy: Boolean = false,
        val message: Message = Message.NONE,
    ) {
        val isSignedIn: Boolean get() = profile?.isSignedIn == true
    }

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    suspend fun load() {
        if (_state.value.profile != null) return
        _state.update { it.copy(isLoading = true) }
        runCatching { account.me() }.fold(
            onSuccess = { p -> _state.update { it.copy(profile = p, isLoading = false) } },
            onFailure = { _state.update { it.copy(isLoading = false) } },
        )
    }

    suspend fun saveDisplayName(name: String) {
        _state.update { it.copy(isBusy = true, message = Message.NONE) }
        runCatching { account.updateDisplayName(name) }.fold(
            onSuccess = { p -> _state.update { it.copy(profile = p, isBusy = false) } },
            onFailure = { _state.update { it.copy(isBusy = false, message = Message.GENERIC) } },
        )
    }

    suspend fun signIn(provider: AccountProvider) {
        _state.update { it.copy(isBusy = true, message = Message.NONE) }
        runCatching {
            val token = credentials.identityToken(provider)
            account.link(provider, token)
        }.fold(
            onSuccess = { p -> _state.update { it.copy(profile = p, isBusy = false) } },
            onFailure = { error ->
                val message = if (error is AccountException.AlreadyLinked) Message.ALREADY_LINKED else Message.GENERIC
                _state.update { it.copy(isBusy = false, message = message) }
            },
        )
    }
}
