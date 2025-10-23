package com.marib.app


import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.Window
import android.view.WindowManager

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lockPreferredRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        lockPreferredRefreshRate()
    }

    private fun lockPreferredRefreshRate() {
        val targetDisplay = obtainActiveDisplay() ?: return
        val supportedModes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            targetDisplay.supportedModes
        } else {
            return
        }

        val highestRefreshRateMode = supportedModes.maxByOrNull { it.refreshRate } ?: return

        val currentAttributes = window.attributes
        var attributesUpdated = false

        if (currentAttributes.preferredDisplayModeId != highestRefreshRateMode.modeId) {
            currentAttributes.preferredDisplayModeId = highestRefreshRateMode.modeId
            attributesUpdated = true
        }

        if (currentAttributes.preferredRefreshRate != highestRefreshRateMode.refreshRate) {
            currentAttributes.preferredRefreshRate = highestRefreshRateMode.refreshRate
            attributesUpdated = true
        }

        if (attributesUpdated) {
            window.attributes = currentAttributes
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lockFrameRateForModernDevices(highestRefreshRateMode.refreshRate)
        }
    }

    private fun obtainActiveDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
    }

    private fun lockFrameRateForModernDevices(refreshRate: Float) {
        val changeStrategy = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Window.CHANGE_FRAME_RATE_ALWAYS
        } else {
            Window.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS
        }

        window.setFrameRate(
            refreshRate,
            Window.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
            changeStrategy
        )
    }
}
