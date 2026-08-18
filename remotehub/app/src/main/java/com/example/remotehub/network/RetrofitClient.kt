package com.example.remotehub.network

import android.content.Context
import okhttp3.OkHttpClient
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

object RetrofitClient {

    private const val BASE_URL = "http://10.0.2.2:8000/"

    private var retrofit: Retrofit? = null

    fun getApiService(context: Context): ApiService {

        if (retrofit == null) {

            val okHttpClient = OkHttpClient.Builder()
                .addInterceptor(
                    AuthInterceptor(context.applicationContext)
                )
                .build()

            retrofit = Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(okHttpClient)
                .addConverterFactory(
                    GsonConverterFactory.create()
                )
                .build()
        }

        return retrofit!!.create(ApiService::class.java)
    }
}