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
static const char *INTERSTITIAL_FAILED_TO_LOAD_DETAILED_SIGNAL = "interstitial_failed_to_load_detailed";
static const char *INTERSTITIAL_SHOW_FAILED_SIGNAL = "interstitial_show_failed";
static const char *INTERSTITIAL_SHOW_FAILED_DETAILED_SIGNAL = "interstitial_show_failed_detailed";
static const char *REWARDED_LOADED_SIGNAL = "rewarded_loaded";
static const char *REWARDED_CLOSED_SIGNAL = "rewarded_closed";
static const char *REWARDED_EARNED_SIGNAL = "rewarded_earned";
static const char *REWARDED_FAILED_TO_LOAD_SIGNAL = "rewarded_failed_to_load";
static const char *REWARDED_FAILED_TO_LOAD_DETAILED_SIGNAL = "rewarded_failed_to_load_detailed";
static const char *REWARDED_SHOW_FAILED_SIGNAL = "rewarded_show_failed";
static const char *REWARDED_SHOW_FAILED_DETAILED_SIGNAL = "rewarded_show_failed_detailed";
static const char *CONSENT_INFO_UPDATED_SIGNAL = "consent_info_updated";
static const char *CONSENT_FORM_SHOWN_SIGNAL = "consent_form_shown";
static const char *CONSENT_FORM_DISMISSED_SIGNAL = "consent_form_dismissed";
static const char *CONSENT_FLOW_FINISHED_SIGNAL = "consent_flow_finished";
static const char *CONSENT_ERROR_SIGNAL = "consent_error";
static const char *PRIVACY_OPTIONS_FORM_SHOWN_SIGNAL = "privacy_options_form_shown";
static const char *PRIVACY_OPTIONS_FORM_DISMISSED_SIGNAL = "privacy_options_form_dismissed";
static const char *PRIVACY_OPTIONS_FORM_FINISHED_SIGNAL = "privacy_options_form_finished";
static const char *AD_INSPECTOR_CLOSED_SIGNAL = "ad_inspector_closed";

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

static NSString *SafeNSString(NSString *value) {
	return value != nil ? value : @"";
}

static NSArray<NSString *> *ParseCSVDeviceIdentifiers(NSString *csv) {
	if (csv == nil || csv.length == 0) {
		return @[];
	}

	NSMutableArray<NSString *> *result = [NSMutableArray array];
	NSArray<NSString *> *parts = [csv componentsSeparatedByString:@","];
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	for (NSString *part in parts) {
		NSString *trimmed = [part stringByTrimmingCharactersInSet:whitespace];
		if (trimmed.length > 0) {
			[result addObject:trimmed];
		}
	}
	return result;
}

@interface AdMobIOSBridge : NSObject <GADFullScreenContentDelegate>

@property(nonatomic, assign) AdMobPlugin *plugin;
@property(nonatomic, strong) GADInterstitialAd *interstitialAd;
@property(nonatomic, strong) GADRewardedAd *rewardedAd;
@property(nonatomic, assign) BOOL initialized;
@property(nonatomic, assign) BOOL testMode;
@property(nonatomic, copy) NSArray<NSString *> *testDeviceIdentifiers;
@property(nonatomic, assign) UMPDebugGeography umpDebugGeography;
@property(nonatomic, copy) NSArray<NSString *> *umpDebugTestDeviceIdentifiers;

- (instancetype)initWithPlugin:(AdMobPlugin *)plugin;
- (NSError *)initializeWithAppID:(NSString *)appID testMode:(BOOL)testMode;
- (void)setTestDeviceIdentifiersFromCSV:(NSString *)deviceIDsCSV;
- (void)applyTestDeviceConfiguration;
- (void)setTagForUnderAgeOfConsentEnabled:(BOOL)enabled;
- (void)loadInterstitialWithAdUnitID:(NSString *)adUnitID;
- (BOOL)showInterstitial;
- (void)loadRewardedWithAdUnitID:(NSString *)adUnitID;
- (BOOL)showRewarded;
- (void)requestTrackingAuthorization;
- (int)trackingAuthorizationStatus;
- (void)requestConsentInfoUpdate;
- (void)setUmpDebugGeographyModeFromString:(NSString *)mode;
- (void)setUmpDebugTestDeviceIdentifiersFromCSV:(NSString *)deviceIDsCSV;
- (BOOL)canRequestAds;
- (BOOL)isConsentFormAvailable;
- (void)showConsentFormIfRequired;
- (int)consentStatus;
- (int)privacyOptionsRequirementStatus;
- (BOOL)isPrivacyOptionsFormAvailable;
- (void)showPrivacyOptionsForm;
- (void)openAdInspector;

@end

// Returns the key window from any scene, preferring the app's own key
// window. The AdMob SDK uses the window's scene to size full-screen ads
// correctly on iPad multi-window (see the "Support multiple windows on
// iPad" guide). Returns nil if no foreground window is available.
//
// v1.3.11 change: the v1.3.10 version of this helper filtered out scenes
// whose activationState was not ForegroundActive/Inactive. That filter
// caused chained rewarded pods to lose their iOS WebKit XPC service
// connection (com.apple.WebKit.WebContent: 113) when the app's own
// scene briefly transitioned to a Background activation state during
// pod transitions — the helper returned the SDK's ad-presentation
// window instead of the app's, and the WebView then connected to the
// wrong scene's XPC service. Reverted to v1.3.9.1's behavior: accept
// any key window with a rootViewController, regardless of activation
// state. The first non-key window check below is a defensive
// improvement over the bare v1.3.0 / v1.3.9.1 implementation.
static UIWindow *ActiveKeyWindow() {
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		UIWindowScene *windowScene = (UIWindowScene *)scene;
		for (UIWindow *window in windowScene.windows) {
			if (window.isKeyWindow) {
				return window;
			}
		}
	}

	id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
	if ([appDelegate respondsToSelector:@selector(window)]) {
		return [appDelegate window];
	}
	return nil;
}

// Returns the key window's rootViewController. This is what the Google
// Mobile Ads SDK expects to receive from `presentFromRootViewController:`:
// the parent VC of the presented ad. Passing the AdMob SDK's own already-
// presented VC (i.e. walking the presentedViewController chain) breaks
// the view hierarchy contract and triggers the iOS WebKit.WebContent: 113
// system error in WebView-backed creatives. Keep this simple: return the
// app's own root VC.
static UIViewController *RootViewController() {
	UIWindow *keyWindow = ActiveKeyWindow();
	if (keyWindow != nil && keyWindow.rootViewController != nil) {
		return keyWindow.rootViewController;
	}

	id<UIApplicationDelegate> appDelegate = UIApplication.sharedApplication.delegate;
	if ([appDelegate respondsToSelector:@selector(window)]) {
		UIWindow *delegateWindow = [appDelegate window];
		return delegateWindow.rootViewController;
	}
	return nil;
}

// Returns the UIWindowScene that should be associated with a GADRequest.
// Required for multi-scene iPad apps per the AdMob iOS "Support multiple
// windows" guide; strongly advised for all apps that enable scene
// support, regardless of format.
static UIWindowScene *ActiveWindowScene() {
	UIWindow *keyWindow = ActiveKeyWindow();
	return keyWindow != nil ? keyWindow.windowScene : nil;
}

@implementation AdMobIOSBridge

- (instancetype)initWithPlugin:(AdMobPlugin *)plugin {
	self = [super init];
	if (self != nil) {
		_plugin = plugin;
		_testDeviceIdentifiers = @[];
		_umpDebugGeography = UMPDebugGeographyDisabled;
		_umpDebugTestDeviceIdentifiers = @[];
	}
	return self;
}

- (void)applyTestDeviceConfiguration {
	NSArray<NSString *> *deviceIDs = self.testDeviceIdentifiers != nil ? self.testDeviceIdentifiers : @[];
	GADMobileAds.sharedInstance.requestConfiguration.testDeviceIdentifiers = deviceIDs;
}

- (void)setTagForUnderAgeOfConsentEnabled:(BOOL)enabled {
	dispatch_async(dispatch_get_main_queue(), ^{
		NSNumber *flag = enabled ? @YES : @NO;
		// Apply both flags for stricter under-age handling on ad requests.
		GADMobileAds.sharedInstance.requestConfiguration.tagForUnderAgeOfConsent = flag;
		GADMobileAds.sharedInstance.requestConfiguration.tagForChildDirectedTreatment = flag;
		NSLog(@"[AdMobPlugin][iOS] set_tag_for_under_age_of_consent=%@ (also applied child_directed_treatment=%@)",
			enabled ? @"true" : @"false",
			enabled ? @"true" : @"false");
	});
}

- (NSError *)initializeWithAppID:(NSString *)appID testMode:(BOOL)testMode {
	(void)appID;
	self.testMode = testMode;
	NSLog(@"[AdMobPlugin][iOS] initialize requested app_id=%@ test_mode=%@ test_device_count=%lu",
		SafeNSString(appID),
		testMode ? @"true" : @"false",
		(unsigned long)self.testDeviceIdentifiers.count);

	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.initialized) {
			[self applyTestDeviceConfiguration];
			self.plugin->notify_initialized();
			return;
		}

		[GADMobileAds.sharedInstance startWithCompletionHandler:^(GADInitializationStatus *_Nonnull status) {
			(void)status;
			self.initialized = YES;
			[self applyTestDeviceConfiguration];
			self.plugin->notify_initialized();
		}];
	});

	return nil;
}

- (void)setTestDeviceIdentifiersFromCSV:(NSString *)deviceIDsCSV {
	NSArray<NSString *> *parsedIdentifiers = ParseCSVDeviceIdentifiers(deviceIDsCSV);
	dispatch_async(dispatch_get_main_queue(), ^{
		self.testDeviceIdentifiers = parsedIdentifiers;
		[self applyTestDeviceConfiguration];
		NSLog(@"[AdMobPlugin][iOS] test device identifiers applied count=%lu ids=%@",
			(unsigned long)self.testDeviceIdentifiers.count,
			self.testDeviceIdentifiers);
	});
}

- (void)loadInterstitialWithAdUnitID:(NSString *)adUnitID {
	if (@available(iOS 14, *)) {
		self.plugin->set_tracking_authorization_status((int)ATTrackingManager.trackingAuthorizationStatus);
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[self applyTestDeviceConfiguration];
		NSLog(@"[AdMobPlugin][iOS] load interstitial ad_unit=%@ test_device_count=%lu",
			SafeNSString(adUnitID),
			(unsigned long)self.testDeviceIdentifiers.count);
		GADRequest *request = [GADRequest request];
		// Per the AdMob iOS multi-scene guide, setting the scene is strongly
		// advised for any app with scene support enabled. Omitting it causes
		// test-mode errors and inconsistent full-screen ad sizing in prod.
		UIWindowScene *scene = ActiveWindowScene();
		if (scene != nil) {
			request.scene = scene;
		}
		[GADInterstitialAd loadWithAdUnitID:adUnitID
									request:request
						  completionHandler:^(GADInterstitialAd * _Nullable ad, NSError * _Nullable error) {
			if (error != nil || ad == nil) {
				self.interstitialAd = nil;
				int errorCode = error != nil ? (int)error.code : -1;
				String errorDomain = NSStringToString(error != nil ? error.domain : nil);
				String errorMessage = NSStringToString(error != nil ? error.localizedDescription : @"Interstitial load failed without NSError");
				String adUnitString = NSStringToString(adUnitID);
				NSLog(@"[AdMobPlugin][iOS] interstitial load failed code=%d domain=%@ ad_unit=%@ message=%@",
					errorCode,
					error != nil ? SafeNSString(error.domain) : @"",
					SafeNSString(adUnitID),
					error != nil ? SafeNSString(error.localizedDescription) : @"Interstitial load failed without NSError");
				self.plugin->notify_interstitial_failed_to_load();
				self.plugin->notify_interstitial_failed_to_load_detailed(errorCode, errorDomain, errorMessage, adUnitString);
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
		NSString *reason = self.interstitialAd == nil ? @"interstitial_not_loaded" : @"root_view_controller_missing";
		NSLog(@"[AdMobPlugin][iOS] interstitial show failed reason=%@", reason);
		self.plugin->notify_interstitial_show_failed();
		self.plugin->notify_interstitial_show_failed_detailed(-1, String("show_interstitial"), NSStringToString(reason));
		return NO;
	}

	// Doc-mandated pre-check: verify the ad can be presented from the
	// current VC + window before calling presentFromRootViewController.
	// This catches expired ads and scene/size mismatches early and
	// prevents the SDK from silently failing or self-dismissing.
	NSError *presentError = nil;
	BOOL canPresent = [self.interstitialAd canPresentFromRootViewController:viewController error:&presentError];
	if (!canPresent) {
		int errorCode = presentError != nil ? (int)presentError.code : -2;
		String errorDomain = NSStringToString(presentError != nil ? presentError.domain : nil);
		String errorMessage = NSStringToString(presentError != nil ? presentError.localizedDescription : @"interstitial cannot be presented from current view controller");
		NSString *logMessage = presentError != nil ? presentError.localizedDescription : @"interstitial cannot be presented from current view controller";
		NSLog(@"[AdMobPlugin][iOS] interstitial can_present check failed code=%d domain=%@ message=%@",
			errorCode,
			presentError != nil ? SafeNSString(presentError.domain) : @"",
			SafeNSString(logMessage));
		self.interstitialAd = nil;
		self.plugin->notify_interstitial_show_failed();
		self.plugin->notify_interstitial_show_failed_detailed(errorCode, errorDomain, errorMessage);
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
		[self applyTestDeviceConfiguration];
		NSLog(@"[AdMobPlugin][iOS] load rewarded ad_unit=%@ test_device_count=%lu",
			SafeNSString(adUnitID),
			(unsigned long)self.testDeviceIdentifiers.count);
		GADRequest *request = [GADRequest request];
		// Per the AdMob iOS multi-scene guide, setting the scene is strongly
		// advised for any app with scene support enabled. Omitting it causes
		// test-mode errors and inconsistent full-screen ad sizing in prod.
		UIWindowScene *scene = ActiveWindowScene();
		if (scene != nil) {
			request.scene = scene;
		}
		[GADRewardedAd loadWithAdUnitID:adUnitID
								request:request
					  completionHandler:^(GADRewardedAd * _Nullable ad, NSError * _Nullable error) {
			if (error != nil || ad == nil) {
				self.rewardedAd = nil;
				int errorCode = error != nil ? (int)error.code : -1;
				String errorDomain = NSStringToString(error != nil ? error.domain : nil);
				String errorMessage = NSStringToString(error != nil ? error.localizedDescription : @"Rewarded load failed without NSError");
				String adUnitString = NSStringToString(adUnitID);
				NSLog(@"[AdMobPlugin][iOS] rewarded load failed code=%d domain=%@ ad_unit=%@ message=%@",
					errorCode,
					error != nil ? SafeNSString(error.domain) : @"",
					SafeNSString(adUnitID),
					error != nil ? SafeNSString(error.localizedDescription) : @"Rewarded load failed without NSError");
				self.plugin->notify_rewarded_failed_to_load();
				self.plugin->notify_rewarded_failed_to_load_detailed(errorCode, errorDomain, errorMessage, adUnitString);
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
		NSString *reason = self.rewardedAd == nil ? @"rewarded_not_loaded" : @"root_view_controller_missing";
		NSLog(@"[AdMobPlugin][iOS] rewarded show failed reason=%@", reason);
		self.plugin->notify_rewarded_show_failed();
		self.plugin->notify_rewarded_show_failed_detailed(-1, String("show_rewarded"), NSStringToString(reason));
		return NO;
	}

	// Doc-mandated pre-check: verify the ad can be presented from the
	// current VC + window before calling presentFromRootViewController.
	// This catches expired ads and scene/size mismatches early and
	// prevents the SDK from silently failing or self-dismissing.
	NSError *presentError = nil;
	BOOL canPresent = [self.rewardedAd canPresentFromRootViewController:viewController error:&presentError];
	if (!canPresent) {
		int errorCode = presentError != nil ? (int)presentError.code : -2;
		String errorDomain = NSStringToString(presentError != nil ? presentError.domain : nil);
		String errorMessage = NSStringToString(presentError != nil ? presentError.localizedDescription : @"rewarded cannot be presented from current view controller");
		NSString *logMessage = presentError != nil ? presentError.localizedDescription : @"rewarded cannot be presented from current view controller";
		NSLog(@"[AdMobPlugin][iOS] rewarded can_present check failed code=%d domain=%@ message=%@",
			errorCode,
			presentError != nil ? SafeNSString(presentError.domain) : @"",
			SafeNSString(logMessage));
		self.rewardedAd = nil;
		self.plugin->notify_rewarded_show_failed();
		self.plugin->notify_rewarded_show_failed_detailed(errorCode, errorDomain, errorMessage);
		return NO;
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.rewardedAd presentFromRootViewController:viewController
							 userDidEarnRewardHandler:^{
			// SDK contract says this fires on the main thread, but some
			// mediation adapters deliver from a background queue. Hop to main
			// before emitting to Godot to avoid deadlocking the script VM.
			dispatch_async(dispatch_get_main_queue(), ^{
				self.plugin->notify_rewarded_earned();
			});
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
		UMPDebugGeography effectiveDebugGeography = self.umpDebugGeography;
		NSArray<NSString *> *effectiveDebugTestDevices = self.umpDebugTestDeviceIdentifiers != nil ? self.umpDebugTestDeviceIdentifiers : @[];
		// Optional env test-device override for local/manual QA runs.
		NSString *umpTestDeviceID = NSProcessInfo.processInfo.environment[@"GODOT_UMP_DEBUG_TEST_DEVICE_ID"];
		if (umpTestDeviceID != nil && umpTestDeviceID.length > 0) {
			effectiveDebugTestDevices = @[ umpTestDeviceID ];
		}
		if (effectiveDebugGeography != UMPDebugGeographyDisabled) {
			UMPDebugSettings *debugSettings = [[UMPDebugSettings alloc] init];
			debugSettings.geography = effectiveDebugGeography;
			if (effectiveDebugTestDevices.count > 0) {
				debugSettings.testDeviceIdentifiers = effectiveDebugTestDevices;
			}
			parameters.debugSettings = debugSettings;
			NSLog(@"[AdMobPlugin][iOS] UMP debug settings applied geography=%ld test_device_count=%lu",
				(long)effectiveDebugGeography,
				(unsigned long)effectiveDebugTestDevices.count);
		}
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

- (void)setUmpDebugGeographyModeFromString:(NSString *)mode {
	NSString *normalized = mode != nil ? [[mode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString] : @"";
	UMPDebugGeography resolved = UMPDebugGeographyDisabled;
	if ([normalized isEqualToString:@"eea"]) {
		resolved = UMPDebugGeographyEEA;
	} else if ([normalized isEqualToString:@"regulated_us_state"] || [normalized isEqualToString:@"us_regulated_state"] || [normalized isEqualToString:@"regulatedusstate"]) {
		resolved = UMPDebugGeographyRegulatedUSState;
	} else if ([normalized isEqualToString:@"other"] || [normalized isEqualToString:@"not_eea"]) {
		resolved = UMPDebugGeographyOther;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		self.umpDebugGeography = resolved;
		NSLog(@"[AdMobPlugin][iOS] UMP debug geography mode set to '%@' (enum=%ld)", normalized, (long)resolved);
	});
}

- (void)setUmpDebugTestDeviceIdentifiersFromCSV:(NSString *)deviceIDsCSV {
	NSArray<NSString *> *parsedIdentifiers = ParseCSVDeviceIdentifiers(deviceIDsCSV);
	dispatch_async(dispatch_get_main_queue(), ^{
		self.umpDebugTestDeviceIdentifiers = parsedIdentifiers;
		NSLog(@"[AdMobPlugin][iOS] UMP debug test device identifiers applied count=%lu ids=%@",
			(unsigned long)self.umpDebugTestDeviceIdentifiers.count,
			self.umpDebugTestDeviceIdentifiers);
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

- (void)openAdInspector {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *viewController = RootViewController();
		if (viewController == nil) {
			self.plugin->notify_ad_inspector_closed("Ad Inspector requires a root view controller");
			return;
		}
		NSLog(@"[AdMobPlugin][iOS] presenting Ad Inspector");
		[GADMobileAds.sharedInstance presentAdInspectorFromViewController:viewController
			completionHandler:^(NSError *_Nullable error) {
				NSString *message = error != nil ? error.localizedDescription : @"closed";
				NSLog(@"[AdMobPlugin][iOS] Ad Inspector closed message=%@", SafeNSString(message));
				self.plugin->notify_ad_inspector_closed(NSStringToString(message));
			}];
	});
}

- (void)adDidRecordImpression:(id<GADFullScreenPresentingAd>)ad {
	// GADFullScreenContentDelegate method. Fires when the SDK records an
	// impression for the full-screen ad. Logged for parity with the
	// official AdMob rewarded sample.
	NSLog(@"[AdMobPlugin][iOS] adDidRecordImpression");
}

- (void)adDidRecordClick:(id<GADFullScreenPresentingAd>)ad {
	// GADFullScreenContentDelegate method. Fires when the user clicks the
	// full-screen ad. Logged for parity with the official AdMob rewarded
	// sample.
	NSLog(@"[AdMobPlugin][iOS] adDidRecordClick");
}

- (void)adWillPresentFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
	// GADFullScreenContentDelegate method. Fires immediately before the
	// full-screen ad UI is presented. The doc suggests pausing
	// animations or time-sensitive UI work here, but for a Godot game
	// the engine already handles its own pause state via the
	// rewarded_loaded / rewarded_closed signal flow.
	NSLog(@"[AdMobPlugin][iOS] adWillPresentFullScreenContent");
}

- (void)adWillDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
	// GADFullScreenContentDelegate method. Fires immediately before the
	// full-screen ad UI is dismissed (e.g. user tapped close). Logged
	// for parity with the official AdMob rewarded sample.
	NSLog(@"[AdMobPlugin][iOS] adWillDismissFullScreenContent");
}

- (void)adDidDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
	// Some mediation paths invoke the full-screen content delegate off the
	// main thread. emit_signal into a Godot Object from a non-main thread
	// can deadlock the script VM. Always re-enter main before notifying.
	dispatch_async(dispatch_get_main_queue(), ^{
		if (ad == self.interstitialAd) {
			self.interstitialAd = nil;
			self.plugin->notify_interstitial_closed();
			return;
		}
		if (ad == self.rewardedAd) {
			self.rewardedAd = nil;
			self.plugin->notify_rewarded_closed();
		}
	});
}

- (void)ad:(id<GADFullScreenPresentingAd>)ad didFailToPresentFullScreenContentWithError:(NSError *)error {
	int errorCode = error != nil ? (int)error.code : -1;
	String errorDomain = NSStringToString(error != nil ? error.domain : nil);
	String errorMessage = NSStringToString(error != nil ? error.localizedDescription : @"present_fullscreen_failed_without_error");
	if (ad == self.interstitialAd) {
		self.interstitialAd = nil;
		NSLog(@"[AdMobPlugin][iOS] interstitial present failed code=%d domain=%@ message=%@",
			errorCode,
			error != nil ? SafeNSString(error.domain) : @"",
			error != nil ? SafeNSString(error.localizedDescription) : @"");
		self.plugin->notify_interstitial_show_failed();
		self.plugin->notify_interstitial_show_failed_detailed(errorCode, errorDomain, errorMessage);
		return;
	}
	if (ad == self.rewardedAd) {
		self.rewardedAd = nil;
		NSLog(@"[AdMobPlugin][iOS] rewarded present failed code=%d domain=%@ message=%@",
			errorCode,
			error != nil ? SafeNSString(error.domain) : @"",
			error != nil ? SafeNSString(error.localizedDescription) : @"");
		self.plugin->notify_rewarded_show_failed();
		self.plugin->notify_rewarded_show_failed_detailed(errorCode, errorDomain, errorMessage);
	}
}

@end

AdMobPlugin *AdMobPlugin::instance = nullptr;

void AdMobPlugin::_bind_methods() {
	ClassDB::bind_method("initialize", &AdMobPlugin::initialize);
	ClassDB::bind_method("init", &AdMobPlugin::init);
	ClassDB::bind_method("set_test_device_ids", &AdMobPlugin::set_test_device_ids);
	ClassDB::bind_method("setTestDeviceIds", &AdMobPlugin::setTestDeviceIds);
	ClassDB::bind_method("set_tag_for_under_age_of_consent", &AdMobPlugin::set_tag_for_under_age_of_consent);
	ClassDB::bind_method("setTagForUnderAgeOfConsent", &AdMobPlugin::setTagForUnderAgeOfConsent);
	ClassDB::bind_method("load_interstitial", &AdMobPlugin::load_interstitial);
	ClassDB::bind_method("loadInterstitial", &AdMobPlugin::loadInterstitial);
	ClassDB::bind_method("show_interstitial", &AdMobPlugin::show_interstitial);
	ClassDB::bind_method("showInterstitial", &AdMobPlugin::showInterstitial);
	ClassDB::bind_method("is_interstitial_loaded", &AdMobPlugin::is_interstitial_loaded);
	ClassDB::bind_method("isInterstitialLoaded", &AdMobPlugin::isInterstitialLoaded);
	ClassDB::bind_method("load_rewarded", &AdMobPlugin::load_rewarded);
	ClassDB::bind_method("loadRewarded", &AdMobPlugin::loadRewarded);
	ClassDB::bind_method("show_rewarded", &AdMobPlugin::show_rewarded);
	ClassDB::bind_method("showRewarded", &AdMobPlugin::showRewarded);
	ClassDB::bind_method("is_rewarded_loaded", &AdMobPlugin::is_rewarded_loaded);
	ClassDB::bind_method("isRewardedLoaded", &AdMobPlugin::isRewardedLoaded);
	ClassDB::bind_method("request_tracking_authorization", &AdMobPlugin::request_tracking_authorization);
	ClassDB::bind_method("requestTrackingAuthorization", &AdMobPlugin::requestTrackingAuthorization);
	ClassDB::bind_method("get_tracking_authorization_status", &AdMobPlugin::get_tracking_authorization_status);
	ClassDB::bind_method("getTrackingAuthorizationStatus", &AdMobPlugin::getTrackingAuthorizationStatus);
	ClassDB::bind_method("request_consent_info_update", &AdMobPlugin::request_consent_info_update);
	ClassDB::bind_method("requestConsentInfoUpdate", &AdMobPlugin::requestConsentInfoUpdate);
	ClassDB::bind_method("set_ump_debug_geography", &AdMobPlugin::set_ump_debug_geography);
	ClassDB::bind_method("setUmpDebugGeography", &AdMobPlugin::setUmpDebugGeography);
	ClassDB::bind_method("set_ump_debug_test_device_ids", &AdMobPlugin::set_ump_debug_test_device_ids);
	ClassDB::bind_method("setUmpDebugTestDeviceIds", &AdMobPlugin::setUmpDebugTestDeviceIds);
	ClassDB::bind_method("can_request_ads", &AdMobPlugin::can_request_ads_now);
	ClassDB::bind_method("canRequestAds", &AdMobPlugin::canRequestAds);
	ClassDB::bind_method("is_consent_form_available", &AdMobPlugin::is_consent_form_available);
	ClassDB::bind_method("isConsentFormAvailable", &AdMobPlugin::isConsentFormAvailable);
	ClassDB::bind_method("show_consent_form_if_required", &AdMobPlugin::show_consent_form_if_required);
	ClassDB::bind_method("showConsentFormIfRequired", &AdMobPlugin::showConsentFormIfRequired);
	ClassDB::bind_method("get_consent_status", &AdMobPlugin::get_consent_status);
	ClassDB::bind_method("getConsentStatus", &AdMobPlugin::getConsentStatus);
	ClassDB::bind_method("get_privacy_options_requirement_status", &AdMobPlugin::get_privacy_options_requirement_status);
	ClassDB::bind_method("getPrivacyOptionsRequirementStatus", &AdMobPlugin::getPrivacyOptionsRequirementStatus);
	ClassDB::bind_method("is_privacy_options_form_available", &AdMobPlugin::is_privacy_options_form_available);
	ClassDB::bind_method("isPrivacyOptionsFormAvailable", &AdMobPlugin::isPrivacyOptionsFormAvailable);
	ClassDB::bind_method("show_privacy_options_form", &AdMobPlugin::show_privacy_options_form);
	ClassDB::bind_method("showPrivacyOptionsForm", &AdMobPlugin::showPrivacyOptionsForm);
	ClassDB::bind_method("open_ad_inspector", &AdMobPlugin::open_ad_inspector);
	ClassDB::bind_method("openAdInspector", &AdMobPlugin::openAdInspector);

	ADD_SIGNAL(MethodInfo(INITIALIZED_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_LOADED_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_CLOSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_FAILED_TO_LOAD_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_FAILED_TO_LOAD_DETAILED_SIGNAL,
		PropertyInfo(Variant::INT, "code"),
		PropertyInfo(Variant::STRING, "domain"),
		PropertyInfo(Variant::STRING, "message"),
		PropertyInfo(Variant::STRING, "ad_unit_id")));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_SHOW_FAILED_SIGNAL));
	ADD_SIGNAL(MethodInfo(INTERSTITIAL_SHOW_FAILED_DETAILED_SIGNAL,
		PropertyInfo(Variant::INT, "code"),
		PropertyInfo(Variant::STRING, "domain"),
		PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(REWARDED_LOADED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_CLOSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_EARNED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_FAILED_TO_LOAD_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_FAILED_TO_LOAD_DETAILED_SIGNAL,
		PropertyInfo(Variant::INT, "code"),
		PropertyInfo(Variant::STRING, "domain"),
		PropertyInfo(Variant::STRING, "message"),
		PropertyInfo(Variant::STRING, "ad_unit_id")));
	ADD_SIGNAL(MethodInfo(REWARDED_SHOW_FAILED_SIGNAL));
	ADD_SIGNAL(MethodInfo(REWARDED_SHOW_FAILED_DETAILED_SIGNAL,
		PropertyInfo(Variant::INT, "code"),
		PropertyInfo(Variant::STRING, "domain"),
		PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(CONSENT_INFO_UPDATED_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_FORM_SHOWN_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_FORM_DISMISSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_FLOW_FINISHED_SIGNAL));
	ADD_SIGNAL(MethodInfo(CONSENT_ERROR_SIGNAL, PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo(PRIVACY_OPTIONS_FORM_SHOWN_SIGNAL));
	ADD_SIGNAL(MethodInfo(PRIVACY_OPTIONS_FORM_DISMISSED_SIGNAL));
	ADD_SIGNAL(MethodInfo(PRIVACY_OPTIONS_FORM_FINISHED_SIGNAL));
	ADD_SIGNAL(MethodInfo(AD_INSPECTOR_CLOSED_SIGNAL, PropertyInfo(Variant::STRING, "message")));
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

void AdMobPlugin::set_test_device_ids(String device_ids_csv) {
	[bridge setTestDeviceIdentifiersFromCSV:StringToNSString(device_ids_csv)];
}

void AdMobPlugin::setTestDeviceIds(String device_ids_csv) {
	set_test_device_ids(device_ids_csv);
}

void AdMobPlugin::set_tag_for_under_age_of_consent(bool enabled) {
	[bridge setTagForUnderAgeOfConsentEnabled:enabled];
}

void AdMobPlugin::setTagForUnderAgeOfConsent(bool enabled) {
	set_tag_for_under_age_of_consent(enabled);
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

void AdMobPlugin::set_ump_debug_geography(String mode) {
	[bridge setUmpDebugGeographyModeFromString:StringToNSString(mode)];
}

void AdMobPlugin::setUmpDebugGeography(String mode) {
	set_ump_debug_geography(mode);
}

void AdMobPlugin::set_ump_debug_test_device_ids(String device_ids_csv) {
	[bridge setUmpDebugTestDeviceIdentifiersFromCSV:StringToNSString(device_ids_csv)];
}

void AdMobPlugin::setUmpDebugTestDeviceIds(String device_ids_csv) {
	set_ump_debug_test_device_ids(device_ids_csv);
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

void AdMobPlugin::open_ad_inspector() {
	[bridge openAdInspector];
}

void AdMobPlugin::openAdInspector() {
	open_ad_inspector();
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

void AdMobPlugin::notify_interstitial_failed_to_load_detailed(int code, const String &domain, const String &message, const String &ad_unit_id) {
	emit_signal(INTERSTITIAL_FAILED_TO_LOAD_DETAILED_SIGNAL, code, domain, message, ad_unit_id);
}

void AdMobPlugin::notify_interstitial_show_failed() {
	interstitial_loaded = false;
	emit_signal(INTERSTITIAL_SHOW_FAILED_SIGNAL);
}

void AdMobPlugin::notify_interstitial_show_failed_detailed(int code, const String &domain, const String &message) {
	emit_signal(INTERSTITIAL_SHOW_FAILED_DETAILED_SIGNAL, code, domain, message);
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

void AdMobPlugin::notify_rewarded_failed_to_load_detailed(int code, const String &domain, const String &message, const String &ad_unit_id) {
	emit_signal(REWARDED_FAILED_TO_LOAD_DETAILED_SIGNAL, code, domain, message, ad_unit_id);
}

void AdMobPlugin::notify_rewarded_show_failed() {
	rewarded_loaded = false;
	emit_signal(REWARDED_SHOW_FAILED_SIGNAL);
}

void AdMobPlugin::notify_rewarded_show_failed_detailed(int code, const String &domain, const String &message) {
	emit_signal(REWARDED_SHOW_FAILED_DETAILED_SIGNAL, code, domain, message);
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

void AdMobPlugin::notify_ad_inspector_closed(const String &message) {
	emit_signal(AD_INSPECTOR_CLOSED_SIGNAL, message);
}

void AdMobPlugin::set_consent_state(bool info_ready, bool ads_allowed, bool form_available, int new_consent_status, int new_privacy_options_requirement_status) {
	consent_info_ready = info_ready;
	can_request_ads = ads_allowed;
	consent_form_available = form_available;
	consent_status = new_consent_status;
	privacy_options_requirement_status = new_privacy_options_requirement_status;
	privacy_options_form_available = new_privacy_options_requirement_status == (int)UMPPrivacyOptionsRequirementStatusRequired;
}
