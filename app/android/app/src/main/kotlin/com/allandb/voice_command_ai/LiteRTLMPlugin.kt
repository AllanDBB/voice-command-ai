package com.allandb.voice_command_ai

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
// LiteRT-LM SDK not yet publicly released — plugin is stubbed.
// When com.google.ai.edge.litertlm:litertlm-android is available, restore full implementation.

/**
 * Stubbed LiteRT-LM plugin.
 * The SDK (com.google.ai.edge.litertlm) is not yet publicly available on Maven.
 * All calls return NOT_INITIALIZED so Dart's _staticFallback() activates automatically.
 * When the SDK ships, restore the full Engine implementation.
 */
class LiteRTLMPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "litert_lm")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "init"      -> result.success(null)  // no-op stub
            "interpret" -> result.error("NOT_INITIALIZED", "LiteRT-LM SDK not available", null)
            "dispose"   -> result.success(null)
            else        -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
