package com.example.remotehub.network

import com.google.gson.annotations.SerializedName

// =========================
// Authentication
// =========================

data class TokenResponse(
    @SerializedName("access_token")
    val accessToken: String,

    @SerializedName("refresh_token")
    val refreshToken: String,

    @SerializedName("token_type")
    val tokenType: String
)

data class RegisterRequest(
    val username: String,
    val email: String,
    val password: String
)

data class RefreshRequest(
    @SerializedName("refresh_token")
    val refreshToken: String
)

data class AccessTokenResponse(
    @SerializedName("access_token")
    val accessToken: String,

    @SerializedName("token_type")
    val tokenType: String
)

data class MessageResponse(
    val message: String
)

data class UserResponse(
    val id: String,
    val username: String,
    val email: String
)


// =========================
// Devices
// =========================

data class DeviceResponse(
    val id: String,

    @SerializedName("user_id")
    val userId: String,

    val hostname: String,
    val os: String,
    val platform: String,
    val status: String,

    @SerializedName("last_seen")
    val lastSeen: String?,

    @SerializedName("created_at")
    val createdAt: String
)