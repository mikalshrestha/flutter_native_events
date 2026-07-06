package com.flutter_native_events

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import kotlin.test.Test

internal class FlutterNativeEventsPluginTest {
    @Test
    fun emitDispatchesToBridgeListener() {
        val plugin = FlutterNativeEventsPlugin()
        val result: MethodChannel.Result = mock(MethodChannel.Result::class.java)
        var received: NativeEvent? = null

        NativeEventsBridge.on("logout") { event ->
            received = event
        }

        plugin.onMethodCall(
            MethodCall("emit", mapOf("name" to "logout", "data" to mapOf("reason" to "manual"))),
            result
        )

        verify(result).success(null)
        assert(received?.data?.get("reason") == "manual")
        NativeEventsBridge.off("logout")
    }
}
