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

#ifndef __TE4WEB_EXTERNAL_H__
#define __TE4WEB_EXTERNAL_H__

enum web_event_kind {
	// Internal stuff
	TE4_WEB_EVENT_DELETE_TEXTURE,

	// Eternal stuff
	TE4_WEB_EVENT_TITLE_CHANGE,
	TE4_WEB_EVENT_REQUEST_POPUP_URL,
	TE4_WEB_EVENT_DOWNLOAD_REQUEST,
	TE4_WEB_EVENT_DOWNLOAD_UPDATE,
	TE4_WEB_EVENT_DOWNLOAD_FINISH,
	TE4_WEB_EVENT_LOADING,
	TE4_WEB_EVENT_LOCAL_REQUEST,
	TE4_WEB_EVENT_RUN_LUA,
	TE4_WEB_EVENT_END_BROWSER,
	TE4_WEB_EVENT_BROWSER_COUNT,
};

typedef struct {
	enum web_event_kind kind;
	int handlers;
	union {
		const char *title;
		struct {
			const char *url;
			int w, h;
		} popup;
		struct {
			long id;
			const char *url;
			const char *mime;
			const char *name;
		} download_request;
		struct {
			long id;
			long total, got, speed;
			int percent;
		} download_update;
		struct {
			long id;
		} download_finish;
		struct {
			const char *url;
			signed char status;
		} loading;
		struct {
			int id;
			const char *path;
		} local_request;
		struct {
			int cb_id;
			const char *code;
		} run_lua;
		void *texture;
		int count;
	} data;
} WebEvent;

typedef struct {
	void *opaque;
	int w, h;
	int last_mouse_x, last_mouse_y;
	int handlers;
	bool closed;
} web_view_type;

#endif
