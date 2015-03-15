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
	if (name == "lua" && arguments.size() == 2 && arguments[0]->IsString() && arguments[1]->IsFunction()) {
		CefRefPtr<CefV8Context> context = CefV8Context::GetCurrentContext();

		int cb_id = next_cb_id++;
		app->callback_map[cb_id] = std::make_pair(context, arguments[1]);
		// retval = CefV8Value::CreateString("My Value!");

		printf("New callback registered for method 'lua': %d\n", cb_id);

		WebEvent *event = new WebEvent();
		event->kind = TE4_WEB_EVENT_RUN_LUA;
		event->data.run_lua.cb_id = cb_id;
		event->data.run_lua.code = cstring_to_c(arguments[0]->GetStringValue());
		push_event(event);

		return true;
	}
	return false;
}

bool TE4ClientApp::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefProcessId source_process, CefRefPtr<CefProcessMessage> message) {
	bool handled = false;

	printf("Receiving IPC message '%s'\n", (char*)message->GetName().c_str());

	if (message->GetName() == "js_callback") handled = processCallback(browser, message);

	return handled;
}

bool TE4ClientApp::processCallback(CefRefPtr<CefBrowser> browser, CefRefPtr<CefProcessMessage> message) {
	// Execute the registered JavaScript callback if any.
	if (callback_map.empty()) return false;
	CefRefPtr<CefListValue> list = message->GetArgumentList();
	if (list->GetSize() == 0) return false;

	// First argument is the callback id
	int cb_id = list->GetInt(0);
	CallbackMap::iterator it = callback_map.find(cb_id);

	if (it == callback_map.end()) return false;

	// Keep a local reference to the objects. The callback may remove itself
	// from the callback map.
	CefRefPtr<CefV8Context> context = it->second.first;
	CefRefPtr<CefV8Value> callback = it->second.second;

	// Enter the context.
	context->Enter();

	CefV8ValueList arguments;

	// // First argument is the message name.
	// arguments.push_back(CefV8Value::CreateString(message_name));

	// // Second argument is the list of message arguments.
	// CefRefPtr<CefListValue> list = message->GetArgumentList();
	// CefRefPtr<CefV8Value> args = CefV8Value::CreateArray(static_cast<int>(list->GetSize()));
	// SetList(list, args);
	// arguments.push_back(args);

	// Execute the callback.
	CefRefPtr<CefV8Value> retval = callback->ExecuteFunction(NULL, arguments);

	// Exit the context.
	context->Exit();

	callback_map.erase(it);

	return true;
}

void TE4ClientApp::sendCallback(int cb_id) {
}

void te4_web_js_callback(web_view_type *view, int cb_id, WebJsValue *args) {

}
