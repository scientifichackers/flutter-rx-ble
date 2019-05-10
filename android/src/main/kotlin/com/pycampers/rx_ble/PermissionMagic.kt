package com.pycampers.rx_ble

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.RequiresApi
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.LocationSettingsStates
import com.google.android.gms.location.LocationSettingsStatusCodes
import com.pycampers.method_call_dispatcher.MethodCallDispatcher
import com.pycampers.method_call_dispatcher.catchErrors
import com.pycampers.method_call_dispatcher.trySend
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.ArrayDeque
import java.util.NoSuchElementException

enum class AccessStatus {
    OK,
    BT_DISABLED,
    LOC_DISABLED,
    LOC_DENIED,
    LOC_DENIED_NEVER_ASK_AGAIN,
    LOC_DENIED_SHOW_PERM_RATIONALE,
}

open class PermissionMagic(val registrar: PluginRegistry.Registrar) : MethodCallDispatcher(),
    PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener {
    val btEnableReqQ = ArrayDeque<Result>()
    val locEnableReqQ = ArrayDeque<Result>()
    val locPermReqQ = ArrayDeque<Result>()

    val activity: Activity
        get() = registrar.activity()
    val context: Context
        get() = activity.applicationContext

    init {
        registrar.addActivityResultListener(this)
        registrar.addRequestPermissionsResultListener(this)
    }

    fun hasLocPerm(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M
            || context.checkSelfPermission(LOC_PERM) == PackageManager.PERMISSION_GRANTED
    }

    @RequiresApi(Build.VERSION_CODES.M)
    fun reallyRequestLocPerm(result: Result) {
        activity.requestPermissions(arrayOf(LOC_PERM), REQUEST_PERM_LOC)
        locPermReqQ.add(result)
    }

    fun requestLocPerm(result: Result) {
        if (hasLocPerm()) {
            return result.success(AccessStatus.OK.ordinal)
        }
        if (activity.shouldShowRequestPermissionRationale(LOC_PERM)) {
            result.success(AccessStatus.LOC_DENIED_SHOW_PERM_RATIONALE.ordinal)
        } else {
            reallyRequestLocPerm(result)
        }
    }

    fun requestLocPerm(call: MethodCall, result: Result) {
        if (hasLocPerm()) {
            return result.success(AccessStatus.OK.ordinal)
        }
        reallyRequestLocPerm(result)
    }

    fun isLocEnabled(callback: (Boolean, e: ResolvableApiException?) -> Unit) {
        val request = LocationSettingsRequest.Builder()
            .addLocationRequest(LocationRequest())
            .setAlwaysShow(true)
            .build()

        val taskResult = LocationServices.getSettingsClient(context)
            .checkLocationSettings(request)

        taskResult.addOnCompleteListener {
            val response = try {
                taskResult.getResult(ApiException::class.java)
            } catch (e: ApiException) {
                when (e.statusCode) {
                    LocationSettingsStatusCodes.RESOLUTION_REQUIRED -> {
                        callback(false, e as ResolvableApiException)
                        return@addOnCompleteListener
                    }
                    else -> null
                }
            }

            callback(response != null && response.locationSettingsStates.isLocationUsable, null)
        }
    }

    fun requestLocEnable(result: Result) {
        isLocEnabled { enabled, resolvable ->
            catchErrors(result) {
                when {
                    enabled -> {
                        requestLocPerm(result)
                    }
                    resolvable != null -> {
                        resolvable.startResolutionForResult(activity, REQUEST_ENABLE_LOC)
                        locEnableReqQ.add(result)
                    }
                    else -> {
                        result.success(AccessStatus.LOC_DISABLED.ordinal)
                    }
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?): Boolean {
        when (requestCode) {
            REQUEST_ENABLE_BT -> {
                val result: Result
                try {
                    result = btEnableReqQ.remove()
                } catch (e: NoSuchElementException) {
                    return false
                }

                catchErrors(result) {
                    when (resultCode) {
                        Activity.RESULT_OK -> requestLocEnable(result)
                        Activity.RESULT_CANCELED -> result.success(AccessStatus.BT_DISABLED.ordinal)
                        else -> throw IllegalArgumentException(
                            "unexpected \"resultCode\" for REQUEST_ENABLE_BT { $resultCode }"
                        )
                    }
                }

                return true
            }
            REQUEST_ENABLE_LOC -> {
                val result: Result
                try {
                    result = locEnableReqQ.remove()
                } catch (e: NoSuchElementException) {
                    return false
                }

                catchErrors(result) {
                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            if (LocationSettingsStates.fromIntent(intent).isLocationUsable) {
                                requestLocPerm(result)
                            } else {
                                result.success(AccessStatus.LOC_DISABLED.ordinal)
                            }
                        }
                        Activity.RESULT_CANCELED -> result.success(AccessStatus.LOC_DISABLED.ordinal)
                        else -> throw IllegalArgumentException(
                            "unexpected \"resultCode\" for REQUEST_ENABLE_LOC { $resultCode }"
                        )
                    }
                }

                return true
            }
            else -> return false
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>?,
        grantResults: IntArray?
    ): Boolean {
        if (requestCode != REQUEST_PERM_LOC) return false

        val result: Result
        try {
            result = locPermReqQ.remove()
        } catch (e: NoSuchElementException) {
            return false
        }

        trySend(result) {
            val granted = try {
                grantResults?.first() == PackageManager.PERMISSION_GRANTED
            } catch (e: NoSuchElementException) {
                false
            }

            val status = if (granted) {
                AccessStatus.OK
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (activity.shouldShowRequestPermissionRationale(LOC_PERM)) {
                    AccessStatus.LOC_DENIED
                } else {
                    AccessStatus.LOC_DENIED_NEVER_ASK_AGAIN
                }
            } else {
                AccessStatus.LOC_DENIED
            }

            status.ordinal
        }

        return true
    }

    fun isBluetoothEnabled(): Boolean {
        val value by lazy(LazyThreadSafetyMode.NONE) {
            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bluetoothManager?.adapter ?: throw RuntimeException("couldn't acquire an instance of BluetoothAdapter")
        }
        return value.isEnabled
    }

    fun hasAccess(call: MethodCall, result: Result) {
        isLocEnabled { enabled, _ ->
            trySend(result) {
                isBluetoothEnabled() && enabled && hasLocPerm()
            }
        }
    }

    fun requestAccess(call: MethodCall, result: Result) {
        if (isBluetoothEnabled()) {
            return requestLocEnable(result)
        }
        // enable bluetooth and proceed to requestLocEnable()
        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
        activity.startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
        btEnableReqQ.add(result)
    }

    fun openAppSettings(call: MethodCall, result: Result) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        val uri = Uri.fromParts("package", context.packageName, null)
        intent.data = uri
        context.startActivity(intent)
        result.success(null)
    }
}