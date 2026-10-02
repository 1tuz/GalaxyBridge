package com.xopmc.galaxybridge.transport

internal object FileSendPolicy {
    const val MAX_SHARE_ITEMS = 100

    fun enabled(distribution: String) = distribution == "internal" || distribution == "direct"

    fun acceptsShare(action: String?, schemes: List<String?>, itemCount: Int, hasReadGrant: Boolean): Boolean {
        val supportedCount = when (action) {
            "android.intent.action.SEND" -> itemCount == 1
            "android.intent.action.SEND_MULTIPLE" -> itemCount in 1..MAX_SHARE_ITEMS
            else -> false
        }
        return supportedCount && hasReadGrant && schemes.size == itemCount &&
            schemes.all { it == "content" }
    }
}
