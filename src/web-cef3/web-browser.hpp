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

class CurrentDownload {
public:
	CurrentDownload() { accept_cb = NULL; cancel_cb = NULL; }
	CefRefPtr<CefBeforeDownloadCallback> accept_cb;
	CefRefPtr<CefDownloadItemCallback> cancel_cb;
};

class BrowserClient :
	public CefClient,
	public CefRequestHandler,
	public CefDisplayHandler,
	public CefLifeSpanHandler,
	public CefDownloadHandler,
	public CefLoadHandler
{
	std::map<int32, CurrentDownload*> downloads;
	CefRefPtr<CefRenderHandler> m_renderHandler;
	int handlers;

public:
	WebViewOpaque *opaque;
	CefRefPtr<CefBrowser> browser;
	bool first_load;

	BrowserClient(WebViewOpaque *opaque, RenderHandler *renderHandler, int handlers);
	~BrowserClient();

	virtual CefRefPtr<CefRenderHandler> GetRenderHandler() {
		return m_renderHandler;
	}
	virtual CefRefPtr<CefDisplayHandler> GetDisplayHandler() OVERRIDE {
		return this;
	}
	virtual CefRefPtr<CefRequestHandler> GetRequestHandler() OVERRIDE {
		return this;
	}
	virtual CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() OVERRIDE {
		return this;
	}
	virtual CefRefPtr<CefDownloadHandler> GetDownloadHandler() OVERRIDE {
		return this;
	}
	virtual CefRefPtr<CefLoadHandler> GetLoadHandler() OVERRIDE {
		return this;
	}

	virtual void OnTitleChange(CefRefPtr<CefBrowser> browser, const CefString& title) OVERRIDE;

	virtual bool OnBeforeResourceLoad(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefRequest> request) OVERRIDE;

	virtual bool OnBeforePluginLoad(CefRefPtr<CefBrowser> browser, const CefString& url, const CefString& policy_url, CefRefPtr<CefWebPluginInfo> info) OVERRIDE;

	virtual void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus status) OVERRIDE;

	virtual bool OnBeforePopup(CefRefPtr<CefBrowser> browser,
	                             CefRefPtr<CefFrame> frame,
	                             const CefString& target_url,
	                             const CefString& target_frame_name,
	                             const CefPopupFeatures& popupFeatures,
	                             CefWindowInfo& windowInfo,
	                             CefRefPtr<CefClient>& client,
	                             CefBrowserSettings& settings,
	                             bool* no_javascript_access) OVERRIDE;

	virtual void OnBeforeDownload(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDownloadItem> download_item, const CefString& suggested_name, CefRefPtr<CefBeforeDownloadCallback> callback) OVERRIDE;

	virtual void OnDownloadUpdated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefDownloadItem> download_item, CefRefPtr<CefDownloadItemCallback> callback) OVERRIDE;
	
	virtual void downloadAction(int32 id, const char *path);

	virtual void OnLoadStart(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame);

	virtual void OnLoadEnd(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, int httpStatusCode);

	virtual void OnAfterCreated(CefRefPtr<CefBrowser> browser);

	virtual void OnBeforeClose(CefRefPtr<CefBrowser> browser);

	IMPLEMENT_REFCOUNTING(BrowserClient);
};

extern std::map<BrowserClient*, bool> all_browsers;
extern int all_browsers_nb;
