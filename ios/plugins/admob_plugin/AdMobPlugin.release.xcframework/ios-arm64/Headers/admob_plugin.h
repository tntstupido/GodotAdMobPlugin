#ifndef ADMOB_PLUGIN_H
#define ADMOB_PLUGIN_H

#import <Foundation/Foundation.h>

#include "core/error/error_list.h"
#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/string/ustring.h"

@class AdMobIOSBridge;

class AdMobPlugin : public Object {
	GDCLASS(AdMobPlugin, Object);

private:
	static AdMobPlugin *instance;

	__strong AdMobIOSBridge *bridge;
	bool initialized = false;
	bool interstitial_loaded = false;
	bool rewarded_loaded = false;
	int tracking_authorization_status = -1;
	bool consent_info_ready = false;
	bool can_request_ads = false;
	bool consent_form_available = false;
	int consent_status = 0;
	int privacy_options_requirement_status = 0;
	bool privacy_options_form_available = false;

	static void _bind_methods();

public:
	static AdMobPlugin *get_singleton();

	AdMobPlugin();
	~AdMobPlugin();

	Error initialize(String app_id, bool test_mode);
	void init(String app_id);

	void load_interstitial(String ad_unit_id);
	void loadInterstitial(String ad_unit_id);
	bool show_interstitial();
	bool showInterstitial();
	bool is_interstitial_loaded() const;
	bool isInterstitialLoaded() const;

	void load_rewarded(String ad_unit_id);
	void loadRewarded(String ad_unit_id);
	bool show_rewarded();
	bool showRewarded();
	bool is_rewarded_loaded() const;
	bool isRewardedLoaded() const;

	void request_tracking_authorization();
	void requestTrackingAuthorization();
	int get_tracking_authorization_status() const;
	int getTrackingAuthorizationStatus() const;

	void request_consent_info_update();
	void requestConsentInfoUpdate();
	bool can_request_ads_now() const;
	bool canRequestAds() const;
	bool is_consent_form_available() const;
	bool isConsentFormAvailable() const;
	void show_consent_form_if_required();
	void showConsentFormIfRequired();
	int get_consent_status() const;
	int getConsentStatus() const;
	int get_privacy_options_requirement_status() const;
	int getPrivacyOptionsRequirementStatus() const;
	bool is_privacy_options_form_available() const;
	bool isPrivacyOptionsFormAvailable() const;
	void show_privacy_options_form();
	void showPrivacyOptionsForm();

	void notify_initialized();
	void notify_interstitial_loaded();
	void notify_interstitial_closed();
	void notify_interstitial_failed_to_load();
	void notify_interstitial_show_failed();
	void notify_rewarded_loaded();
	void notify_rewarded_closed();
	void notify_rewarded_earned();
	void notify_rewarded_failed_to_load();
	void notify_rewarded_show_failed();
	void set_tracking_authorization_status(int status);
	void notify_consent_info_updated();
	void notify_consent_form_shown();
	void notify_consent_form_dismissed();
	void notify_consent_flow_finished();
	void notify_consent_error(const String &message);
	void notify_privacy_options_form_shown();
	void notify_privacy_options_form_dismissed();
	void notify_privacy_options_form_finished();
	void set_consent_state(bool info_ready, bool ads_allowed, bool form_available, int new_consent_status, int new_privacy_options_requirement_status);
};

#endif
