package com.marib.app

import android.content.Context
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.Display
import android.util.Log
import android.view.Window
import android.view.WindowManager
import kotlin.math.abs
import io.flutter.embedding.android.FlutterFragmentActivity
import java.lang.reflect.Method
import java.lang.reflect.Proxy
import java.util.concurrent.Executor

class MainActivity : FlutterFragmentActivity() {

    private val displayManager: DisplayManager by lazy {
        getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    }

    private val displayListener = ActiveDisplayListener()

    private val powerManager: PowerManager by lazy {
        getSystemService(Context.POWER_SERVICE) as PowerManager
    }

    private val thermalManager: Any? by lazy {
        if (!ThermalCompat.isSupported) {
            return@lazy null
        }

        val serviceName = ThermalCompat.thermalServiceName ?: return@lazy null
        getSystemService(serviceName)
    }

    private val thermalStatusListener: Any? by lazy {
        if (!ThermalCompat.isSupported) {
            return@lazy null
        }
        ThermalCompat.createListener(
            onStatusChanged = { lockPreferredRefreshRate() },
            fallbackClassLoader = javaClass.classLoader
        )
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

        if (ThermalCompat.isSupported) {
            val manager = thermalManager
            val threshold = ThermalCompat.thermalStatusModerate

            if (manager != null && threshold != null) {
                val thermalStatus = ThermalCompat.getCurrentThermalStatus(manager, TAG)
                if (thermalStatus != null && thermalStatus >= threshold) {
                    return true
                }
            }
        }

        return false
    }

    private fun registerThermalStatusListenerIfNeeded() {
        if (!ThermalCompat.isSupported) {
            return
        }

        val manager = thermalManager ?: return
        val listener = thermalStatusListener ?: return

        if (isThermalListenerRegistered) {
            return
        }

        val didRegister = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ThermalCompat.registerListener(manager, listener, mainExecutor, TAG)
        } else {
            ThermalCompat.registerListener(manager, listener, null, TAG)

        }

        if (didRegister) {
            isThermalListenerRegistered = true
        }
    }

    private fun unregisterThermalStatusListenerIfNeeded() {
        if (!ThermalCompat.isSupported) {
            return
        }

        if (!isThermalListenerRegistered) {
            return
        }

        val manager = thermalManager
        val listener = thermalStatusListener

        if (manager != null && listener != null) {
            val didUnregister = ThermalCompat.unregisterListener(manager, listener, TAG)
            if (didUnregister) {
                isThermalListenerRegistered = false
            }
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


    companion object {
        private const val TAG = "MainActivity"
        private const val SUSTAINED_REFRESH_RATE = 60f
    }

    private object ThermalCompat {
        private const val SERVICE_NAME_FALLBACK = "thermalservice"

        val isSupported: Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

        val thermalServiceName: String? = if (isSupported) {
            try {
                Context::class.java.getField("THERMAL_SERVICE").get(null) as? String
            } catch (error: ReflectiveOperationException) {
                SERVICE_NAME_FALLBACK
            }
        } else {
            null
        }
        private val managerClass: Class<*>? = if (isSupported) {
            loadClass("android.os.ThermalManager")
        } else {
            null
        }
        val thermalStatusModerate: Int? = managerClass?.let { clazz ->
            try {
                clazz.getField("THERMAL_STATUS_MODERATE").getInt(null)
            } catch (error: ReflectiveOperationException) {
                null
            }
        }


        private val listenerInterface: Class<*>? = if (isSupported) {
            loadClass("android.os.ThermalManager\$OnThermalStatusChangedListener")
        } else {
            null
        }

        private val getCurrentThermalStatusMethod: Method? = managerClass?.findMethod("getCurrentThermalStatus")

        private val registerListenerMethod: Method? = listenerInterface?.let { listenerClass ->
            managerClass?.findMethod("registerThermalStatusListener", listenerClass)
        }

        private val registerListenerWithExecutorMethod: Method? = listenerInterface?.let { listenerClass ->
            managerClass?.findMethod("registerThermalStatusListener", Executor::class.java, listenerClass)
        }

        private val unregisterListenerMethod: Method? = listenerInterface?.let { listenerClass ->
            managerClass?.findMethod("unregisterThermalStatusListener", listenerClass)
        }

        fun createListener(onStatusChanged: () -> Unit, fallbackClassLoader: ClassLoader?): Any? {
            if (!isSupported) {
                return null
            }

            val listenerClass = listenerInterface ?: return null
            val classLoader = listenerClass.classLoader ?: fallbackClassLoader ?: return null

            return Proxy.newProxyInstance(classLoader, arrayOf(listenerClass)) { _, method, _ ->
                if (method?.name == "onThermalStatusChanged") {
                    onStatusChanged()
                }
                null
            }
        }

        fun registerListener(manager: Any, listener: Any, executor: Executor?, logTag: String): Boolean {
            if (!isSupported) {
                return false
            }

            return try {
                when {
                    executor != null && registerListenerWithExecutorMethod != null -> {
                        registerListenerWithExecutorMethod.invoke(manager, executor, listener)
                        true
                    }

                    registerListenerMethod != null -> {
                        registerListenerMethod.invoke(manager, listener)
                        true
                    }

                    else -> false
                }
            } catch (error: ReflectiveOperationException) {
                Log.w(logTag, "Unable to register thermal status listener via reflection", error)
                false
            } catch (error: SecurityException) {
                Log.w(logTag, "Security manager prevented registering thermal status listener", error)
                false
            }
        }

        fun unregisterListener(manager: Any, listener: Any, logTag: String): Boolean {
            if (!isSupported) {
                return false
            }

            val method = unregisterListenerMethod ?: return false

            return try {
                method.invoke(manager, listener)
                true
            } catch (error: ReflectiveOperationException) {
                Log.w(logTag, "Unable to unregister thermal status listener via reflection", error)
                false
            } catch (error: SecurityException) {
                Log.w(logTag, "Security manager prevented unregistering thermal status listener", error)
                false
            }
        }

        fun getCurrentThermalStatus(manager: Any, logTag: String): Int? {
            if (!isSupported) {
                return null
            }

            val method = getCurrentThermalStatusMethod ?: return null

            return try {
                method.invoke(manager) as? Int
            } catch (error: ReflectiveOperationException) {
                Log.w(logTag, "Unable to read current thermal status via reflection", error)
                null
            } catch (error: SecurityException) {
                Log.w(logTag, "Security manager prevented reading thermal status", error)
                null
            }
        }

        private fun loadClass(name: String): Class<*>? {
            return try {
                Class.forName(name)
            } catch (error: ClassNotFoundException) {
                null
            } catch (error: LinkageError) {
                null
            }
        }

        private fun Class<*>.findMethod(name: String, vararg parameterTypes: Class<*>): Method? {
            return try {
                getMethod(name, *parameterTypes)
            } catch (error: NoSuchMethodException) {
                null
            } catch (error: SecurityException) {
                null
            }
        }
    }
}
