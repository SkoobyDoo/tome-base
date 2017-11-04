/*
    TE4 - T-Engine 4
    Copyright (C) 2009 - 2015 Nicolas Casalini

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

extern "C" {
#include "web-external.h"
#include <stdio.h>
#include <stdlib.h>
}
#include <map>
#include "web.h"
#include "web-internal.h"

std::map<BrowserClient*, bool> all_browsers;
std::map<int, CefRefPtr<CefBrowser> > browsers_by_cb;
int all_browsers_nb = 0;

BrowserClient::BrowserClient(WebViewOpaque *opaque, RenderHandler *renderHandler, int handlers) : m_renderHandler(renderHandler) {
	this->opaque = opaque;
	this->handlers = handlers;
	this->first_load = true;
	all_browsers[this] = true;
	all_browsers_nb++;

	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_BROWSER_COUNT;
	event->data.count = all_browsers_nb;
	push_event(event);
}
BrowserClient::~BrowserClient() {
	fprintf(logfile, "[WEBCORE] Destroyed client\n");
	for (std::map<int32, CurrentDownload*>::iterator it=downloads.begin(); it != downloads.end(); ++it) {
		delete it->second;
	}
	all_browsers.erase(this);
	all_browsers_nb--;

	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_BROWSER_COUNT;
	event->data.count = all_browsers_nb;
	push_event(event);
}

void BrowserClient::OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) OVERRIDE {
	char *cur_title = cstring_to_c(title);
	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_TITLE_CHANGE;
	event->handlers = handlers;
	event->data.title = cur_title;
	push_event(event);
}

bool BrowserClient::OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefRequest> request) OVERRIDE {
	return false;
}

bool BrowserClient::OnBeforePluginLoad(CefRefPtr<CefBrowser> browser, const CefString& url, const CefString& policy_url, CefRefPtr<CefWebPluginInfo> info) OVERRIDE {
	char *name = cstring_to_c(info->GetName());
	char *path = cstring_to_c(info->GetPath());
	fprintf(logfile, "[WEBCORE] Forbade plugin %s from %s\n", name, path);
	free(name);
	free(path);
	return true;
}

void BrowserClient::OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus status) OVERRIDE {
	if ((status == TS_ABNORMAL_TERMINATION) || (status == TS_PROCESS_WAS_KILLED) || (status == TS_PROCESS_CRASHED)) {
		opaque->crashed = true;
		WebEvent *event = new WebEvent();
		event->kind = TE4_WEB_EVENT_END_BROWSER;
		event->handlers = handlers;
		push_event(event);
	}
}

bool BrowserClient::OnBeforePopup(CefRefPtr<CefBrowser> browser,
                             CefRefPtr<CefFrame> frame,
                             const CefString& target_url,
                             const CefString& target_frame_name,
                             const CefPopupFeatures& popupFeatures,
                             CefWindowInfo& windowInfo,
                             CefRefPtr<CefClient>& client,
                             CefBrowserSettings& settings,
                             bool* no_javascript_access) OVERRIDE {
	char *url = cstring_to_c(target_url);

	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_REQUEST_POPUP_URL;
	event->handlers = handlers;
	event->data.popup.url = url;
	event->data.popup.w = popupFeatures.widthSet ? popupFeatures.width : -1;
	event->data.popup.h = popupFeatures.heightSet ? popupFeatures.height : -1;
	push_event(event);

	fprintf(logfile, "[WEBCORE] stopped popup to %s (%dx%d), pushing event...\n", url, event->data.popup.w, event->data.popup.h);

	return true;
}

void BrowserClient::OnBeforeDownload(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDownloadItem> download_item, const CefString& suggested_name, CefRefPtr<CefBeforeDownloadCallback> callback) OVERRIDE {
	int32 id = download_item->GetId();
	CurrentDownload *cd = new CurrentDownload();
	cd->accept_cb = callback;
	this->downloads[id] = cd;

	const char *mime = cstring_to_c(download_item->GetMimeType());
	const char *url = cstring_to_c(download_item->GetURL());
	const char *name = cstring_to_c(suggested_name);
	fprintf(logfile, "[WEBCORE] Download request id %ld [name: %s] [mime: %s] [url: %s]\n", (long int)id, name, mime, url);

	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_DOWNLOAD_REQUEST;
	event->handlers = handlers;
	event->data.download_request.url = url;
	event->data.download_request.name = name;
	event->data.download_request.mime = mime;
	event->data.download_request.id = id;
	push_event(event);
}

void BrowserClient::OnDownloadUpdated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDownloadItem> download_item, CefRefPtr<CefDownloadItemCallback> callback) OVERRIDE {
	int32 id = download_item->GetId();
	CurrentDownload *cd = this->downloads[id];
	if (!cd) { return; }
	cd->cancel_cb = callback;

	fprintf(logfile, "[WEBCORE] Download update id %ld [size: %ld / %ld] [completed: %d, canceled: %d, inprogress: %d, valid: %d]\n",
			(long int)id,
			download_item->GetReceivedBytes(), download_item->GetTotalBytes(),
			download_item->IsComplete(), download_item->IsCanceled(),
			download_item->IsInProgress(), download_item->IsValid()
		);

	if (download_item->IsComplete() || download_item->IsCanceled()) {
		WebEvent *event = new WebEvent();
		event->kind = TE4_WEB_EVENT_DOWNLOAD_FINISH;
		event->handlers = handlers;
		event->data.download_finish.id = id;
		push_event(event);
	} else {
		WebEvent *event = new WebEvent();
		event->kind = TE4_WEB_EVENT_DOWNLOAD_UPDATE;
		event->handlers = handlers;
		event->data.download_update.id = id;
		event->data.download_update.got = download_item->GetReceivedBytes();
		event->data.download_update.total = download_item->GetTotalBytes();
		event->data.download_update.percent = download_item->GetPercentComplete();
		event->data.download_update.speed = download_item->GetCurrentSpeed();
		push_event(event);
	}
}

void BrowserClient::downloadAction(int32 id, const char *path) {
	CurrentDownload *cd = this->downloads[id];
	if (!cd) return;

	if (!path) {
		// Cancel
		if (cd->cancel_cb) cd->cancel_cb->Cancel();
		delete cd;
		downloads.erase(id);
		fprintf(logfile, "[WEBCORE] Cancel download(%d)\n", id);
	} else {
		// Accept
		CefString fullpath(path);
		cd->accept_cb->Continue(fullpath, false);
		fprintf(logfile, "[WEBCORE] Accepting download(%d) to %s\n", id, path);
	}
}

void BrowserClient::OnLoadStart(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame) {
	const char *url = cstring_to_c(frame->GetURL());
	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_LOADING;
	event->handlers = handlers;
	event->data.loading.url = url;
	event->data.loading.status = 0;
	push_event(event);
}

void BrowserClient::OnLoadEnd(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int httpStatusCode) {
	const char *url = cstring_to_c(frame->GetURL());
	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_LOADING;
	event->handlers = handlers;
	event->data.loading.url = url;
	event->data.loading.status = 1;
	push_event(event);
}

void BrowserClient::OnAfterCreated(CefRefPtr<CefBrowser> browser) {
	fprintf(logfile, "[WEBCORE] Created browser for webview\n");
	this->browser = browser;
}

void BrowserClient::OnBeforeClose(CefRefPtr<CefBrowser> browser) {
	this->opaque->render = NULL;
	this->opaque->view = NULL;
	this->opaque->browser = NULL;
	this->browser = NULL;

	delete this->opaque;

	fprintf(logfile, "[WEBCORE] Destroyed webview for browser\n");
}

bool BrowserClient::processRunLua(CefRefPtr<CefBrowser> browser, CefRefPtr<CefProcessMessage> message) {
	// Execute the registered JavaScript callback if any.
	CefRefPtr<CefListValue> list = message->GetArgumentList();
	if (list->GetSize() == 0) return false;

	// First argument is the callback id
	int cb_id = list->GetInt(0);

	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_RUN_LUA;
	event->data.run_lua.cb_id = cb_id;
	event->data.run_lua.code = cstring_to_c(list->GetString(1));
	push_event(event);

	// Register which browser is for which cb
	if (cb_id) {
		browsers_by_cb[cb_id] = browser;
	}

	return true;
}

bool BrowserClient::processEventLua(CefRefPtr<CefBrowser> browser, CefRefPtr<CefProcessMessage> message) {
	// Execute the registered JavaScript callback if any.
	CefRefPtr<CefListValue> list = message->GetArgumentList();
	if (list->GetSize() != 2) return false;

	WebEvent *event = new WebEvent();
	event->kind = TE4_WEB_EVENT_EVENT_LUA;
	event->handlers = handlers;
	event->data.event_lua.kind = cstring_to_c(list->GetString(0));
	event->data.event_lua.data = cstring_to_c(list->GetString(1));
	push_event(event);

	return true;
}

bool BrowserClient::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefProcessId source_process, CefRefPtr<CefProcessMessage> message) {
	bool handled = false;

	// printf("Main Receiving IPC message '%s' from %d\n", (char*)message->GetName().c_str(), source_process);

	if (message->GetName() == "runlua") handled = processRunLua(browser, message);
	else if (message->GetName() == "eventlua") handled = processEventLua(browser, message);

	return handled;
}

void te4_web_js_callback(web_view_type *view, int cb_id, char *json_ret, size_t len) {
	if (!browsers_by_cb.count(cb_id)) return;

	CefRefPtr<CefBrowser> browser = browsers_by_cb[cb_id];
	app->sendCallback(browser, cb_id, json_ret, len);

	browsers_by_cb.erase(cb_id);
}
