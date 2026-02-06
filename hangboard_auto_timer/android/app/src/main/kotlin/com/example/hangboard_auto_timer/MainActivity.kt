package com.example.hangboard_auto_timer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.hangboard.auto_timer/pose"
    private val EVENT_CHANNEL = "com.hangboard.auto_timer/pose_events"

    private var gestureDetector: GestureDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        var eventSink: EventChannel.EventSink? = null

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val frontCamera = call.argument<Boolean>("frontCamera") ?: true
                        try {
                            gestureDetector = GestureDetector(this@MainActivity)
                            gestureDetector?.start(frontCamera) { event ->
                                runOnUiThread {
                                    eventSink?.success(event)
                                }
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("CAMERA_ERROR", e.message, null)
                        }
                    }
                    "stop" -> {
                        gestureDetector?.stop()
                        gestureDetector = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPause() {
        super.onPause()
        gestureDetector?.pause()
    }

    override fun onResume() {
        super.onResume()
        gestureDetector?.resume()
    }

    override fun onDestroy() {
        gestureDetector?.stop()
        gestureDetector = null
        super.onDestroy()
    }
}
