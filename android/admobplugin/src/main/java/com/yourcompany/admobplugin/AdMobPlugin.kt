package com.yourcompany.admobplugin

import android.app.Activity
import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class AdMobPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "AdMobPlugin"
    }

    private var interstitialAd: InterstitialAd? = null
    private var isInitialized = false

    override fun getPluginName(): String = "AdMobPlugin"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("initialized"),
        SignalInfo("interstitial_loaded"),
        SignalInfo("interstitial_closed"),
        SignalInfo("interstitial_failed_to_load"),
        SignalInfo("interstitial_show_failed")
    )

    @UsedByGodot
    fun initialize(appId: String, testMode: Boolean) {
        val activity: Activity = activity ?: run {
            Log.e(TAG, "initialize: activity is null")
            return
        }
        activity.runOnUiThread {
            MobileAds.initialize(activity) { initializationStatus ->
                Log.d(TAG, "MobileAds initialized: $initializationStatus")
                isInitialized = true
                emitSignal("initialized")
            }
        }
    }

    @UsedByGodot
    fun load_interstitial(adUnitId: String) {
        val activity: Activity = activity ?: run {
            Log.e(TAG, "load_interstitial: activity is null")
            return
        }
        activity.runOnUiThread {
            val adRequest = AdRequest.Builder().build()
            InterstitialAd.load(
                activity,
                adUnitId,
                adRequest,
                object : InterstitialAdLoadCallback() {
                    override fun onAdLoaded(ad: InterstitialAd) {
                        Log.d(TAG, "Interstitial ad loaded.")
                        interstitialAd = ad
                        emitSignal("interstitial_loaded")
                    }

                    override fun onAdFailedToLoad(error: LoadAdError) {
                        Log.e(TAG, "Interstitial failed to load: ${error.message}")
                        interstitialAd = null
                        emitSignal("interstitial_failed_to_load")
                    }
                }
            )
        }
    }

    @UsedByGodot
    fun show_interstitial(): Boolean {
        val activity: Activity = activity ?: run {
            Log.e(TAG, "show_interstitial: activity is null")
            return false
        }
        val ad = interstitialAd ?: run {
            Log.w(TAG, "show_interstitial: ad not loaded")
            return false
        }
        activity.runOnUiThread {
            ad.fullScreenContentCallback = object : FullScreenContentCallback() {
                override fun onAdDismissedFullScreenContent() {
                    Log.d(TAG, "Interstitial dismissed.")
                    interstitialAd = null
                    emitSignal("interstitial_closed")
                }

                override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                    Log.e(TAG, "Interstitial failed to show: ${adError.message}")
                    interstitialAd = null
                    emitSignal("interstitial_show_failed")
                }
            }
            ad.show(activity)
        }
        return true
    }

    @UsedByGodot
    fun is_interstitial_loaded(): Boolean {
        return interstitialAd != null
    }
}
