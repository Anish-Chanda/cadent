package com.example.app

import io.flutter.plugin.common.EventChannel

object NavigationIntentBus {
    private var eventSink: EventChannel.EventSink? = null
    private var pendingTarget: String? = null

    fun attach(sink: EventChannel.EventSink?) {
        eventSink = sink
        pendingTarget?.let { target ->
            emit(target)
            pendingTarget = null
        }
    }

    fun detach() {
        eventSink = null
    }

    fun emit(target: String) {
        val event = mapOf("target" to target)
        if (eventSink == null) {
            pendingTarget = target
        } else {
            eventSink?.success(event)
        }
    }
}
