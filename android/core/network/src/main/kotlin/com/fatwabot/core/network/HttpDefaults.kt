package com.fatwabot.core.network

import okhttp3.OkHttpClient
import java.util.concurrent.TimeUnit

/**
 * The shared OkHttp client for every API call.
 *
 * A bare `OkHttpClient()` reads with a **10 second** timeout, and AI search does
 * not fit in ten seconds: measured end to end it is 8-16s on a warm path, and
 * up to ~75s when the embedding provider throttles. So search failed on the
 * device with `Transport(detail=timeout)` while the backend was busy returning a
 * perfectly good answer nobody ever saw.
 *
 * 90s is a ceiling, not a delay — a fast endpoint still returns as fast as it
 * ever did. It is set high enough to cover a throttled search rather than only
 * a healthy one, because a user who waits a minute and then gets an answer is
 * better served than one who waits ten seconds and gets an error.
 *
 * Connect stays short: failing to reach the host at all is a different problem
 * from a slow response, and there is no reason to sit on it.
 *
 * iOS gets 60s here for free — that is `URLSession`'s default
 * `timeoutIntervalForRequest`, and NetworkingKit never overrides it. Android was
 * the outlier at 10s. (iOS is still short of the throttled worst case; worth
 * raising there too, separately.)
 */
internal fun defaultHttpClient(): OkHttpClient = OkHttpClient.Builder()
    .connectTimeout(15, TimeUnit.SECONDS)
    .readTimeout(90, TimeUnit.SECONDS)
    .writeTimeout(30, TimeUnit.SECONDS)
    .callTimeout(120, TimeUnit.SECONDS)
    .build()
