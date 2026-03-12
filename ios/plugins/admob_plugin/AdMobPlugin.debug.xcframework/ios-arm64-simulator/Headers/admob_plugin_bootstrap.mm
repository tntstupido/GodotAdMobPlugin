#import "admob_plugin.h"
#import "admob_plugin_bootstrap.h"

#include "core/config/engine.h"

static AdMobPlugin *admob_plugin = nullptr;

void init_admob_plugin() {
	admob_plugin = memnew(AdMobPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("AdMobPlugin", admob_plugin));
}

void deinit_admob_plugin() {
	if (admob_plugin != nullptr) {
		memdelete(admob_plugin);
		admob_plugin = nullptr;
	}
}
