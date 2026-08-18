package com.example.remotehub.network

import android.content.Context
import com.example.remotehub.storage.TokenStorage
import okhttp3.Interceptor
import okhttp3.Response

class AuthInterceptor(
    context: Context
) : Interceptor {

    private val tokenStorage =
        TokenStorage(context.applicationContext)

    override fun intercept(
        chain: Interceptor.Chain
    ): Response {

        val request = chain.request()

        val accessToken =
            tokenStorage.getAccessToken()

        if (accessToken.isNullOrBlank()) {
            return chain.proceed(request)
        }

        val authenticatedRequest =
            request.newBuilder()
                .addHeader(
                    "Authorization",
                    "Bearer $accessToken"
                )
                .build()

        return chain.proceed(authenticatedRequest)
    }
}