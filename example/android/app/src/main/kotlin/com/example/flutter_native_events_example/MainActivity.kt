package com.example.flutter_native_events_example

import com.flutter_native_events.NativeEventsBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeEventsBridge.on("logout") { event ->
            android.util.Log.d("NativeEventsExample", "Flutter logout: ${event.data}")
            NativeEventsBridge.sendToFlutter(
                "payment_success",
                mapOf("transactionId" to "ANDROID-TXN-123")
            )
        }

        NativeEventsBridge.onRequest("select_account") { request ->
            NativeEventsBridge.replySuccess(
                requestId = request.requestId,
                data = mapOf(
                    "accountNumber" to "1234567890",
                    "source" to "android"
                )
            )
        }

        NativeEventsBridge.onRequest("select_account_error") { request ->
            NativeEventsBridge.replyError(
                requestId = request.requestId,
                errorCode = "ACCOUNT_NOT_SELECTED",
                errorMessage = "User cancelled account selection"
            )
        }

        NativeEventsBridge.sendToFlutter(
            "native_navigation",
            mapOf("route" to "android/home")
        )
    }
}
