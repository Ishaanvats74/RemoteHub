package com.example.remotehub.auth

import com.example.remotehub.network.AccessTokenResponse
import com.example.remotehub.network.ApiError
import com.example.remotehub.network.ApiService
import com.example.remotehub.network.MessageResponse
import com.example.remotehub.network.RefreshRequest
import com.example.remotehub.network.RegisterRequest
import com.example.remotehub.network.TokenResponse
import com.example.remotehub.storage.TokenStorage

class AuthRepository(
    private val apiService: ApiService,
    private val tokenStorage: TokenStorage
) {

    suspend fun login(
        email: String,
        password: String
    ): Result<TokenResponse> {

        return try {

            val response = apiService.login(
                email = email,
                password = password
            )

            if (response.isSuccessful) {

                val tokens = response.body()

                if (tokens != null) {

                    tokenStorage.saveTokens(
                        accessToken = tokens.accessToken,
                        refreshToken = tokens.refreshToken
                    )

                    Result.success(tokens)

                } else {

                    Result.failure(
                        Exception("Empty login response")
                    )
                }

            } else {

                Result.failure(
                    Exception(
                        ApiError.getMessage(
                            response.errorBody()?.string(),
                            "Login failed"
                        )
                    )
                )
            }

        } catch (e: Exception) {

            Result.failure(
                Exception(
                    e.message ?: "Unable to connect to server"
                )
            )
        }
    }


    suspend fun register(
        username: String,
        email: String,
        password: String
    ): Result<MessageResponse> {

        return try {

            val response = apiService.register(
                RegisterRequest(
                    username = username,
                    email = email,
                    password = password
                )
            )

            if (response.isSuccessful) {

                val body = response.body()

                if (body != null) {

                    Result.success(body)

                } else {

                    Result.failure(
                        Exception("Empty registration response")
                    )
                }

            } else {

                Result.failure(
                    Exception(
                        ApiError.getMessage(
                            response.errorBody()?.string(),
                            "Registration failed"
                        )
                    )
                )
            }

        } catch (e: Exception) {

            Result.failure(
                Exception(
                    e.message ?: "Unable to connect to server"
                )
            )
        }
    }


    suspend fun refreshAccessToken(): Result<String> {

        val refreshToken =
            tokenStorage.getRefreshToken()
                ?: return Result.failure(
                    Exception("Refresh token not found")
                )

        return try {

            val response =
                apiService.refreshToken(
                    RefreshRequest(refreshToken)
                )

            if (response.isSuccessful) {

                val body = response.body()

                if (body != null) {

                    tokenStorage.updateAccessToken(
                        body.accessToken
                    )

                    Result.success(
                        body.accessToken
                    )

                } else {

                    tokenStorage.clearTokens()

                    Result.failure(
                        Exception("Empty refresh response")
                    )
                }

            } else {

                tokenStorage.clearTokens()

                Result.failure(
                    Exception(
                        ApiError.getMessage(
                            response.errorBody()?.string(),
                            "Token refresh failed"
                        )
                    )
                )
            }

        } catch (e: Exception) {

            Result.failure(
                Exception(
                    e.message ?: "Unable to connect to server"
                )
            )
        }
    }


    suspend fun logout(): Result<MessageResponse> {

        val refreshToken =
            tokenStorage.getRefreshToken()
                ?: run {

                    tokenStorage.clearTokens()

                    return Result.failure(
                        Exception("No refresh token found")
                    )
                }

        return try {

            val response =
                apiService.logout(
                    RefreshRequest(refreshToken)
                )

            tokenStorage.clearTokens()

            if (response.isSuccessful) {

                val body = response.body()

                if (body != null) {

                    Result.success(body)

                } else {

                    Result.failure(
                        Exception("Empty logout response")
                    )
                }

            } else {

                Result.failure(
                    Exception(
                        ApiError.getMessage(
                            response.errorBody()?.string(),
                            "Logout failed"
                        )
                    )
                )
            }

        } catch (e: Exception) {

            tokenStorage.clearTokens()

            Result.failure(
                Exception(
                    e.message ?: "Unable to connect to server"
                )
            )
        }
    }


    fun hasTokens(): Boolean {
        return tokenStorage.hasTokens()
    }
}