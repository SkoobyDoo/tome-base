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

void te4_web_focus(web_view_type *view, bool focus) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;
	
	opaque->browser->GetHost()->SendFocusEvent(focus);
}

static int get_cef_state_modifiers() {
	bool shift, ctrl, alt, meta;
	web_key_mods(&shift, &ctrl, &alt, &meta);

	int modifiers = 0;
	if (shift)
		modifiers |= EVENTFLAG_SHIFT_DOWN;
	else if (ctrl)
		modifiers |= EVENTFLAG_CONTROL_DOWN;
	else if (alt)
		modifiers |= EVENTFLAG_ALT_DOWN;

	return modifiers;
}

void te4_web_inject_mouse_move(web_view_type *view, int x, int y) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;

	view->last_mouse_x = x;
	view->last_mouse_y = y;
	CefMouseEvent mouse_event;
	mouse_event.x = x;
	mouse_event.y = y;
	mouse_event.modifiers = get_cef_state_modifiers();

	opaque->browser->GetHost()->SendMouseMoveEvent(mouse_event, false);
}

void te4_web_inject_mouse_wheel(web_view_type *view, int x, int y) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;
	
	CefMouseEvent mouse_event;
	mouse_event.x = view->last_mouse_x;
	mouse_event.y = view->last_mouse_y;
	mouse_event.modifiers = get_cef_state_modifiers();
	opaque->browser->GetHost()->SendMouseWheelEvent(mouse_event, -x, -y);
}

void te4_web_inject_mouse_button(web_view_type *view, int kind, bool up) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;
	
	CefBrowserHost::MouseButtonType button_type = MBT_LEFT;
	if (kind == 2) button_type = MBT_MIDDLE;
	else if (kind == 3) button_type = MBT_RIGHT;

	CefMouseEvent mouse_event;
	mouse_event.x = view->last_mouse_x;
	mouse_event.y = view->last_mouse_y;
	mouse_event.modifiers = get_cef_state_modifiers();

	opaque->browser->GetHost()->SendMouseClickEvent(mouse_event, button_type, up, 1);
}

#if defined(SELFEXE_MACOSX)
#include <Carbon/Carbon.h>

// A convenient array for getting symbol characters on the number keys.
static const char kShiftCharsForNumberKeys[] = ")!@#$%^&*(";

// Convert an ANSI character to a Mac key code.
static int GetMacKeyCodeFromChar(int key_code) {
	switch (key_code) {
		case ' ': return kVK_Space;

		case '0': case ')': return kVK_ANSI_0;
		case '1': case '!': return kVK_ANSI_1;
		case '2': case '@': return kVK_ANSI_2;
		case '3': case '#': return kVK_ANSI_3;
		case '4': case '$': return kVK_ANSI_4;
		case '5': case '%': return kVK_ANSI_5;
		case '6': case '^': return kVK_ANSI_6;
		case '7': case '&': return kVK_ANSI_7;
		case '8': case '*': return kVK_ANSI_8;
		case '9': case '(': return kVK_ANSI_9;

		case 'a': case 'A': return kVK_ANSI_A;
		case 'b': case 'B': return kVK_ANSI_B;
		case 'c': case 'C': return kVK_ANSI_C;
		case 'd': case 'D': return kVK_ANSI_D;
		case 'e': case 'E': return kVK_ANSI_E;
		case 'f': case 'F': return kVK_ANSI_F;
		case 'g': case 'G': return kVK_ANSI_G;
		case 'h': case 'H': return kVK_ANSI_H;
		case 'i': case 'I': return kVK_ANSI_I;
		case 'j': case 'J': return kVK_ANSI_J;
		case 'k': case 'K': return kVK_ANSI_K;
		case 'l': case 'L': return kVK_ANSI_L;
		case 'm': case 'M': return kVK_ANSI_M;
		case 'n': case 'N': return kVK_ANSI_N;
		case 'o': case 'O': return kVK_ANSI_O;
		case 'p': case 'P': return kVK_ANSI_P;
		case 'q': case 'Q': return kVK_ANSI_Q;
		case 'r': case 'R': return kVK_ANSI_R;
		case 's': case 'S': return kVK_ANSI_S;
		case 't': case 'T': return kVK_ANSI_T;
		case 'u': case 'U': return kVK_ANSI_U;
		case 'v': case 'V': return kVK_ANSI_V;
		case 'w': case 'W': return kVK_ANSI_W;
		case 'x': case 'X': return kVK_ANSI_X;
		case 'y': case 'Y': return kVK_ANSI_Y;
		case 'z': case 'Z': return kVK_ANSI_Z;

		// U.S. Specific mappings.  Mileage may vary.
		case ';': case ':': return kVK_ANSI_Semicolon;
		case '=': case '+': return kVK_ANSI_Equal;
		case ',': case '<': return kVK_ANSI_Comma;
		case '-': case '_': return kVK_ANSI_Minus;
		case '.': case '>': return kVK_ANSI_Period;
		case '/': case '?': return kVK_ANSI_Slash;
		case '`': case '~': return kVK_ANSI_Grave;
		case '[': case '{': return kVK_ANSI_LeftBracket;
		case '\\': case '|': return kVK_ANSI_Backslash;
		case ']': case '}': return kVK_ANSI_RightBracket;
		case '\'': case '"': return kVK_ANSI_Quote;
	}
	
	return -1;
}
#endif  // defined(OS_MACOSX)
extern "C" {
	#include <tSDL.h>
}

void te4_web_inject_key(web_view_type *view, int scancode, int asymb, const char *uni, int unilen, bool up) {
	WebViewOpaque *opaque = (WebViewOpaque*)view->opaque;
	if (view->closed) return;
	
	int key_code = scancode;

	CefKeyEvent key_event;

	key_event.modifiers = get_cef_state_modifiers();

	// OMFG ... CEF3 is very very nice, except for key handling
	// Once this will be working(-ish) I never want to take a look at that thing again.
#if defined(SELFEXE_LINUX)
	if (key_code == SDLK_BACKSPACE)
		key_event.native_key_code = 0xff08;
	else if (key_code == SDLK_DELETE)
		key_event.native_key_code = 0xffff;
	else if (key_code == SDLK_DOWN)
		key_event.native_key_code = 0xff54;
	else if (key_code == SDLK_RETURN)
		key_event.native_key_code = 0xff0d;
	else if (key_code == SDLK_ESCAPE)
		key_event.native_key_code = 0xff1b;
	else if (key_code == SDLK_LEFT)
		key_event.native_key_code = 0xff51;
	else if (key_code == SDLK_RIGHT)
		key_event.native_key_code = 0xff53;
	else if (key_code == SDLK_TAB)
		key_event.native_key_code = 0xff09;
	else if (key_code == SDLK_UP)
		key_event.native_key_code = 0xff52;
	else if (key_code == SDLK_PAGEUP)
		key_event.native_key_code = 0xff55;
	else if (key_code == SDLK_PAGEDOWN)
		key_event.native_key_code = 0xff56;
	else
		key_event.native_key_code = key_code;
#elif defined(SELFEXE_WINDOWS)
	// This has been fully untested and most certainly isnt working
	BYTE VkCode;
	if (key_code == SDLK_BACKSPACE)
		VkCode = VK_BACK;
	else if (key_code == SDLK_DELETE)
		VkCode = VK_DELETE;
	else if (key_code == SDLK_DOWN)
		VkCode = VK_DOWN;
	else if (key_code == SDLK_RETURN)
		VkCode = VK_RETURN;
	else if (key_code == SDLK_ESCAPE)
		VkCode = VK_ESCAPE;
	else if (key_code == SDLK_LEFT)
		VkCode = VK_LEFT;
	else if (key_code == SDLK_RIGHT)
		VkCode = VK_RIGHT;
	else if (key_code == SDLK_TAB)
		VkCode = VK_TAB;
	else if (key_code == SDLK_UP)
		VkCode = VK_UP;
	else if (unilen == 1 && uni[0] >= '!' && uni[0] <= '@')
		VkCode = uni[0];
	else if (unilen == 1 && uni[0] >= '[' && uni[0] <= '`')
		VkCode = uni[0];
	else if (unilen == 1 && uni[0] >= '{' && uni[0] <= '~')
		VkCode = uni[0];
	else if (unilen == 1 && uni[0] >= 'A' && uni[0] <= 'Z')
		VkCode = uni[0];
	else if (unilen == 1 && uni[0] >= 'a' && uni[0] <= 'z')
		VkCode = uni[0];
	else if (unilen == 1 && uni[0] >= 'a' && uni[0] <= 'z')
		VkCode = uni[0];
	else
		VkCode = LOBYTE(VkKeyScanA(key_code));
	UINT scanCode = MapVirtualKey(VkCode, MAPVK_VK_TO_VSC);
	key_event.native_key_code = (scanCode << 16) |  // key scan code
                              1;  // key repeat count
	key_event.windows_key_code = VkCode;
#elif defined(SELFEXE_MACOSX)
	if (key_code == SDLK_BACKSPACE) {
		key_event.native_key_code = kVK_Delete;
		key_event.unmodified_character = kBackspaceCharCode;
	} else if (key_code == SDLK_DELETE) {
		key_event.native_key_code = kVK_ForwardDelete;
		key_event.unmodified_character = kDeleteCharCode;
	} else if (key_code == SDLK_DOWN) {
		key_event.native_key_code = kVK_DownArrow;
		key_event.unmodified_character = /* NSDownArrowFunctionKey */ 0xF701;
	} else if (key_code == SDLK_RETURN) {
		key_event.native_key_code = kVK_Return;
		key_event.unmodified_character = kReturnCharCode;
	} else if (key_code == SDLK_ESCAPE) {
		key_event.native_key_code = kVK_Escape;
		key_event.unmodified_character = kEscapeCharCode;
	} else if (key_code == SDLK_LEFT) {
		key_event.native_key_code = kVK_LeftArrow;
		key_event.unmodified_character = /* NSLeftArrowFunctionKey */ 0xF702;
	} else if (key_code == SDLK_RIGHT) {
		key_event.native_key_code = kVK_RightArrow;
		key_event.unmodified_character = /* NSRightArrowFunctionKey */ 0xF703;
	} else if (key_code == SDLK_TAB) {
		key_event.native_key_code = kVK_Tab;
		key_event.unmodified_character = kTabCharCode;
	} else if (key_code == SDLK_UP) {
		key_event.native_key_code = kVK_UpArrow;
		key_event.unmodified_character = /* NSUpArrowFunctionKey */ 0xF700;
	} else {
		key_event.native_key_code = GetMacKeyCodeFromChar(key_code);
		if (key_event.native_key_code == -1)
			return;
		
		key_event.unmodified_character = key_code;
	}

	key_event.character = key_event.unmodified_character;

	// Fill in |character| according to flags.
	if (key_event.modifiers & EVENTFLAG_SHIFT_DOWN) {
		if (key_code >= '0' && key_code <= '9') {
			key_event.character = kShiftCharsForNumberKeys[key_code - '0'];
		} else if (key_code >= 'A' && key_code <= 'Z') {
			key_event.character = 'A' + (key_code - 'A');
		} else {
			switch (key_event.native_key_code) {
				case kVK_ANSI_Grave:
					key_event.character = '~';
					break;
				case kVK_ANSI_Minus:
					key_event.character = '_';
					break;
				case kVK_ANSI_Equal:
					key_event.character = '+';
					break;
				case kVK_ANSI_LeftBracket:
					key_event.character = '{';
					break;
				case kVK_ANSI_RightBracket:
					key_event.character = '}';
					break;
				case kVK_ANSI_Backslash:
					key_event.character = '|';
					break;
				case kVK_ANSI_Semicolon:
					key_event.character = ':';
					break;
				case kVK_ANSI_Quote:
					key_event.character = '\"';
					break;
				case kVK_ANSI_Comma:
					key_event.character = '<';
					break;
				case kVK_ANSI_Period:
					key_event.character = '>';
					break;
				case kVK_ANSI_Slash:
					key_event.character = '?';
					break;
				default:
					break;
			}
		}
	}

	// Control characters.
	if (key_event.modifiers & EVENTFLAG_CONTROL_DOWN) {
		if (key_code >= 'A' && key_code <= 'Z')
			key_event.character = 1 + key_code - 'A';
		else if (key_event.native_key_code == kVK_ANSI_LeftBracket)
			key_event.character = 27;
		else if (key_event.native_key_code == kVK_ANSI_Backslash)
			key_event.character = 28;
		else if (key_event.native_key_code == kVK_ANSI_RightBracket)
			key_event.character = 29;
	}
#else
	// Try a fallback..
	key_event.native_key_code = key_code;
#endif

	key_event.unmodified_character = key_code;
	key_event.character = key_event.unmodified_character;
	key_event.modifiers = get_cef_state_modifiers();

	if (unilen) {
		key_event.type = KEYEVENT_RAWKEYDOWN;
		opaque->browser->GetHost()->SendKeyEvent(key_event);
		key_event.type = KEYEVENT_KEYUP;
		opaque->browser->GetHost()->SendKeyEvent(key_event);
		key_event.type = KEYEVENT_CHAR;
		opaque->browser->GetHost()->SendKeyEvent(key_event);
	} else if (!up) {
		key_event.type = KEYEVENT_KEYDOWN;
		opaque->browser->GetHost()->SendKeyEvent(key_event);
	} else {
		// Need to send both KEYUP and CHAR events.
		key_event.type = KEYEVENT_KEYUP;
		opaque->browser->GetHost()->SendKeyEvent(key_event);
	}
}
