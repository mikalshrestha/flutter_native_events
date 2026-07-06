package com.flutter_native_events

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlutterNativeEventsPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, "flutter_native_events/methods")
        eventChannel = EventChannel(binding.binaryMessenger, "flutter_native_events/events")

        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        when (call.method) {
            "init" -> {
                NativeEventsBridge.configure(call.arguments as? Map<*, *>)
                result.success(null)
            }
            "dispose" -> {
                NativeEventsBridge.dispose()
                result.success(null)
            }
            "emit" -> {
                val arguments = call.arguments as? Map<*, *>
                if (arguments == null) {
                    result.error("invalid_arguments", "Arguments must be a map.", null)
                    return
                }
                try {
                    NativeEventsBridge.handleFlutterEvent(arguments)
                    result.success(null)
                } catch (error: Throwable) {
                    result.error("emit_failed", error.message, null)
                }
            }
            "request" -> {
                val arguments = call.arguments as? Map<*, *>
                if (arguments == null) {
                    result.error("invalid_arguments", "Arguments must be a map.", null)
                    return
                }
                NativeEventsBridge.handleFlutterRequest(arguments, result)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        NativeEventsBridge.attachSink(events)
    }

    override fun onCancel(arguments: Any?) {
        NativeEventsBridge.attachSink(null)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        NativeEventsBridge.dispose()
    }
}
