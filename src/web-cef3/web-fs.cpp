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

#include <map>

extern "C" {
#include "web-external.h"
#include <stdio.h>
#include <stdlib.h>
}
#include "web.h"
#include "web-internal.h"
#include <map>

class TE4ResourceHandler;
static std::map<int, TE4ResourceHandler*> requests;
static int requests_next = 1;

// Implementation of the resource handler for client requests.
class TE4ResourceHandler : public CefResourceHandler {
private:
	int id;

	size_t len, where;
	void *result;
	CefString *mime;

	CefRefPtr<CefCallback> cb;
public:
	TE4ResourceHandler() {
		id = requests_next++;
		requests[id] = this;
		// printf("NEW HANDLER================\n");
	}
	~TE4ResourceHandler() {
		delete mime;
		free(result);
	}

	void setData(const char *mime, const char *result, size_t len) {
		if (!len) { this->cb->Cancel(); return; }

		this->mime = new CefString(mime);
		this->len = len;
		this->where = 0;
		this->result = malloc(len);
		memcpy(this->result, result, len);

		this->cb->Continue();
		this->cb = NULL;
	}

	virtual bool ProcessRequest(CefRefPtr<CefRequest> request, CefRefPtr<CefCallback> callback) OVERRIDE {
		const char *path = cstring_to_c(request->GetURL());
		WebEvent *event = new WebEvent();
		event->kind = TE4_WEB_EVENT_LOCAL_REQUEST;
		event->handlers = 0;
		event->data.local_request.id = id;
		event->data.local_request.path = path;
		push_event(event);
		this->cb = callback;
		return true;
	}

	virtual void GetResponseHeaders(CefRefPtr<CefResponse> response, int64& response_length, CefString& redirectUrl) OVERRIDE {
		// Populate the response headers.
		response->SetMimeType(*mime);
		response->SetStatus(200);

		// Specify the resulting response length.
		response_length = (int64)len;
	}

	virtual void Cancel() OVERRIDE {
		// Cancel the response...
	}

	virtual bool ReadResponse(void* data_out, int bytes_to_read, int& bytes_read, CefRefPtr<CefCallback> callback) OVERRIDE {
		// printf("Returning response %d\n", bytes_to_read);
		if (len > (size_t)bytes_to_read) bytes_read = bytes_to_read;
		else bytes_read = len;
		memcpy(data_out, (char*)result + where, bytes_read);
		where += bytes_read;
		len -= bytes_read;
		return true;
	}

private:
	IMPLEMENT_REFCOUNTING(TE4ResourceHandler);
};

CefRefPtr<CefResourceHandler> TE4SchemeHandlerFactory::Create(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame, const CefString& scheme_name, CefRefPtr<CefRequest> request) OVERRIDE {
	return new TE4ResourceHandler();
}

void te4_web_reply_local(int id, const char *mime, const char *result, size_t len) {
	TE4ResourceHandler *handler = requests[id];
	requests.erase(id);

	handler->setData(mime, result, len);
}
