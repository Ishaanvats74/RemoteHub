package com.example.remotehub.network

import retrofit2.Response
import retrofit2.http.Field
import retrofit2.http.FormUrlEncoded
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Body
import retrofit2.http.Path



interface ApiService {

    // =========================
    // Authentication
    // =========================

    @FormUrlEncoded
    @POST("token")
    suspend fun login(
        @Field("username") email: String,
        @Field("password") password: String
    ): Response<TokenResponse>


    @POST("auth/register")
    suspend fun register(
        @Body request: RegisterRequest
    ): Response<MessageResponse>


    @POST("auth/refresh")
    suspend fun refreshToken(
        @Body request: RefreshRequest
    ): Response<AccessTokenResponse>


    @POST("auth/logout")
    suspend fun logout(
        @Body request: RefreshRequest
    ): Response<MessageResponse>


    @GET("users/me/")
    suspend fun getCurrentUser(): Response<UserResponse>


    // =========================
    // Devices
    // =========================

    @GET("devices")
    suspend fun getDevices(): Response<List<DeviceResponse>>


    @GET("devices/{deviceId}")
    suspend fun getDevice(
        @Path("deviceId") deviceId: String
    ): Response<DeviceResponse>


    @GET("devices/{deviceId}/telemetry")
    suspend fun getDeviceTelemetry(
        @Path("deviceId") deviceId: String
    ): Response<Map<String, Any>>
}