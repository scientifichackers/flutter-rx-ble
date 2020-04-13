package com.pycampers.rx_ble

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.RequiresApi
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.*
import com.pycampers.plugin_scaffold.catchErrors
import com.pycampers.plugin_scaffold.trySend
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import java.util.*

const val REQUEST_ENABLE_BT = 1
const val REQUEST_ENABLE_LOC = 2
const val REQUEST_PERM_LOC = 3
const val LOC_PERM = Manifest.permission.ACCESS_COARSE_LOCATION

enum class AccessStatus {
    OK,
    BT_DISABLED,
    LOC_DISABLED,
    LOC_DENIED,
    LOC_DENIED_NEVER_ASK_AGAIN,
    BLUETOOTH_NOT_AVAILABLE,
    LOC_DENIED_SHOW_PERM_RATIONALE,
}

interface PermissionInterface {
    fun requestLocPerm(call: MethodCall, result: Result)
    fun hasAccess(call: MethodCall, result: Result)
    fun requestAccess(call: MethodCall, result: Result)
    fun openAppSettings(call: MethodCall, result: Result)
}

class PermissionMethods(val context: Context) : ActivityResultListener,
        RequestPermissionsResultListener,
        PermissionInterface {

    var activity: Activity? = null

    val btEnableReqQ = ArrayDeque<Result>()
    val locEnableReqQ = ArrayDeque<Result>()
    val locPermReqQ = ArrayDeque<Result>()

    fun hasLocPerm(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M
                || context.checkSelfPermission(LOC_PERM) == PackageManager.PERMISSION_GRANTED
    }

    @RequiresApi(Build.VERSION_CODES.M)
    fun reallyRequestLocPerm(result: Result) {
        activity?.requestPermissions(arrayOf(LOC_PERM), REQUEST_PERM_LOC)
        locPermReqQ.add(result)
    }

    fun isGooglePlayServicesAvailable(): Boolean {
        return GoogleApiAvailability
                .getInstance()
                .isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
    }

    fun requestLocPerm(result: Result) {
        if (hasLocPerm()) {
            return result.success(AccessStatus.OK.ordinal)
        }
        if (activity?.shouldShowRequestPermissionRationale(LOC_PERM) == true) {
            result.success(AccessStatus.LOC_DENIED_SHOW_PERM_RATIONALE.ordinal)
        } else {
            reallyRequestLocPerm(result)
        }
    }

    fun isLocEnabled(result: Result, callback: (Boolean, (() -> Unit)?) -> Unit) {
        if (!isGooglePlayServicesAvailable()) {
            if (activity == null) {
                callback(false) {
                    result.success(AccessStatus.LOC_DISABLED.ordinal)
                }
            }

            activity?.let {
                val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    val manager: LocationManager =
                            context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    manager.isLocationEnabled
                } else {
                    Settings.Secure.getInt(
                            it.contentResolver, Settings.Secure.LOCATION_MODE
                    ) != Settings.Secure.LOCATION_MODE_OFF
                }

                callback(enabled) {
                    it.startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                    result.success(AccessStatus.LOC_DISABLED.ordinal)
                }
                return
            }
        }

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
                        callback(false) {
                            val resolvable = e as ResolvableApiException
                            resolvable.startResolutionForResult(activity, REQUEST_ENABLE_LOC)
                            locEnableReqQ.add(result)
                        }
                        return@addOnCompleteListener
                    }
                    else -> null
                }
            }

            callback(response != null && response.locationSettingsStates.isLocationUsable, null)
        }
    }

    fun requestLocEnable(result: Result) {
        isLocEnabled(result) { enabled, requestEnable ->
            catchErrors(result) {
                when {
                    enabled -> {
                        requestLocPerm(result)
                    }
                    requestEnable != null -> {
                        requestEnable()
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
                if (activity?.shouldShowRequestPermissionRationale(LOC_PERM) == true) {
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

    fun isBluetoothAvailable(): Boolean {
        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        return bluetoothAdapter != null
    }

    fun isBluetoothEnabled(): Boolean {
        val value by lazy(LazyThreadSafetyMode.NONE) {
            val bluetoothManager =
                    context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bluetoothManager?.adapter
                    ?: throw RuntimeException("couldn't acquire an instance of BluetoothAdapter")
        }
        return value.isEnabled
    }

    override fun requestLocPerm(call: MethodCall, result: Result) {
        if (hasLocPerm()) {
            return result.success(AccessStatus.OK.ordinal)
        }
        reallyRequestLocPerm(result)
    }

    override fun hasAccess(call: MethodCall, result: Result) {
        if (!isBluetoothAvailable()) {
            result.success(false)
        }
        isLocEnabled(result) { enabled, _ ->
            trySend(result) {
                isBluetoothEnabled() && enabled && hasLocPerm()
            }
        }
    }


    override fun requestAccess(call: MethodCall, result: Result) {
        if (!isBluetoothAvailable()) {
            result.success(AccessStatus.BLUETOOTH_NOT_AVAILABLE.ordinal)
        }
        if (isBluetoothEnabled()) {
            return requestLocEnable(result)
        }
        // enable bluetooth and proceed to requestLocEnable()
        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
        activity?.startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
        btEnableReqQ.add(result)
    }

    override fun openAppSettings(call: MethodCall, result: Result) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        val uri = Uri.fromParts("package", context.packageName, null)
        intent.data = uri
        activity?.startActivity(intent)
        result.success(null)
    }
}