/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2017 Nicolas Casalini

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Nicolas Casalini "DarkGod"
    darkgod@te4.org
*/

#include <map>

extern "C" {
#include "web-external.h"
#include <stdio.h>
#include <stdlib.h>
}
#include "web.h"
#include "web-internal.h"
#include <map>

FILE *logfile = NULL;

void *(*web_mutex_create)();
void (*web_mutex_destroy)(void *mutex);
void (*web_mutex_lock)(void *mutex);
void (*web_mutex_unlock)(void *mutex);
void *(*web_make_texture)(int w, int h);
void (*web_del_texture)(void *tex);
void (*web_texture_update)(void *tex, int w, int h, const void* buffer);
void (*web_key_mods)(bool *shift, bool *ctrl, bool *alt, bool *meta);

static bool web_core = false;

char *cstring_to_c(const CefString &cstr) {
	std::string str = cstr.ToString();
	size_t len = cstr.size();
	char *ret = (char*)malloc((len+1) * sizeof(char));
	memcpy(ret, str.c_str(), len);
	ret[len] = '\0';
	return ret;
}

void te4_web_new(web_view_type *view, int w, int h) {
	static bool inited = false;
	if (!inited) {
		CefRegisterSchemeHandlerFactory("te4", "data", new TE4SchemeHandlerFactory());
		CefAddCrossOriginWhitelistEntry("te4://data", "te4", "data", true);
		inited = true;
	}

	WebViewOpaque *opaque = new WebViewOpaque();
	view->opaque = (void*)opaque;

	CefWindowInfo window_info;
	CefBrowserSettings browserSettings;
	browserSettings.java = STATE_DISABLED;
	browserSettings.plugins = STATE_DISABLED;
	window_info.SetAsOffScreen(NULL);
	window_info.SetTransparentPainting(true);
	opaque->render = new RenderHandler(w, h);
	opaque->view = new BrowserClient(opaque, opaque->render, view->handlers);
	CefString curl("");
	opaque->browser = CefBrowserHost::CreateBrowserSync(window_info, opaque->view.get(), curl, browserSettings);
	opaque->crashed = false;

	view->w = w;
	view->h = h;
	view->closed = false;
	fprintf(logfile, "[WEBCORE] Created webview\n");
}

bool te4_web_close(web_view_type *view) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (!view->closed) {
		view->closed = true;
		if (opaque->crashed) {
			fprintf(logfile, "[WEBCORE] Destroying webview but it was already crashed, doing nothing\n");
		} else {
			fprintf(logfile, "[WEBCORE] Destroying webview for browser\n");
			opaque->browser->GetHost()->CloseBrowser(true);
			fprintf(logfile, "[WEBCORE] Destroying send done\n");
		}
		return true;
	}
	return false;
}

void te4_web_load_url(web_view_type *view, const char *url) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;

	CefString curl(url);
	opaque->browser->GetMainFrame()->LoadURL(curl);
}

void te4_web_set_js_call(web_view_type *view, const char *name) {
//	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;

//	opaque->listener->te4_js.SetCustomMethod(WebString::CreateFromUTF8(name, strlen(name)), true);
}

void *te4_web_toscreen(web_view_type *view, int *w, int *h) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return NULL;

	const RenderHandler* surface = opaque->render;

	if (surface) {
		*w = (*w < 0) ? surface->w : *w;
		*h = (*h < 0) ? surface->h : *h;
		return surface->tex;
	}
	return NULL;
}

bool te4_web_loading(web_view_type *view) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return false;

	return opaque->browser->IsLoading();
}

void te4_web_download_action(web_view_type *view, long id, const char *path) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;

	opaque->view->downloadAction(id, path);
}

void te4_web_do_update(void (*cb)(WebEvent*)) {
	if (!web_core) return;

	if (all_browsers_nb) CefDoMessageLoopWork();

	WebEvent *event;
	while ((event = pop_event())) {
		cb(event);

		switch (event->kind) {
			case TE4_WEB_EVENT_TITLE_CHANGE:
				free((void*)event->data.title);
				break;
			case TE4_WEB_EVENT_REQUEST_POPUP_URL:
				free((void*)event->data.popup.url);
				break;
			case TE4_WEB_EVENT_DOWNLOAD_REQUEST:
				free((void*)event->data.download_request.url);
				free((void*)event->data.download_request.name);
				free((void*)event->data.download_request.mime);
				break;
			case TE4_WEB_EVENT_DOWNLOAD_UPDATE:
				break;
			case TE4_WEB_EVENT_DOWNLOAD_FINISH:
				break;
			case TE4_WEB_EVENT_LOADING:
				free((void*)event->data.loading.url);
				break;
			case TE4_WEB_EVENT_LOCAL_REQUEST:
				free((void*)event->data.local_request.path);
				break;
			case TE4_WEB_EVENT_RUN_LUA:
				free((void*)event->data.run_lua.code);
				break;
			case TE4_WEB_EVENT_EVENT_LUA:
				free((void*)event->data.event_lua.kind);
				free((void*)event->data.event_lua.data);
				break;
			case TE4_WEB_EVENT_DELETE_TEXTURE:
				web_del_texture(event->data.texture);
				break;
			case TE4_WEB_EVENT_END_BROWSER:
			case TE4_WEB_EVENT_BROWSER_COUNT:
				break;
		}

		delete event;
	}
}

static int g_argc;
static char **g_argv;
static char *spawnname;
CefRefPtr<TE4ClientApp> app(new TE4ClientApp);

void te4_web_setup(
	int argc, char **gargv, char *spawnc,
	void*(*mutex_create)(), void(*mutex_destroy)(void*), void(*mutex_lock)(void*), void(*mutex_unlock)(void*),
	void *(*make_texture)(int, int), void (*del_texture)(void*), void (*texture_update)(void*, int, int, const void*),
	void (*key_mods)(bool*, bool*, bool*, bool*)
	) {

#ifdef SELFEXE_MACOSX
	logfile = fopen("/tmp/te4_log_web.txt", "w");
#else
	logfile = fopen("te4_log_web.txt", "w");
#endif
#ifdef _WIN32
	setvbuf(logfile, NULL, _IONBF, 2);
#endif
#ifdef SELFEXE_MACOSX
	setvbuf(logfile, NULL, _IONBF, 2);
#endif

	web_mutex_create = mutex_create;
	web_mutex_destroy = mutex_destroy;
	web_mutex_lock = mutex_lock;
	web_mutex_unlock = mutex_unlock;
	web_make_texture = make_texture;
	web_del_texture = del_texture;
	web_texture_update = texture_update;
	web_key_mods = key_mods;

	spawnname = spawnc;
	g_argc = argc;
	g_argv = gargv;
}

void te4_web_initialize(const char *locales, const char *pak) {
	if (!web_core) {
#ifdef _WIN32
		CefMainArgs args(GetModuleHandle(NULL));
#else
		char **cargv = (char**)calloc(g_argc, sizeof(char*));
		for (int i = 0; i < g_argc; i++) cargv[i] = strdup(g_argv[i]);
		CefMainArgs args(g_argc, cargv);
#endif

		CefSettings settings;
		settings.multi_threaded_message_loop = false;

		// CefString spawn(spawnname);
		// CefString(&settings.browser_subprocess_path) = spawn;
		CefString clocales(locales);
		CefString(&settings.locales_dir_path) = clocales;
		CefString resources(pak);
		CefString(&settings.resources_dir_path) = resources;
		CefInitialize(args, settings, app.get());
		web_core = true;
	}

	te4_web_init_utils();
}

void te4_web_shutdown() {
	fprintf(logfile, "[WEBCORE] Shutdown starting...\n");

	std::map<BrowserClient*, bool> all;

	for (std::map<BrowserClient*, bool>::iterator it=all_browsers.begin(); it != all_browsers.end(); ++it) {
		all[it->first] = it->second;
	}

	fprintf(logfile, "[WEBCORE] Sending kill to all browsers (%d)\n", all_browsers_nb);
	for (std::map<BrowserClient*, bool>::iterator it=all.begin(); it != all.end(); ++it) {
		fprintf(logfile, "[WEBCORE] Sending kill to a browser (crash status %d)\n", it->first->opaque->crashed);
		if (!it->first->opaque->crashed) {
			it->first->browser->GetHost()->CloseBrowser(true);
		}
	}

	while (!all_browsers.empty()) {
		CefDoMessageLoopWork();
		fprintf(logfile, "Waiting browsers to close: %d left\n", (int)all_browsers.size());
	}
	
	fprintf(logfile, "[WEBCORE] all browsers dead, shutting down\n");
	CefShutdown();
	fprintf(logfile, "[WEBCORE] all browsers dead, shutdown completed\n");

	fclose(logfile);
}
