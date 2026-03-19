package com.yourcompany.admobplugin

import android.app.Activity
import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.RequestConfiguration
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import com.google.android.ump.ConsentDebugSettings
import com.google.android.ump.ConsentInformation
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.UserMessagingPlatform
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

class AdMobPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "AdMobPlugin"

        private const val UMP_DEBUG_GEOGRAPHY_DISABLED = "disabled"
        private const val UMP_DEBUG_GEOGRAPHY_EEA = "eea"
        private const val UMP_DEBUG_GEOGRAPHY_NOT_EEA = "not_eea"
    }

    private var interstitialAd: InterstitialAd? = null
    private var rewardedAd: RewardedAd? = null

    private var umpDebugGeographyMode: String = UMP_DEBUG_GEOGRAPHY_DISABLED
    private var umpDebugTestDeviceHashedId: String? = null

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
        SignalInfo("rewarded_show_failed"),
        SignalInfo("consent_info_updated"),
        SignalInfo("consent_form_shown"),
        SignalInfo("consent_form_dismissed"),
        SignalInfo("consent_flow_finished"),
        SignalInfo("consent_error", String::class.java),
        SignalInfo("privacy_options_form_shown"),
        SignalInfo("privacy_options_form_dismissed"),
        SignalInfo("privacy_options_form_finished")
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
    fun set_test_device_ids(deviceIdsCsv: String) {
        val deviceIds = deviceIdsCsv
            .split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }

        val requestConfiguration = MobileAds.getRequestConfiguration()
        val updatedConfiguration = requestConfiguration
            .toBuilder()
            .setTestDeviceIds(deviceIds)
            .build()
        MobileAds.setRequestConfiguration(updatedConfiguration)

        umpDebugTestDeviceHashedId = if (deviceIds.isNotEmpty()) deviceIds[0] else null

        Log.d(TAG, "set_test_device_ids: applied ${deviceIds.size} test device IDs")
    }

    @UsedByGodot
    fun setTestDeviceIds(deviceIdsCsv: String) {
        set_test_device_ids(deviceIdsCsv)
    }

    @UsedByGodot
    fun set_ump_debug_geography(mode: String) {
        val normalized = mode.trim().lowercase()
        umpDebugGeographyMode = when (normalized) {
            UMP_DEBUG_GEOGRAPHY_EEA,
            "debug_geography_eea" -> UMP_DEBUG_GEOGRAPHY_EEA

            UMP_DEBUG_GEOGRAPHY_NOT_EEA,
            "debug_geography_not_eea",
            "non_eea",
            "not-eea" -> UMP_DEBUG_GEOGRAPHY_NOT_EEA

            UMP_DEBUG_GEOGRAPHY_DISABLED,
            "debug_geography_disabled",
            "off",
            "none",
            "" -> UMP_DEBUG_GEOGRAPHY_DISABLED

            else -> {
                Log.w(TAG, "set_ump_debug_geography: unknown mode '$mode', using disabled")
                UMP_DEBUG_GEOGRAPHY_DISABLED
            }
        }
        Log.d(TAG, "set_ump_debug_geography: mode=$umpDebugGeographyMode")
    }

    @UsedByGodot
    fun setUmpDebugGeography(mode: String) {
        set_ump_debug_geography(mode)
    }

    @UsedByGodot
    fun reset_ump_consent_state() {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "reset_ump_consent_state: activity is null")
            return
        }
        currentActivity.runOnUiThread {
            UserMessagingPlatform.getConsentInformation(currentActivity).reset()
            Log.d(TAG, "reset_ump_consent_state: consent information reset")
        }
    }

    @UsedByGodot
    fun resetUmpConsentState() {
        reset_ump_consent_state()
    }

    @UsedByGodot
    fun request_consent_info_update() {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "request_consent_info_update: activity is null")
            emitSignal("consent_error", "activity_null")
            return
        }

        currentActivity.runOnUiThread {
            val consentInformation = UserMessagingPlatform.getConsentInformation(currentActivity)
            val parameters = buildConsentRequestParameters(currentActivity)

            consentInformation.requestConsentInfoUpdate(
                currentActivity,
                parameters,
                {
                    emitSignal("consent_info_updated")
                },
                { error ->
                    val message = error?.message ?: "unknown_error"
                    Log.e(TAG, "request_consent_info_update failed: $message")
                    emitSignal("consent_error", message)
                }
            )
        }
    }

    @UsedByGodot
    fun requestConsentInfoUpdate() {
        request_consent_info_update()
    }

    @UsedByGodot
    fun can_request_ads(): Boolean {
        val currentActivity: Activity = activity ?: return false
        val consentInformation = UserMessagingPlatform.getConsentInformation(currentActivity)
        return consentInformation.canRequestAds()
    }

    @UsedByGodot
    fun canRequestAds(): Boolean {
        return can_request_ads()
    }

    @UsedByGodot
    fun is_consent_form_available(): Boolean {
        val currentActivity: Activity = activity ?: return false
        val consentInformation = UserMessagingPlatform.getConsentInformation(currentActivity)
        return consentInformation.isConsentFormAvailable
    }

    @UsedByGodot
    fun isConsentFormAvailable(): Boolean {
        return is_consent_form_available()
    }

    @UsedByGodot
    fun show_consent_form_if_required() {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "show_consent_form_if_required: activity is null")
            emitSignal("consent_error", "activity_null")
            return
        }

        currentActivity.runOnUiThread {
            emitSignal("consent_form_shown")
            UserMessagingPlatform.loadAndShowConsentFormIfRequired(currentActivity) { formError ->
                emitSignal("consent_form_dismissed")
                if (formError != null) {
                    val message = formError.message ?: "unknown_error"
                    Log.e(TAG, "show_consent_form_if_required failed: $message")
                    emitSignal("consent_error", message)
                }
                emitSignal("consent_flow_finished")
            }
        }
    }

    @UsedByGodot
    fun showConsentFormIfRequired() {
        show_consent_form_if_required()
    }

    @UsedByGodot
    fun get_consent_status(): Int {
        val currentActivity: Activity = activity ?: return ConsentInformation.ConsentStatus.UNKNOWN
        val consentInformation = UserMessagingPlatform.getConsentInformation(currentActivity)
        return consentInformation.consentStatus
    }

    @UsedByGodot
    fun getConsentStatus(): Int {
        return get_consent_status()
    }

    @UsedByGodot
    fun get_privacy_options_requirement_status(): Int {
        val currentActivity: Activity = activity ?: return 0
        val consentInformation = UserMessagingPlatform.getConsentInformation(currentActivity)
        val status = consentInformation.privacyOptionsRequirementStatus
        return when (status) {
            ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED -> 2
            ConsentInformation.PrivacyOptionsRequirementStatus.NOT_REQUIRED -> 1
            else -> 0
        }
    }

    @UsedByGodot
    fun getPrivacyOptionsRequirementStatus(): Int {
        return get_privacy_options_requirement_status()
    }

    @UsedByGodot
    fun is_privacy_options_form_available(): Boolean {
        val currentActivity: Activity = activity ?: return false
        val consentInformation = UserMessagingPlatform.getConsentInformation(currentActivity)
        return consentInformation.privacyOptionsRequirementStatus == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED
    }

    @UsedByGodot
    fun isPrivacyOptionsFormAvailable(): Boolean {
        return is_privacy_options_form_available()
    }

    @UsedByGodot
    fun show_privacy_options_form() {
        val currentActivity: Activity = activity ?: run {
            Log.e(TAG, "show_privacy_options_form: activity is null")
            emitSignal("consent_error", "activity_null")
            return
        }

        currentActivity.runOnUiThread {
            emitSignal("privacy_options_form_shown")
            UserMessagingPlatform.showPrivacyOptionsForm(currentActivity) { formError ->
                emitSignal("privacy_options_form_dismissed")
                if (formError != null) {
                    val message = formError.message ?: "unknown_error"
                    Log.e(TAG, "show_privacy_options_form failed: $message")
                    emitSignal("consent_error", message)
                }
                emitSignal("privacy_options_form_finished")
            }
        }
    }

    @UsedByGodot
    fun showPrivacyOptionsForm() {
        show_privacy_options_form()
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

    private fun buildConsentRequestParameters(currentActivity: Activity): ConsentRequestParameters {
        val requestBuilder = ConsentRequestParameters.Builder()

        val debugGeography = when (umpDebugGeographyMode) {
            UMP_DEBUG_GEOGRAPHY_EEA -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA
            UMP_DEBUG_GEOGRAPHY_NOT_EEA -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_NOT_EEA
            else -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_DISABLED
        }

        if (debugGeography != ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_DISABLED) {
            val debugSettingsBuilder = ConsentDebugSettings.Builder(currentActivity)
                .setDebugGeography(debugGeography)

            val hashedId = umpDebugTestDeviceHashedId
            if (!hashedId.isNullOrBlank()) {
                debugSettingsBuilder.addTestDeviceHashedId(hashedId)
            } else {
                Log.w(TAG, "UMP debug geography enabled without test device hash; forcing may not apply")
            }

            requestBuilder.setConsentDebugSettings(debugSettingsBuilder.build())
            Log.d(TAG, "UMP debug request configured (mode=$umpDebugGeographyMode, hasTestDevice=${!hashedId.isNullOrBlank()})")
        }

        return requestBuilder.build()
    }
}
