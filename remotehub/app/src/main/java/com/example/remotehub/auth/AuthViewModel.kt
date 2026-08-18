package com.example.remotehub.auth

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.remotehub.network.RetrofitClient
import com.example.remotehub.storage.TokenStorage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed class AuthOperationState {

    data object Idle : AuthOperationState()

    data object Loading : AuthOperationState()

    data object Success : AuthOperationState()

    data class Error(
        val message: String
    ) : AuthOperationState()
}

class AuthViewModel(
    application: Application
) : AndroidViewModel(application) {

    private val tokenStorage =
        TokenStorage(application.applicationContext)

    private val authRepository =
        AuthRepository(
            apiService = RetrofitClient.getApiService(
                application.applicationContext
            ),
            tokenStorage = tokenStorage
        )

    // --------------------------------
    // Authentication state
    // --------------------------------

    private val _authState =
        MutableStateFlow<AuthState>(
            AuthState.Checking
        )

    val authState: StateFlow<AuthState> =
        _authState.asStateFlow()


    // --------------------------------
    // Login state
    // --------------------------------

    private val _loginState =
        MutableStateFlow<AuthOperationState>(
            AuthOperationState.Idle
        )

    val loginState: StateFlow<AuthOperationState> =
        _loginState.asStateFlow()


    // --------------------------------
    // Register state
    // --------------------------------

    private val _registerState =
        MutableStateFlow<AuthOperationState>(
            AuthOperationState.Idle
        )

    val registerState: StateFlow<AuthOperationState> =
        _registerState.asStateFlow()


    // --------------------------------
    // Check authentication
    // --------------------------------

    fun checkAuthentication() {

        viewModelScope.launch {

            _authState.value =
                AuthState.Checking

            if (authRepository.hasTokens()) {

                _authState.value =
                    AuthState.Authenticated

            } else {

                _authState.value =
                    AuthState.Unauthenticated
            }
        }
    }


    // --------------------------------
    // Login
    // --------------------------------

    fun login(
        email: String,
        password: String
    ) {

        viewModelScope.launch {

            _loginState.value =
                AuthOperationState.Loading

            val result =
                authRepository.login(
                    email = email,
                    password = password
                )

            result.onSuccess {

                _loginState.value =
                    AuthOperationState.Success

                _authState.value =
                    AuthState.Authenticated
            }

            result.onFailure { error ->

                _loginState.value =
                    AuthOperationState.Error(
                        error.message
                            ?: "Login failed"
                    )
            }
        }
    }


    // --------------------------------
    // Register
    // --------------------------------

    fun register(
        username: String,
        email: String,
        password: String
    ) {

        viewModelScope.launch {

            _registerState.value =
                AuthOperationState.Loading

            val result =
                authRepository.register(
                    username = username,
                    email = email,
                    password = password
                )

            result.onSuccess {

                _registerState.value =
                    AuthOperationState.Success
            }

            result.onFailure { error ->

                _registerState.value =
                    AuthOperationState.Error(
                        error.message
                            ?: "Registration failed"
                    )
            }
        }
    }


    // --------------------------------
    // Refresh access token
    // --------------------------------

    fun refreshAccessToken() {

        viewModelScope.launch {

            val result =
                authRepository.refreshAccessToken()

            result.onSuccess {

                _authState.value =
                    AuthState.Authenticated
            }

            result.onFailure {

                _authState.value =
                    AuthState.Unauthenticated
            }
        }
    }


    // --------------------------------
    // Logout
    // --------------------------------

    fun logout() {

        viewModelScope.launch {

            authRepository.logout()

            _authState.value =
                AuthState.Unauthenticated
        }
    }


    // --------------------------------
    // Reset login state
    // --------------------------------

    fun resetLoginState() {

        _loginState.value =
            AuthOperationState.Idle
    }


    // --------------------------------
    // Reset register state
    // --------------------------------

    fun resetRegisterState() {

        _registerState.value =
            AuthOperationState.Idle
    }
}