#import "admob_plugin.h"

#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <Foundation/Foundation.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <UserMessagingPlatform/UserMessagingPlatform.h>
#import <UIKit/UIKit.h>

static const char *INITIALIZED_SIGNAL = "initialized";
static const char *INTERSTITIAL_LOADED_SIGNAL = "interstitial_loaded";
static const char *INTERSTITIAL_CLOSED_SIGNAL = "interstitial_closed";
static const char *INTERSTITIAL_FAILED_TO_LOAD_SIGNAL = "interstitial_failed_to_load";
static const char *INTERSTITIAL_SHOW_FAILED_SIGNAL = "interstitial_show_failed";
static const char *REWARDED_LOADED_SIGNAL = "rewarded_loaded";
static const char *REWARDED_CLOSED_SIGNAL = "rewarded_closed";
static const char *REWARDED_EARNED_SIGNAL = "rewarded_earned";
static const char *REWARDED_FAILED_TO_LOAD_SIGNAL = "rewarded_failed_to_load";
static const char *REWARDED_SHOW_FAILED_SIGNAL = "rewarded_show_failed";
static const char *CONSENT_INFO_UPDATED_SIGNAL = "consent_info_updated";
static const char *CONSENT_FORM_SHOWN_SIGNAL = "consent_form_shown";
static const char *CONSENT_FORM_DISMISSED_SIGNAL = "consent_form_dismissed";
static const char *CONSENT_FLOW_FINISHED_SIGNAL = "consent_flow_finished";
static const char *CONSENT_ERROR_SIGNAL = "consent_error";
static const char *PRIVACY_OPTIONS_FORM_SHOWN_SIGNAL = "privacy_options_form_shown";
static const char *PRIVACY_OPTIONS_FORM_DISMISSED_SIGNAL = "privacy_options_form_dismissed";
static const char *PRIVACY_OPTIONS_FORM_FINISHED_SIGNAL = "privacy_options_form_finished";

static NSString *StringToNSString(const String &value) {
	CharString utf8 = value.utf8();
	return [NSString stringWithUTF8String:utf8.get_data()];
}

static String NSStringToString(NSString *value) {
	if (value == nil) {
		return String();
	}
	return String::utf8([value UTF8String]);
}

@interface AdMobIOSBridge : NSObject <GADFullScreenContentDelegate>

@property(nonatomic, assign) AdMobPlugin *plugin;
@property(nonatomic, strong) GADInterstitialAd *interstitialAd;
@property(nonatomic, strong) GADRewardedAd *rewardedAd;
@property(nonatomic, assign) BOOL initialized;
@property(nonatomic, assign) BOOL testMode;

- (instancetype)initWithPlugin:(AdMobPlugin *)plugin;
- (NSError *)initializeWithAppID:(NSString *)appID testMode:(BOOL)testMode;
- (void)loadInterstitialWithAdUnitID:(NSString *)adUnitID;
- (BOOL)showInterstitial;
- (void)loadRewardedWithAdUnitID:(NSString *)adUnitID;
- (BOOL)showRewarded;
- (void)requestTrackingAuthorization;
- (int)trackingAuthorizationStatus;
- (void)requestConsentInfoUpdate;
- (BOOL)canRequestAds;
- (BOOL)isConsentFormAvailable;
- (void)showConsentFormIfRequired;
- (int)consentStatus;
- (int)privacyOptionsRequirementStatus;
- (BOOL)isPrivacyOptionsFormAvailable;
- (void)showPrivacyOptionsForm;

@end

static UIViewController *RootViewController() {
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		UIWindowScene *windowScene = (UIWindowScene *)scene;
		for (UIWindow *window in windowScene.windows) {
			if (window.isKeyWindow && window.rootViewController != nil) {
				return window.rootViewController;
			}
		}
	}

	id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
	if ([appDelegate respondsToSelector:@selector(window)]) {
		UIWindow *delegateWindow = [appDelegate window];
		return delegateWindow.rootViewController;
	}
	return nil;
}

@implementation AdMobIOSBridge

- (instancetype)initWithPlugin:(AdMobPlugin *)plugin {
	self = [super init];
	if (self != nil) {
		_plugin = plugin;
	}
	return self;
}

- (NSError *)initializeWithAppID:(NSString *)appID testMode:(BOOL)testMode {
	(void)appID;
	self.testMode = testMode;

	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.initialized) {
			self.plugin->notify_initialized();
			return;
		}

		[GADMobileAds.sharedInstance startWithCompletionHandler:^(GADInitializationStatus *_Nonnull status) {
			(void)status;
			self.initialized = YES;
			self.plugin->notify_initialized();
		}];
	});

	return nil;
}

- (void)loadInterstitialWithAdUnitID:(NSString *)adUnitID {
	if (@available(iOS 14, *)) {
		self.plugin->set_tracking_authorization_status((int)ATTrackingManager.trackingAuthorizationStatus);
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[GADInterstitialAd loadWithAdUnitID:adUnitID
									request:[GADRequest request]
						  completionHandler:^(GADInterstitialAd * _Nullable ad, NSError * _Nullable error) {
			if (error != nil || ad == nil) {
				self.interstitialAd = nil;
				self.plugin->notify_interstitial_failed_to_load();
				return;
			}

			self.interstitialAd = ad;
			self.interstitialAd.fullScreenContentDelegate = self;
			self.plugin->notify_interstitial_loaded();
		}];
	});
}

- (BOOL)showInterstitial {
	UIViewController *viewController = RootViewController();
	if (self.interstitialAd == nil || viewController == nil) {
		self.plugin->notify_interstitial_show_failed();
		return NO;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.interstitialAd presentFromRootViewController:viewController];
	});
	return YES;
}

- (void)loadRewardedWithAdUnitID:(NSString *)adUnitID {
	if (@available(iOS 14, *)) {
		self.plugin->set_tracking_authorization_status((int)ATTrackingManager.trackingAuthorizationStatus);
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[GADRewardedAd loadWithAdUnitID:adUnitID
								request:[GADRequest request]
					  completionHandler:^(GADRewardedAd * _Nullable ad, NSError * _Nullable error) {
			if (error != nil || ad == nil) {
				self.rewardedAd = nil;
				self.plugin->notify_rewarded_failed_to_load();
				return;
			}

			self.rewardedAd = ad;
			self.rewardedAd.fullScreenContentDelegate = self;
			self.plugin->notify_rewarded_loaded();
		}];
	});
}

- (BOOL)showRewarded {
	UIViewController *viewController = RootViewController();
	if (self.rewardedAd == nil || viewController == nil) {
		self.plugin->notify_rewarded_show_failed();
		return NO;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.rewardedAd presentFromRootViewController:viewController
							 userDidEarnRewardHandler:^{
			self.plugin->notify_rewarded_earned();
		}];
	});
	return YES;
}

- (void)requestTrackingAuthorization {
	if (@available(iOS 14, *)) {
		[ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
			self.plugin->set_tracking_authorization_status((int)status);
		}];
		return;
	}

	self.plugin->set_tracking_authorization_status(-1);
}

- (int)trackingAuthorizationStatus {
	if (@available(iOS 14, *)) {
		return (int)ATTrackingManager.trackingAuthorizationStatus;
	}
	return -1;
}

- (void)requestConsentInfoUpdate {
	dispatch_async(dispatch_get_main_queue(), ^{
		UMPRequestParameters *parameters = [[UMPRequestParameters alloc] init];
		[[UMPConsentInformation sharedInstance]
			requestConsentInfoUpdateWithParameters:parameters
			completionHandler:^(NSError *_Nullable error) {
				UMPConsentInformation *info = [UMPConsentInformation sharedInstance];
				self.plugin->set_consent_state(
					true,
					info.canRequestAds,
					info.formStatus == UMPFormStatusAvailable,
					(int)info.consentStatus,
					(int)info.privacyOptionsRequirementStatus
				);
				if (error != nil) {
					self.plugin->notify_consent_error(NSStringToString(error.localizedDescription ?: @"Unknown consent error"));
					return;
				}
				self.plugin->notify_consent_info_updated();
			}];
	});
}

- (BOOL)canRequestAds {
	return [UMPConsentInformation sharedInstance].canRequestAds;
}

- (BOOL)isConsentFormAvailable {
	return [UMPConsentInformation sharedInstance].formStatus == UMPFormStatusAvailable;
}

- (void)showConsentFormIfRequired {
	dispatch_async(dispatch_get_main_queue(), ^{
		UMPConsentInformation *info = [UMPConsentInformation sharedInstance];
		BOOL shouldPresentForm = info.consentStatus == UMPConsentStatusRequired && info.formStatus == UMPFormStatusAvailable;
		self.plugin->set_consent_state(
			true,
			info.canRequestAds,
			info.formStatus == UMPFormStatusAvailable,
			(int)info.consentStatus,
			(int)info.privacyOptionsRequirementStatus
		);
		if (shouldPresentForm) {
			self.plugin->notify_consent_form_shown();
		}
		[UMPConsentForm loadAndPresentIfRequiredFromViewController:RootViewController()
			completionHandler:^(NSError *_Nullable error) {
				UMPConsentInformation *updatedInfo = [UMPConsentInformation sharedInstance];
				self.plugin->set_consent_state(
					true,
					updatedInfo.canRequestAds,
					updatedInfo.formStatus == UMPFormStatusAvailable,
					(int)updatedInfo.consentStatus,
					(int)updatedInfo.privacyOptionsRequirementStatus
				);
				self.plugin->notify_consent_form_dismissed();
				if (error != nil) {
					self.plugin->notify_consent_error(NSStringToString(error.localizedDescription ?: @"Unknown consent form error"));
					return;
				}
				self.plugin->notify_consent_flow_finished();
			}];
	});
}

- (int)consentStatus {
	return (int)[UMPConsentInformation sharedInstance].consentStatus;
}

- (int)privacyOptionsRequirementStatus {
	return (int)[UMPConsentInformation sharedInstance].privacyOptionsRequirementStatus;
}

- (BOOL)isPrivacyOptionsFormAvailable {
	return [UMPConsentInformation sharedInstance].privacyOptionsRequirementStatus == UMPPrivacyOptionsRequirementStatusRequired;
}

- (void)showPrivacyOptionsForm {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *viewController = RootViewController();
		UMPConsentInformation *info = [UMPConsentInformation sharedInstance];
		self.plugin->set_consent_state(
			true,
			info.canRequestAds,
			info.formStatus == UMPFormStatusAvailable,
			(int)info.consentStatus,
			(int)info.privacyOptionsRequirementStatus
		);
		if (viewController == nil) {
			self.plugin->notify_consent_error("Privacy options form requires a root view controller");
			return;
		}
		self.plugin->notify_privacy_options_form_shown();
		[UMPConsentForm presentPrivacyOptionsFormFromViewController:viewController
			completionHandler:^(NSError *_Nullable error) {
				UMPConsentInformation *updatedInfo = [UMPConsentInformation sharedInstance];
				self.plugin->set_consent_state(
					true,
					updatedInfo.canRequestAds,
					updatedInfo.formStatus == UMPFormStatusAvailable,
					(int)updatedInfo.consentStatus,
					(int)updatedInfo.privacyOptionsRequirementStatus
				);
				self.plugin->notify_privacy_options_form_dismissed();
				if (error != nil) {
					self.plugin->notify_consent_error(NSStringToString(error.localizedDescription ?: @"Unknown privacy options form error"));
					return;
				}
				self.plugin->notify_privacy_options_form_finished();
			}];
	});
}

- (void)adDidDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
	if (ad == self.interstitialAd) {
		self.interstitialAd = nil;
		self.plugin->notify_interstitial_closed();
		return;
	}
	if (ad == self.rewardedAd) {
		self.rewardedAd = nil;
		self.plugin->notify_rewarded_closed();
	}
}

- (void)ad:(id<GADFullScreenPresentingAd>)ad didFailToPresentFullScreenContentWithError:(NSError *)error {
	(void)error;
	if (ad == self.interstitialAd) {
		self.interstitialAd = nil;
		self.plugin->notify_interstitial_show_failed();
		return;
	}
	if (ad == self.rewardedAd) {
		self.rewardedAd = nil;
		self.plugin->notify_rewarded_show_failed();
	}
}

@end

AdMobPlugin *AdMobPlugin::instance = nullptr;

void AdMobPlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("initialize", "app_id", "test_mode"), &AdMobPlugin::initialize);
	ClassDB::bind_method(D_METHOD("init", "app_id"), &AdMobPlugin::init);
	ClassDB::bind_method(D_METHOD("load_interstitial", "ad_unit_id"), &AdMobPlugin::load_interstitial);
	ClassDB::bind_method(D_METHOD("loadInterstitial", "ad_unit_id"), &AdMobPlugin::loadInterstitial);
	ClassDB::bind_method(D_METHOD("show_interstitial"), &AdMobPlugin::show_interstitial);
	ClassDB::bind_method(D_METHOD("showInterstitial"), &AdMobPlugin::showInterstitial);
	ClassDB::bind_method(D_METHOD("is_interstitial_loaded"), &AdMobPlugin::is_interstitial_loaded);
	ClassDB::bind_method(D_METHOD("isInterstitialLoaded"), &AdMobPlugin::isInterstitialLoaded);
	ClassDB::bind_method(D_METHOD("load_rewarded", "ad_unit_id"), &AdMobPlugin::load_rewarded);
	ClassDB::bind_method(D_METHOD("loadRewarded", "ad_unit_id"), &AdMobPlugin::loadRewarded);
	ClassDB::bind_method(D_METHOD("show_rewarded"), &AdMobPlugin::show_rewarded);
	ClassDB::bind_method(D_METHOD("showRewarded"), &AdMobPlugin::showRewarded);
	ClassDB::bind_method(D_METHOD("is_rewarded_loaded"), &AdMobPlugin::is_rewarded_loaded);
	ClassDB::bind_method(D_METHOD("isRewardedLoaded"), &AdMobPlugin::isRewardedLoaded);
	ClassDB::bind_method(D_METHOD("request_tracking_authorization"), &AdMobPlugin::request_tracking_authorization);
	ClassDB::bind_method(D_METHOD("requestTrackingAuthorization"), &AdMobPlugin::requestTrackingAuthorization);
	ClassDB::bind_method(D_METHOD("get_tracking_authorization_status"), &AdMobPlugin::get_tracking_authorization_status);
	ClassDB::bind_method(D_METHOD("getTrackingAuthorizationStatus"), &AdMobPlugin::getTrackingAuthorizationStatus);
	ClassDB::bind_method(D_METHOD("request_consent_info_update"), &AdMobPlugin::request_consent_info_update);
	ClassDB::bind_method(D_METHOD("requestConsentInfoUpdate"), &AdMobPlugin::requestConsentInfoUpdate);
	ClassDB::bind_method(D_METHOD("can_request_ads"), &AdMobPlugin::can_request_ads_now);
	ClassDB::bind_method(D_METHOD("canRequestAds"), &AdMobPlugin::canRequestAds);
	ClassDB::bind_method(D_METHOD("is_consent_form_available"), &AdMobPlugin::is_consent_form_available);
	ClassDB::bind_method(D_METHOD("isConsentFormAvailable"), &AdMobPlugin::isConsentFormAvailable);
	ClassDB::bind_method(D_METHOD("show_consent_form_if_required"), &AdMobPlugin::show_consent_form_if_required);
	ClassDB::bind_method(D_METHOD("showConsentFormIfRequired"), &AdMobPlugin::showConsentFormIfRequired);
	ClassDB::bind_method(D_METHOD("get_consent_status"), &AdMobPlugin::get_consent_status);
	ClassDB::bind_method(D_METHOD("getConsentStatus"), &AdMobPlugin::getConsentStatus);
	ClassDB::bind_method(D_METHOD("get_privacy_options_requirement_status"), &AdMobPlugin::get_privacy_options_requirement_status);
	ClassDB::bind_method(D_METHOD("getPrivacyOptionsRequirementStatus"), &AdMobPlugin::getPrivacyOptionsRequirementStatus);
	ClassDB::bind_method(D_METHOD("is_privacy_options_form_available"), &AdMobPlugin::is_privacy_options_form_available);
	ClassDB::bind_method(D_METHOD("isPrivacyOptionsFormAvailable"), &AdMobPlugin::isPrivacyOptionsFormAvailable);
	ClassDB::bind_method(D_METHOD("show_privacy_options_form"), &AdMobPlugin::show_privacy_options_form);
	ClassDB::bind_method(D_METHOD("showPrivacyOptionsForm"), &AdMobPlugin::showPrivacyOptionsForm);

	ADD_SIGNAL(MethodInfo(INITIALIZED_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_LOADED_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_CLOSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_FAILED_TO_LOAD_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_SHOW_FAILED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_LOADED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_CLOSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_EARNED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_FAILED_TO_LOAD_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_SHOW_FAILED_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_INFO_UPDATED_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_FORM_SHOWN_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_FORM_DISMISSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_FLOW_FINISHED_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_ERROR_SIGNAL, PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(PRIVACY_OPTIONS_FORM_SHOWN_SIGNAL));
	ADD_SIGNAL(MethodInfo(PRIVACY_OPTIONS_FORM_DISMISSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(PRIVACY_OPTIONS_FORM_FINISHED_SIGNAL));
}

AdMobPlugin *AdMobPlugin::get_singleton() {
	return instance;
}

AdMobPlugin::AdMobPlugin() {
	instance = this;
	bridge = [[AdMobIOSBridge alloc] initWithPlugin:this];
}

AdMobPlugin::~AdMobPlugin() {
	bridge = nil;
	if (instance == this) {
		instance = nullptr;
	}
}

Error AdMobPlugin::initialize(String app_id, bool test_mode) {
	NSError *error = [bridge initializeWithAppID:StringToNSString(app_id) testMode:test_mode];
	if (error != nil) {
		return FAILED;
	}
	return OK;
}

void AdMobPlugin::init(String app_id) {
	initialize(app_id, true);
}

void AdMobPlugin::load_interstitial(String ad_unit_id) {
	[bridge loadInterstitialWithAdUnitID:StringToNSString(ad_unit_id)];
}

void AdMobPlugin::loadInterstitial(String ad_unit_id) {
	load_interstitial(ad_unit_id);
}

bool AdMobPlugin::show_interstitial() {
	return [bridge showInterstitial];
}

bool AdMobPlugin::showInterstitial() {
	return show_interstitial();
}

bool AdMobPlugin::is_interstitial_loaded() const {
	return interstitial_loaded;
}

bool AdMobPlugin::isInterstitialLoaded() const {
	return is_interstitial_loaded();
}

void AdMobPlugin::load_rewarded(String ad_unit_id) {
	[bridge loadRewardedWithAdUnitID:StringToNSString(ad_unit_id)];
}

void AdMobPlugin::loadRewarded(String ad_unit_id) {
	load_rewarded(ad_unit_id);
}

bool AdMobPlugin::show_rewarded() {
	return [bridge showRewarded];
}

bool AdMobPlugin::showRewarded() {
	return show_rewarded();
}

bool AdMobPlugin::is_rewarded_loaded() const {
	return rewarded_loaded;
}

bool AdMobPlugin::isRewardedLoaded() const {
	return is_rewarded_loaded();
}

void AdMobPlugin::request_tracking_authorization() {
	[bridge requestTrackingAuthorization];
}

void AdMobPlugin::requestTrackingAuthorization() {
	request_tracking_authorization();
}

int AdMobPlugin::get_tracking_authorization_status() const {
	return [bridge trackingAuthorizationStatus];
}

int AdMobPlugin::getTrackingAuthorizationStatus() const {
	return get_tracking_authorization_status();
}

void AdMobPlugin::request_consent_info_update() {
	[bridge requestConsentInfoUpdate];
}

void AdMobPlugin::requestConsentInfoUpdate() {
	request_consent_info_update();
}

bool AdMobPlugin::can_request_ads_now() const {
	return can_request_ads;
}

bool AdMobPlugin::canRequestAds() const {
	return can_request_ads_now();
}

bool AdMobPlugin::is_consent_form_available() const {
	return consent_form_available;
}

bool AdMobPlugin::isConsentFormAvailable() const {
	return is_consent_form_available();
}

void AdMobPlugin::show_consent_form_if_required() {
	[bridge showConsentFormIfRequired];
}

void AdMobPlugin::showConsentFormIfRequired() {
	show_consent_form_if_required();
}

int AdMobPlugin::get_consent_status() const {
	return consent_status;
}

int AdMobPlugin::getConsentStatus() const {
	return get_consent_status();
}

int AdMobPlugin::get_privacy_options_requirement_status() const {
	return privacy_options_requirement_status;
}

int AdMobPlugin::getPrivacyOptionsRequirementStatus() const {
	return get_privacy_options_requirement_status();
}

bool AdMobPlugin::is_privacy_options_form_available() const {
	return privacy_options_requirement_status == (int)UMPPrivacyOptionsRequirementStatusRequired;
}

bool AdMobPlugin::isPrivacyOptionsFormAvailable() const {
	return is_privacy_options_form_available();
}

void AdMobPlugin::show_privacy_options_form() {
	[bridge showPrivacyOptionsForm];
}

void AdMobPlugin::showPrivacyOptionsForm() {
	show_privacy_options_form();
}

void AdMobPlugin::notify_initialized() {
	initialized = true;
	emit_signal(INITIALIZED_SIGNAL);
}

void AdMobPlugin::notify_interstitial_loaded() {
	interstitial_loaded = true;
	emit_signal(INTERSTITIAL_LOADED_SIGNAL);
}

void AdMobPlugin::notify_interstitial_closed() {
	interstitial_loaded = false;
	emit_signal(INTERSTITIAL_CLOSED_SIGNAL);
}

void AdMobPlugin::notify_interstitial_failed_to_load() {
	interstitial_loaded = false;
	emit_signal(INTERSTITIAL_FAILED_TO_LOAD_SIGNAL);
}

void AdMobPlugin::notify_interstitial_show_failed() {
	interstitial_loaded = false;
	emit_signal(INTERSTITIAL_SHOW_FAILED_SIGNAL);
}

void AdMobPlugin::notify_rewarded_loaded() {
	rewarded_loaded = true;
	emit_signal(REWARDED_LOADED_SIGNAL);
}

void AdMobPlugin::notify_rewarded_closed() {
	rewarded_loaded = false;
	emit_signal(REWARDED_CLOSED_SIGNAL);
}

void AdMobPlugin::notify_rewarded_earned() {
	emit_signal(REWARDED_EARNED_SIGNAL);
}

void AdMobPlugin::notify_rewarded_failed_to_load() {
	rewarded_loaded = false;
	emit_signal(REWARDED_FAILED_TO_LOAD_SIGNAL);
}

void AdMobPlugin::notify_rewarded_show_failed() {
	rewarded_loaded = false;
	emit_signal(REWARDED_SHOW_FAILED_SIGNAL);
}

void AdMobPlugin::set_tracking_authorization_status(int status) {
	tracking_authorization_status = status;
}

void AdMobPlugin::notify_consent_info_updated() {
	emit_signal(CONSENT_INFO_UPDATED_SIGNAL);
}

void AdMobPlugin::notify_consent_form_shown() {
	emit_signal(CONSENT_FORM_SHOWN_SIGNAL);
}

void AdMobPlugin::notify_consent_form_dismissed() {
	emit_signal(CONSENT_FORM_DISMISSED_SIGNAL);
}

void AdMobPlugin::notify_consent_flow_finished() {
	emit_signal(CONSENT_FLOW_FINISHED_SIGNAL);
}

void AdMobPlugin::notify_consent_error(const String &message) {
	emit_signal(CONSENT_ERROR_SIGNAL, message);
}

void AdMobPlugin::notify_privacy_options_form_shown() {
	emit_signal(PRIVACY_OPTIONS_FORM_SHOWN_SIGNAL);
}

void AdMobPlugin::notify_privacy_options_form_dismissed() {
	emit_signal(PRIVACY_OPTIONS_FORM_DISMISSED_SIGNAL);
}

void AdMobPlugin::notify_privacy_options_form_finished() {
	emit_signal(PRIVACY_OPTIONS_FORM_FINISHED_SIGNAL);
}

void AdMobPlugin::set_consent_state(bool info_ready, bool ads_allowed, bool form_available, int new_consent_status, int new_privacy_options_requirement_status) {
	consent_info_ready = info_ready;
	can_request_ads = ads_allowed;
	consent_form_available = form_available;
	consent_status = new_consent_status;
	privacy_options_requirement_status = new_privacy_options_requirement_status;
	privacy_options_form_available = new_privacy_options_requirement_status == (int)UMPPrivacyOptionsRequirementStatusRequired;
}
