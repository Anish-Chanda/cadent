package com.example.app

import io.flutter.plugin.common.EventChannel

object TrackingEventBus {
    private var eventSink: EventChannel.EventSink? = null

    fun attach(sink: EventChannel.EventSink?) {
        eventSink = sink
        ActivityTrackingService.latestSnapshot?.let { snapshot ->
            eventSink?.success(snapshot)
        }
    }

    fun detach() {
        eventSink = null
    }

    fun emit(snapshot: Map<String, Any?>) {
        eventSink?.success(snapshot)
    }
}
