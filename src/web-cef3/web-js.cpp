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
#include "web.h"
#include "web-internal.h"

static int next_cb_id = 1;

bool TE4V8Handler::Execute(const CefString& name, CefRefPtr<CefV8Value> object, const CefV8ValueList& arguments, CefRefPtr<CefV8Value>& retval, CefString& exception) OVERRIDE {
	// Execute arbitraty lua code with a callback on exec end
	if (name == "lua" && arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsFunction()) {
		CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();

		int cb_id = next_cb_id++;
		app->callback_map[cb_id] = std::make_pair(context, arguments[1]);

		CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("runlua");
		CefRefPtr<CefListValue> list = message->GetArgumentList();
		list->SetSize(2);
		list->SetInt(0, cb_id);
		list->SetString(1, arguments[0]->GetStringValue());
		context->GetBrowser()->SendProcessMessage(PID_BROWSER, message);

		return true;
	}
	// Execute arbitraty lua code without any callbacks
	else if (name == "lua" && arguments.size() == 1 && arguments[0]->IsString()) {
		CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();

		CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("runlua");
		CefRefPtr<CefListValue> list = message->GetArgumentList();
		list->SetSize(2);
		list->SetInt(0, 0);
		list->SetString(1, arguments[0]->GetStringValue());
		context->GetBrowser()->SendProcessMessage(PID_BROWSER, message);

		return true;
	}
	// Generic lua event
	else if (name == "luaevent" && arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsString()) {
		CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();

		CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("eventlua");
		CefRefPtr<CefListValue> list = message->GetArgumentList();
		list->SetSize(2);
		list->SetString(0, arguments[0]->GetStringValue());
		list->SetString(1, arguments[1]->GetStringValue());
		context->GetBrowser()->SendProcessMessage(PID_BROWSER, message);

		return true;
	}
	return false;
}

bool TE4RenderProcessHandler::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefProcessId source_process, CefRefPtr<CefProcessMessage> message) {
	bool handled = false;

	// printf("Renderer Receiving IPC message '%s' from %d\n", (char*)message->GetName().c_str(), source_process);

	if (message->GetName() == "js_callback") handled = app->processCallback(browser, message);

	return handled;
}

void TE4RenderProcessHandler::OnWebKitInitialized() {
	// Define the extension contents.
	std::string extensionCode = 
"var te4; "
"if (!te4) te4 = {}; "
"(function() { "
"	te4.run = function(code, cb) { "
"		if (!cb) { lua(code); return; } "
" "
"		code = \"require'Json2' return json.encode(\"+code+\")\"; "
"		lua(code, function(ret) { "
"			var data = JSON.parse(ret); "
"			cb(data); "
"		}); "
"	}; "
"	te4.event = function(kind, data) { "
"		if (typeof data == 'string') luaevent(kind, data); "
"		else luaevent(kind, JSON.stringify(data));"
"	}; "
"})(); "
	;

	// Register the extension.
	CefRegisterExtension("v8/test", extensionCode, NULL);
}

void TE4RenderProcessHandler::OnContextCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, CefRefPtr<CefV8Context> context) {
	// Retrieve the context's window object.
	CefRefPtr<CefV8Value> object = context->GetGlobal();

	CefRefPtr<CefV8Handler> handler = new TE4V8Handler();
	object->SetValue("lua", CefV8Value::CreateFunction("lua", handler), V8_PROPERTY_ATTRIBUTE_NONE);
	object->SetValue("luaevent", CefV8Value::CreateFunction("luaevent", handler), V8_PROPERTY_ATTRIBUTE_NONE);
}

bool TE4ClientApp::processCallback(CefRefPtr<CefBrowser> browser, CefRefPtr<CefProcessMessage> message) {
	// Execute the registered JavaScript callback if any.
	if (callback_map.empty()) { return false; }
	CefRefPtr<CefListValue> list = message->GetArgumentList();
	if (list->GetSize() == 0) { return false; }

	// First argument is the callback id
	int cb_id = list->GetInt(0);
	CallbackMap::iterator it = callback_map.find(cb_id);
	if (it == callback_map.end()) { return false; }

	// Keep a local reference to the objects. The callback may remove itself
	// from the callback map.
	CefRefPtr<CefV8Context> context = it->second.first;
	CefRefPtr<CefV8Value> callback = it->second.second;

	context->Enter();
	CefV8ValueList arguments;
	if (list->GetSize() == 2 && list->GetType(1) == VTYPE_STRING) {
		// printf("===1 %s\n", cstring_to_c(list->GetString(1)));
		arguments.push_back(CefV8Value::CreateString(list->GetString(1)));
	}
	callback->ExecuteFunction(NULL, arguments);
	context->Exit();

	callback_map.erase(it);

	return true;
}

void TE4ClientApp::sendCallback(CefRefPtr<CefBrowser> browser, int cb_id, char *ret, size_t len) {
	CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("js_callback");
	CefRefPtr<CefListValue> list = message->GetArgumentList();
	list->SetSize(2);
	list->SetInt(0, cb_id);
	if (len) {
		CefString str(ret);
		list->SetString(1, str);
	} else {
		list->SetNull(1);
	}
	browser->SendProcessMessage(PID_RENDERER, message);
}
