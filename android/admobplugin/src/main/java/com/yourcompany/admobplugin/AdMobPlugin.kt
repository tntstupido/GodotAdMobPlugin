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
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class AdMobPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "AdMobPlugin"
    }

    private var interstitialAd: InterstitialAd? = null
    private var rewardedAd: RewardedAd? = null

    override fun getPluginName(): String = "AdMobPlugin"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("initialized"),
        SignalInfo("interstitial_loaded"),
        SignalInfo("interstitial_closed"),
        SignalInfo("interstitial_failed_to_load"),
        SignalInfo("interstitial_show_failed"),
        SignalInfo("rewarded_loaded"),
        SignalInfo("rewarded_closed"),
        SignalInfo("rewarded_earned"),
        SignalInfo("rewarded_failed_to_load"),
        SignalInfo("rewarded_show_failed")
    )

    @UsedByGodot
    fun initialize(appId: String, testMode: Boolean) {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "initialize: activity is null")
            return
        }
        currentActivity.runOnUiThread {
            MobileAds.initialize(currentActivity) { initializationStatus ->
                Log.d(TAG, "MobileAds initialized: $initializationStatus")
                emitSignal("initialized")
            }
        }
    }

    @UsedByGodot
    fun init(appId: String) {
        initialize(appId, true)
    }

    @UsedByGodot
    fun load_interstitial(adUnitId: String) {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "load_interstitial: activity is null")
            return
        }
        currentActivity.runOnUiThread {
            val adRequest = AdRequest.Builder().build()
            InterstitialAd.load(
                currentActivity,
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
    fun loadInterstitial(adUnitId: String) {
        load_interstitial(adUnitId)
    }

    @UsedByGodot
    fun show_interstitial(): Boolean {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "show_interstitial: activity is null")
            return false
        }
        val ad = interstitialAd ?: run {
            Log.w(TAG, "show_interstitial: ad not loaded")
            return false
        }
        currentActivity.runOnUiThread {
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
            ad.show(currentActivity)
        }
        return true
    }

    @UsedByGodot
    fun showInterstitial(): Boolean {
        return show_interstitial()
    }

    @UsedByGodot
    fun is_interstitial_loaded(): Boolean {
        return interstitialAd != null
    }

    @UsedByGodot
    fun isInterstitialLoaded(): Boolean {
        return is_interstitial_loaded()
    }

    @UsedByGodot
    fun load_rewarded(adUnitId: String) {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "load_rewarded: activity is null")
            return
        }
        currentActivity.runOnUiThread {
            val adRequest = AdRequest.Builder().build()
            RewardedAd.load(
                currentActivity,
                adUnitId,
                adRequest,
                object : RewardedAdLoadCallback() {
                    override fun onAdLoaded(ad: RewardedAd) {
                        Log.d(TAG, "Rewarded ad loaded.")
                        rewardedAd = ad
                        emitSignal("rewarded_loaded")
                    }

                    override fun onAdFailedToLoad(error: LoadAdError) {
                        Log.e(TAG, "Rewarded failed to load: ${error.message}")
                        rewardedAd = null
                        emitSignal("rewarded_failed_to_load")
                    }
                }
            )
        }
    }

    @UsedByGodot
    fun loadRewarded(adUnitId: String) {
        load_rewarded(adUnitId)
    }

    @UsedByGodot
    fun show_rewarded(): Boolean {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "show_rewarded: activity is null")
            return false
        }
        val ad = rewardedAd ?: run {
            Log.w(TAG, "show_rewarded: ad not loaded")
            return false
        }
        currentActivity.runOnUiThread {
            ad.fullScreenContentCallback = object : FullScreenContentCallback() {
                override fun onAdDismissedFullScreenContent() {
                    Log.d(TAG, "Rewarded dismissed.")
                    rewardedAd = null
                    emitSignal("rewarded_closed")
                }

                override fun onAdFailedToShowFullScreenContent(adError: AdError) {
                    Log.e(TAG, "Rewarded failed to show: ${adError.message}")
                    rewardedAd = null
                    emitSignal("rewarded_show_failed")
                }
            }
            ad.show(currentActivity) {
                Log.d(TAG, "Rewarded earned.")
                emitSignal("rewarded_earned")
            }
        }
        return true
    }

    @UsedByGodot
    fun showRewarded(): Boolean {
        return show_rewarded()
    }

    @UsedByGodot
    fun is_rewarded_loaded(): Boolean {
        return rewardedAd != null
    }

    @UsedByGodot
    fun isRewardedLoaded(): Boolean {
        return is_rewarded_loaded()
    }
}
