package com.marib.app

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.view.Display
import android.util.Log
import android.view.Window
import android.view.WindowManager

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {

    private val displayManager: DisplayManager by lazy {
        getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    }

    private val displayListener = ActiveDisplayListener()


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lockPreferredRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        displayListener.updateActiveDisplayId()
        displayManager.registerDisplayListener(displayListener, null)

        lockPreferredRefreshRate()
    }

    override fun onPause() {
        displayManager.unregisterDisplayListener(displayListener)
        super.onPause()
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
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return
        }

        val changeStrategyFieldName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            "CHANGE_FRAME_RATE_ALWAYS"


        } else {
            "CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS"
        }

        try {
            val windowClass = Window::class.java
            val setFrameRateMethod = windowClass.getMethod(
                "setFrameRate",
                Float::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType
            )

            val frameRateCompatibility = windowClass
                .getField("FRAME_RATE_COMPATIBILITY_FIXED_SOURCE")
                .getInt(null)

            val changeStrategy = windowClass
                .getField(changeStrategyFieldName)
                .getInt(null)

            setFrameRateMethod.invoke(window, refreshRate, frameRateCompatibility, changeStrategy)
        } catch (error: ReflectiveOperationException) {
            Log.w(
                TAG,
                "Unable to lock frame rate via reflection on this device",
                error
            )
        } catch (error: SecurityException) {
            Log.w(
                TAG,
                "Security manager prevented frame rate locking",
                error
            )
        }
    }

    companion object {
        private const val TAG = "MainActivity"
    }



    private inner class ActiveDisplayListener : DisplayManager.DisplayListener {
        private var activeDisplayId: Int = Display.INVALID_DISPLAY

        fun updateActiveDisplayId() {
            activeDisplayId = obtainActiveDisplay()?.displayId ?: Display.INVALID_DISPLAY
        }

        override fun onDisplayAdded(displayId: Int) = Unit

        override fun onDisplayRemoved(displayId: Int) = Unit

        override fun onDisplayChanged(displayId: Int) {
            if (displayId == activeDisplayId) {
                lockPreferredRefreshRate()
            }
        }
    }

}
