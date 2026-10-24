package com.memorycard.memory_card

import com.memorycard.memory_card.widgets.WidgetChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Widget previews for Settings, and the Quick Settings tile.
        WidgetChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
