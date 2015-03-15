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

typedef std::map<int, std::pair<CefRefPtr<CefV8Context>, CefRefPtr<CefV8Value> > > CallbackMap;

class TE4V8Handler : public CefV8Handler {
public:
	TE4V8Handler() {}

	virtual bool Execute(const CefString& name, CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval, CefString& exception) OVERRIDE;

	IMPLEMENT_REFCOUNTING(TE4V8Handler);
};

class TE4RenderProcessHandler : public CefRenderProcessHandler
{
public:
	TE4RenderProcessHandler() {
		// printf("NEW Render Process\n");
	}

	virtual bool OnBeforeNavigation(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefRequest> request, NavigationType navigation_type, bool is_redirect) OVERRIDE {
		return false;
	}

	virtual void OnWebKitInitialized() OVERRIDE {
		
	}

	virtual bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefProcessId source_process, CefRefPtr<CefProcessMessage> message);

	virtual void OnContextCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context) OVERRIDE {
		// Retrieve the context's window object.
		CefRefPtr<CefV8Value> object = context->GetGlobal();

		CefRefPtr<CefV8Handler> handler = new TE4V8Handler();
		object->SetValue("lua", CefV8Value::CreateFunction("lua", handler), V8_PROPERTY_ATTRIBUTE_NONE);
	}

	IMPLEMENT_REFCOUNTING(TE4RenderProcessHandler);
};

class TE4ClientApp : public CefApp
{
public:
	CallbackMap callback_map;

	virtual CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() OVERRIDE {
		return new TE4RenderProcessHandler();
	}

	virtual void OnRegisterCustomSchemes(CefRefPtr<CefSchemeRegistrar> registrar) {
		registrar->AddCustomScheme("te4", true, true, false);
	}

	bool processCallback(CefRefPtr<CefBrowser> browser, CefRefPtr<CefProcessMessage> message);
	void sendCallback(CefRefPtr<CefBrowser> browser, int cb_id);

	IMPLEMENT_REFCOUNTING(TE4ClientApp);
};

extern CefRefPtr<TE4ClientApp> app;
