package com.marib.app

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.ThermalManager
import android.view.Display
import android.util.Log
import android.view.Window
import android.view.WindowManager
import kotlin.math.abs

class MainActivity : FlutterFragmentActivity() {

    private val displayManager: DisplayManager by lazy {
        getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    }

    private val displayListener = ActiveDisplayListener()

    private val powerManager: PowerManager by lazy {
        getSystemService(Context.POWER_SERVICE) as PowerManager
    }

    private val thermalManager: ThermalManager? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getSystemService(Context.THERMAL_SERVICE) as ThermalManager
        } else {
            null
        }
    }

    private val thermalStatusListener: ThermalManager.OnThermalStatusChangedListener? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ThermalManager.OnThermalStatusChangedListener {
                lockPreferredRefreshRate()
            }
        } else {
            null
        }
    }

    private var isThermalListenerRegistered: Boolean = false


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lockPreferredRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        displayListener.updateActiveDisplayId()
        displayManager.registerDisplayListener(displayListener, null)
        registerThermalStatusListenerIfNeeded()

        lockPreferredRefreshRate()
    }

    override fun onPause() {
        unregisterThermalStatusListenerIfNeeded()
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
        val targetMode = resolveTargetRefreshRate(supportedModes, highestRefreshRateMode)

        val currentAttributes = window.attributes
        var attributesUpdated = false

        if (targetMode != null) {
            if (currentAttributes.preferredDisplayModeId != targetMode.modeId) {
                currentAttributes.preferredDisplayModeId = targetMode.modeId
                attributesUpdated = true
            }

            if (currentAttributes.preferredRefreshRate != targetMode.refreshRate) {
                currentAttributes.preferredRefreshRate = targetMode.refreshRate
                attributesUpdated = true
            }
        } else {
            if (currentAttributes.preferredDisplayModeId != 0) {
                currentAttributes.preferredDisplayModeId = 0
                attributesUpdated = true
            }

            if (currentAttributes.preferredRefreshRate != 0f) {
                currentAttributes.preferredRefreshRate = 0f
                attributesUpdated = true
            }
        }

        if (attributesUpdated) {
            window.attributes = currentAttributes
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            lockFrameRateForModernDevices(targetMode?.refreshRate)
        }
    }

    private fun resolveTargetRefreshRate(
        supportedModes: Array<Display.Mode>,
        highestRefreshRateMode: Display.Mode
    ): Display.Mode? {
        if (!shouldReduceRefreshRate()) {
            return highestRefreshRateMode
        }

        val fallbackMode = supportedModes
            .filter { it.refreshRate < highestRefreshRateMode.refreshRate }
            .minByOrNull { abs(it.refreshRate - SUSTAINED_REFRESH_RATE) }

        return fallbackMode
    }

    private fun shouldReduceRefreshRate(): Boolean {
        if (powerManager.isPowerSaveMode) {
            return true
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val manager = thermalManager
            if (manager != null) {
                val thermalStatus = manager.getCurrentThermalStatus()
                if (thermalStatus >= ThermalManager.THERMAL_STATUS_MODERATE) {
                    return true
                }
            }
        }

        return false
    }

    private fun registerThermalStatusListenerIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }

        val manager = thermalManager ?: return
        val listener = thermalStatusListener ?: return

        if (isThermalListenerRegistered) {
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            manager.registerThermalStatusListener(mainExecutor, listener)
        } else {
            @Suppress("DEPRECATION")
            manager.registerThermalStatusListener(listener)
        }

        isThermalListenerRegistered = true
    }

    private fun unregisterThermalStatusListenerIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }

        if (!isThermalListenerRegistered) {
            return
        }

        val manager = thermalManager
        val listener = thermalStatusListener

        if (manager != null && listener != null) {
            manager.unregisterThermalStatusListener(listener)
        }

        isThermalListenerRegistered = false
    }


    private fun obtainActiveDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
    }

    private fun lockFrameRateForModernDevices(refreshRate: Float?) {
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

            val frameRateCompatibilityFieldName = if (refreshRate != null && refreshRate > 0f) {
                "FRAME_RATE_COMPATIBILITY_FIXED_SOURCE"
            } else {
                "FRAME_RATE_COMPATIBILITY_DEFAULT"
            }


            val frameRateCompatibility = windowClass
                .getField(frameRateCompatibilityFieldName)
                .getInt(null)

            val changeStrategy = windowClass
                .getField(changeStrategyFieldName)
                .getInt(null)

            val targetRefreshRate = refreshRate ?: 0f

            setFrameRateMethod.invoke(window, targetRefreshRate, frameRateCompatibility, changeStrategy)

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
        private const val SUSTAINED_REFRESH_RATE = 60f

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
