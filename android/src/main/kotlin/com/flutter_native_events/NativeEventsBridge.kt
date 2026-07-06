package com.flutter_native_events

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

data class NativeEvent(
    val id: String,
    val name: String,
    val data: Map<String, Any?>,
    val timestamp: Long,
    val source: String
)

data class NativeEventRequest(
    val requestId: String,
    val name: String,
    val data: Map<String, Any?>,
    val timestamp: Long
)

object NativeEventsBridge {
    private val mainHandler: Handler by lazy { Handler(Looper.getMainLooper()) }
    private var eventSink: EventChannel.EventSink? = null
    private var enableLogging = false
    private val listeners = ConcurrentHashMap<String, MutableList<(NativeEvent) -> Unit>>()
    private val requestHandlers = ConcurrentHashMap<String, (NativeEventRequest) -> Unit>()
    private val pendingResults = ConcurrentHashMap<String, MethodChannel.Result>()

    internal fun configure(config: Map<*, *>?) {
        enableLogging = config?.get("enableLogging") as? Boolean ?: false
    }

    internal fun attachSink(sink: EventChannel.EventSink?) {
        mainHandler.post {
            eventSink = sink
        }
    }

    internal fun dispose() {
        attachSink(null)
        pendingResults.clear()
    }

    @JvmStatic
    fun sendToFlutter(
        name: String,
        data: Map<String, Any?> = emptyMap()
    ) {
        val event = NativeEvent(
            id = newId("evt"),
            name = name,
            data = data,
            timestamp = System.currentTimeMillis(),
            source = "android"
        )
        sendToFlutter(event)
    }

    @JvmStatic
    fun sendToFlutter(event: NativeEvent) {
        mainHandler.post {
            eventSink?.success(event.toMap())
            log("sent ${event.name}")
        }
    }

    @JvmStatic
    fun on(
        name: String,
        handler: (NativeEvent) -> Unit
    ) {
        listeners.getOrPut(name) { mutableListOf() }.add(handler)
    }

    @JvmStatic
    fun off(name: String) {
        listeners.remove(name)
    }

    @JvmStatic
    fun onRequest(
        name: String,
        handler: (NativeEventRequest) -> Unit
    ) {
        requestHandlers[name] = handler
    }

    @JvmStatic
    fun clearRequestHandler(name: String) {
        requestHandlers.remove(name)
    }

    @JvmStatic
    fun replySuccess(
        requestId: String,
        data: Map<String, Any?> = emptyMap()
    ) {
        completeRequest(
            requestId,
            mapOf(
                "requestId" to requestId,
                "success" to true,
                "data" to data
            )
        )
    }

    @JvmStatic
    fun replyError(
        requestId: String,
        errorCode: String,
        errorMessage: String
    ) {
        completeRequest(
            requestId,
            mapOf(
                "requestId" to requestId,
                "success" to false,
                "errorCode" to errorCode,
                "errorMessage" to errorMessage
            )
        )
    }

    internal fun handleFlutterEvent(arguments: Map<*, *>) {
        val event = NativeEvent(
            id = arguments["id"] as? String ?: newId("evt"),
            name = requireNotNull(arguments["name"] as? String) { "Event name is required." },
            data = sanitizeMap(arguments["data"]),
            timestamp = parseTimestamp(arguments["timestamp"]),
            source = arguments["source"] as? String ?: "flutter"
        )
        listeners[event.name]?.toList()?.forEach { handler ->
            handler(event)
        }
        log("received ${event.name}")
    }

    internal fun handleFlutterRequest(
        arguments: Map<*, *>,
        result: MethodChannel.Result
    ) {
        val request = NativeEventRequest(
            requestId = arguments["requestId"] as? String ?: "",
            name = arguments["name"] as? String ?: "",
            data = sanitizeMap(arguments["data"]),
            timestamp = parseTimestamp(arguments["timestamp"])
        )

        if (request.requestId.isBlank() || request.name.isBlank()) {
            result.error("invalid_request", "Request id and name are required.", null)
            return
        }

        val handler = requestHandlers[request.name]
        if (handler == null) {
            result.success(
                mapOf(
                    "requestId" to request.requestId,
                    "success" to false,
                    "errorCode" to "NO_HANDLER",
                    "errorMessage" to "No Android request handler registered for \"${request.name}\"."
                )
            )
            return
        }

        pendingResults[request.requestId] = result
        try {
            handler(request)
        } catch (error: Throwable) {
            pendingResults.remove(request.requestId)
            result.success(
                mapOf(
                    "requestId" to request.requestId,
                    "success" to false,
                    "errorCode" to "HANDLER_ERROR",
                    "errorMessage" to (error.message ?: "Android request handler failed.")
                )
            )
        }
    }

    private fun completeRequest(
        requestId: String,
        response: Map<String, Any?>
    ) {
        val result = pendingResults.remove(requestId) ?: return
        mainHandler.post {
            result.success(response)
            log("replied $requestId")
        }
    }

    private fun sanitizeMap(value: Any?): Map<String, Any?> {
        if (value !is Map<*, *>) return emptyMap()
        return value.entries.associate { (key, mapValue) ->
            require(key is String) { "Native event payload keys must be strings." }
            key to mapValue
        }
    }

    private fun parseTimestamp(value: Any?): Long {
        return when (value) {
            is Number -> value.toLong()
            is String -> System.currentTimeMillis()
            else -> System.currentTimeMillis()
        }
    }

    private fun NativeEvent.toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "name" to name,
        "data" to data,
        "timestamp" to timestamp,
        "source" to source
    )

    private fun newId(prefix: String): String = "$prefix-${System.currentTimeMillis()}-${UUID.randomUUID()}"

    private fun log(message: String) {
        if (enableLogging) {
            android.util.Log.d("NativeEventsBridge", message)
        }
    }
}
