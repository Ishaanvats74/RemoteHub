package com.example.remotehub.network

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName

data class ApiErrorResponse(
    @SerializedName("detail")
    val detail: String?
)

object ApiError {

    fun getMessage(
        errorBody: String?,
        fallback: String
    ): String {

        if (errorBody.isNullOrBlank()) {
            return fallback
        }

        return try {
            val error = Gson().fromJson(
                errorBody,
                ApiErrorResponse::class.java
            )

            error.detail ?: fallback

        } catch (e: Exception) {
            fallback
        }
    }
}