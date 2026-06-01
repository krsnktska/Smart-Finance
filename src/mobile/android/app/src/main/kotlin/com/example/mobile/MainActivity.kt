package com.example.mobile

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var initialLink: String? = null
  private var deepLinkChannel: MethodChannel? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    deepLinkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smartfinance/deep_link")
    deepLinkChannel?.setMethodCallHandler { call, result ->
      if (call.method == "getInitialLink") {
        result.success(initialLink)
      } else {
        result.notImplemented()
      }
    }
    initialLink = intent?.dataString
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    initialLink = intent.dataString
    intent.dataString?.let { link ->
      deepLinkChannel?.invokeMethod("linkChanged", link)
    }
    setIntent(intent)
  }
}
