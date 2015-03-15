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
	return false;
}

bool TE4RenderProcessHandler::OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefProcessId source_process, CefRefPtr<CefProcessMessage> message) {
	bool handled = false;

	// printf("Renderer Receiving IPC message '%s' from %d\n", (char*)message->GetName().c_str(), source_process);

	if (message->GetName() == "js_callback") handled = app->processCallback(browser, message);

	return handled;
}

bool TE4ClientApp::processCallback(CefRefPtr<CefBrowser> browser, CefRefPtr<CefProcessMessage> message) {
	// Execute the registered JavaScript callback if any.
	if (callback_map.empty()) {printf("exit for 1\n"); return false; }
	CefRefPtr<CefListValue> list = message->GetArgumentList();
	if (list->GetSize() == 0) {printf("exit for 2\n"); return false; }

	// First argument is the callback id
	int cb_id = list->GetInt(0);
	CallbackMap::iterator it = callback_map.find(cb_id);
	if (it == callback_map.end()) {printf("exit for 3\n"); return false; }

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
	callback->ExecuteFunction(NULL, arguments);

	// Exit the context.
	context->Exit();

	callback_map.erase(it);

	return true;
}

void TE4ClientApp::sendCallback(CefRefPtr<CefBrowser> browser, int cb_id) {
	CefRefPtr<CefProcessMessage> message = CefProcessMessage::Create("js_callback");
	CefRefPtr<CefListValue> list = message->GetArgumentList();
	list->SetSize(1);
	list->SetInt(0, cb_id);
	// list->SetString(1, arguments[0]->GetStringValue());
	browser->SendProcessMessage(PID_RENDERER, message);
}
