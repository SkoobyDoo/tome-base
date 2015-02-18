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
#include "display.h"
#include "fov/fov.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "types.h"
#include "script.h"
#include "display.h"
#include "physfs.h"
#include "physfsrwops.h"
#include "SFMT.h"
#include "mzip.h"
#include "zlib.h"
#include "main.h"
#include "useshader.h"
#include "core_lua.h"
#include "vertex_objects.h"
#include <math.h>
#include <time.h>
#include <locale.h>

#ifdef __APPLE__
#include <libpng/png.h>
#else
#include <png.h>
#endif

extern SDL_Window *window;

/******************************************************************
 ******************************************************************
 *                             Mouse                              *
 ******************************************************************
 ******************************************************************/
static int lua_get_mouse(lua_State *L)
{
	int x = 0, y = 0;
	int buttons = SDL_GetMouseState(&x, &y);

	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	lua_pushnumber(L, SDL_BUTTON(buttons));

	return 3;
}
static int lua_set_mouse(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	SDL_WarpMouseInWindow(window, x, y);
	return 0;
}
extern int current_mousehandler;
static int lua_set_current_mousehandler(lua_State *L)
{
	if (current_mousehandler != LUA_NOREF)
		luaL_unref(L, LUA_REGISTRYINDEX, current_mousehandler);

	if (lua_isnil(L, 1))
		current_mousehandler = LUA_NOREF;
	else
		current_mousehandler = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}
static int lua_mouse_show(lua_State *L)
{
	SDL_ShowCursor(lua_toboolean(L, 1) ? TRUE : FALSE);
	return 0;
}

static int lua_is_touch_enabled(lua_State *L)
{
	lua_pushboolean(L, SDL_GetNumTouchDevices() > 0);
	return 1;
}

static int lua_is_gamepad_enabled(lua_State *L)
{
	if (!SDL_NumJoysticks()) return 0;
	const char *str = SDL_JoystickNameForIndex(0);
	lua_pushstring(L, str);
	return 1;
}

static const struct luaL_Reg mouselib[] =
{
	{"touchCapable", lua_is_touch_enabled},
	{"gamepadCapable", lua_is_gamepad_enabled},
	{"show", lua_mouse_show},
	{"get", lua_get_mouse},
	{"set", lua_set_mouse},
	{"set_current_handler", lua_set_current_mousehandler},
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                              Keys                              *
 ******************************************************************
 ******************************************************************/
extern int current_keyhandler;
static int lua_set_current_keyhandler(lua_State *L)
{
	if (current_keyhandler != LUA_NOREF)
		luaL_unref(L, LUA_REGISTRYINDEX, current_keyhandler);

	if (lua_isnil(L, 1))
		current_keyhandler = LUA_NOREF;
	else
		current_keyhandler = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}
static int lua_get_mod_state(lua_State *L)
{
	const char *mod = luaL_checkstring(L, 1);
	SDL_Keymod smod = SDL_GetModState();

	if (!strcmp(mod, "shift")) lua_pushboolean(L, smod & KMOD_SHIFT);
	else if (!strcmp(mod, "ctrl")) lua_pushboolean(L, smod & KMOD_CTRL);
	else if (!strcmp(mod, "alt")) lua_pushboolean(L, smod & KMOD_ALT);
	else if (!strcmp(mod, "meta")) lua_pushboolean(L, smod & KMOD_GUI);
	else if (!strcmp(mod, "caps")) lua_pushboolean(L, smod & KMOD_CAPS);
	else lua_pushnil(L);

	return 1;
}
static int lua_get_scancode_name(lua_State *L)
{
	SDL_Scancode code = luaL_checknumber(L, 1);
	lua_pushstring(L, SDL_GetScancodeName(code));

	return 1;
}
static int lua_flush_key_events(lua_State *L)
{
	SDL_FlushEvents(SDL_KEYDOWN, SDL_TEXTINPUT);
	return 0;
}

static int lua_key_unicode(lua_State *L)
{
	if (lua_isboolean(L, 1)) SDL_StartTextInput();
	else SDL_StopTextInput();
	return 0;
}

static int lua_key_set_clipboard(lua_State *L)
{
	char *str = (char*)luaL_checkstring(L, 1);
	SDL_SetClipboardText(str);
	return 0;
}

static int lua_key_get_clipboard(lua_State *L)
{
	if (SDL_HasClipboardText())
	{
		char *str = SDL_GetClipboardText();
		if (str)
		{
			lua_pushstring(L, str);
			SDL_free(str);
		}
		else
			lua_pushnil(L);
	}
	else
		lua_pushnil(L);
	return 1;
}

static const struct luaL_Reg keylib[] =
{
	{"set_current_handler", lua_set_current_keyhandler},
	{"modState", lua_get_mod_state},
	{"symName", lua_get_scancode_name},
	{"flush", lua_flush_key_events},
	{"unicodeInput", lua_key_unicode},
	{"getClipboard", lua_key_get_clipboard},
	{"setClipboard", lua_key_set_clipboard},
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                              Game                              *
 ******************************************************************
 ******************************************************************/
extern int current_game;
static int lua_set_current_game(lua_State *L)
{
	if (current_game != LUA_NOREF)
		luaL_unref(L, LUA_REGISTRYINDEX, current_game);

	if (lua_isnil(L, 1))
		current_game = LUA_NOREF;
	else
		current_game = luaL_ref(L, LUA_REGISTRYINDEX);

	return 0;
}
extern bool exit_engine;
static int lua_exit_engine(lua_State *L)
{
	exit_engine = TRUE;
	return 0;
}
static int lua_reboot_lua(lua_State *L)
{
	core_def->define(
		core_def,
		luaL_checkstring(L, 1),
		luaL_checknumber(L, 2),
		luaL_checkstring(L, 3),
		luaL_checkstring(L, 4),
		luaL_checkstring(L, 5),
		luaL_checkstring(L, 6),
		lua_toboolean(L, 7),
		luaL_checkstring(L, 8)
		);

	// By default reboot the same core -- this skips some initializations
	if (core_def->corenum == -1) core_def->corenum = TE4CORE_VERSION;

	return 0;
}
static int lua_get_time(lua_State *L)
{
	lua_pushnumber(L, SDL_GetTicks());
	return 1;
}
static int lua_get_frame_time(lua_State *L)
{
	lua_pushnumber(L, cur_frame_tick);
	return 1;
}
static int lua_set_realtime(lua_State *L)
{
	float freq = luaL_checknumber(L, 1);
	setupRealtime(freq);
	return 0;
}
static int lua_set_fps(lua_State *L)
{
	float freq = luaL_checknumber(L, 1);
	setupDisplayTimer(freq);
	return 0;
}
static int lua_sleep(lua_State *L)
{
	int ms = luaL_checknumber(L, 1);
	SDL_Delay(ms);
	return 0;
}

static int lua_check_error(lua_State *L)
{
	if (!last_lua_error_head) return 0;

	int n = 1;
	lua_newtable(L);
	lua_err_type *cur = last_lua_error_head;
	while (cur)
	{
		if (cur->err_msg) lua_pushfstring(L, "Lua Error: %s", cur->err_msg);
		else lua_pushfstring(L, "  At %s:%d %s", cur->file, cur->line, cur->func);
		lua_rawseti(L, -2, n++);
		cur = cur->next;
	}

	del_lua_error();
	return 1;
}

static char *reboot_message = NULL;
static int lua_set_reboot_message(lua_State *L)
{
	const char *msg = luaL_checkstring(L, 1);
	if (reboot_message) { free(reboot_message); }
	reboot_message = strdup(msg);
	return 0;
}
static int lua_get_reboot_message(lua_State *L)
{
	if (reboot_message) {
		lua_pushstring(L, reboot_message);
		free(reboot_message);
		reboot_message = NULL;
	} else lua_pushnil(L);
	return 1;
}

static int lua_reset_locale(lua_State *L)
{
	setlocale(LC_NUMERIC, "C");
	return 0;
}

static const struct luaL_Reg gamelib[] =
{
	{"setRebootMessage", lua_set_reboot_message},
	{"getRebootMessage", lua_get_reboot_message},
	{"reboot", lua_reboot_lua},
	{"set_current_game", lua_set_current_game},
	{"exit_engine", lua_exit_engine},
	{"getTime", lua_get_time},
	{"getFrameTime", lua_get_frame_time},
	{"sleep", lua_sleep},
	{"setRealtime", lua_set_realtime},
	{"setFPS", lua_set_fps},
	{"checkError", lua_check_error},
	{"resetLocale", lua_reset_locale},
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                              RNG                               *
 ******************************************************************
 ******************************************************************/

static int rng_float(lua_State *L)
{
	float min = luaL_checknumber(L, 1);
	float max = luaL_checknumber(L, 2);
	if (min < max)
		lua_pushnumber(L, genrand_real(min, max));
	else
		lua_pushnumber(L, genrand_real(max, min));
	return 1;
}

static int rng_dice(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	int i, res = 0;
	for (i = 0; i < x; i++)
		res += 1 + rand_div(y);
	lua_pushnumber(L, res);
	return 1;
}

static int rng_range(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	if (x < y)
	{
		int res = x + rand_div(1 + y - x);
		lua_pushnumber(L, res);
	}
	else
	{
		int res = y + rand_div(1 + x - y);
		lua_pushnumber(L, res);
	}
	return 1;
}

static int rng_avg(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int y = luaL_checknumber(L, 2);
	int nb = 2;
	double res = 0;
	int i;
	if (lua_isnumber(L, 3)) nb = luaL_checknumber(L, 3);
	for (i = 0; i < nb; i++)
	{
		int r = x + rand_div(1 + y - x);
		res += r;
	}
	lua_pushnumber(L, res / (double)nb);
	return 1;
}

static int rng_call(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	if (lua_isnumber(L, 2))
	{
		int y = luaL_checknumber(L, 2);
		if (x < y)
		{
			int res = x + rand_div(1 + y - x);
			lua_pushnumber(L, res);
		}
		else
		{
			int res = y + rand_div(1 + x - y);
			lua_pushnumber(L, res);
		}
	}
	else
	{
		lua_pushnumber(L, rand_div(x));
	}
	return 1;
}

static int rng_seed(lua_State *L)
{
	int seed = luaL_checknumber(L, 1);
	if (seed>=0)
		init_gen_rand(seed);
	else
		init_gen_rand(time(NULL));
	return 0;
}

static int rng_chance(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	lua_pushboolean(L, rand_div(x) == 0);
	return 1;
}

static int rng_percent(lua_State *L)
{
	int x = luaL_checknumber(L, 1);
	int res = rand_div(100);
	lua_pushboolean(L, res < x);
	return 1;
}

/*
 * The number of entries in the "randnor_table"
 */
#define RANDNOR_NUM	256

/*
 * The standard deviation of the "randnor_table"
 */
#define RANDNOR_STD	64

/*
 * The normal distribution table for the "randnor()" function (below)
 */
static int randnor_table[RANDNOR_NUM] =
{
	206, 613, 1022, 1430, 1838, 2245, 2652, 3058,
	3463, 3867, 4271, 4673, 5075, 5475, 5874, 6271,
	6667, 7061, 7454, 7845, 8234, 8621, 9006, 9389,
	9770, 10148, 10524, 10898, 11269, 11638, 12004, 12367,
	12727, 13085, 13440, 13792, 14140, 14486, 14828, 15168,
	15504, 15836, 16166, 16492, 16814, 17133, 17449, 17761,
	18069, 18374, 18675, 18972, 19266, 19556, 19842, 20124,
	20403, 20678, 20949, 21216, 21479, 21738, 21994, 22245,

	22493, 22737, 22977, 23213, 23446, 23674, 23899, 24120,
	24336, 24550, 24759, 24965, 25166, 25365, 25559, 25750,
	25937, 26120, 26300, 26476, 26649, 26818, 26983, 27146,
	27304, 27460, 27612, 27760, 27906, 28048, 28187, 28323,
	28455, 28585, 28711, 28835, 28955, 29073, 29188, 29299,
	29409, 29515, 29619, 29720, 29818, 29914, 30007, 30098,
	30186, 30272, 30356, 30437, 30516, 30593, 30668, 30740,
	30810, 30879, 30945, 31010, 31072, 31133, 31192, 31249,

	31304, 31358, 31410, 31460, 31509, 31556, 31601, 31646,
	31688, 31730, 31770, 31808, 31846, 31882, 31917, 31950,
	31983, 32014, 32044, 32074, 32102, 32129, 32155, 32180,
	32205, 32228, 32251, 32273, 32294, 32314, 32333, 32352,
	32370, 32387, 32404, 32420, 32435, 32450, 32464, 32477,
	32490, 32503, 32515, 32526, 32537, 32548, 32558, 32568,
	32577, 32586, 32595, 32603, 32611, 32618, 32625, 32632,
	32639, 32645, 32651, 32657, 32662, 32667, 32672, 32677,

	32682, 32686, 32690, 32694, 32698, 32702, 32705, 32708,
	32711, 32714, 32717, 32720, 32722, 32725, 32727, 32729,
	32731, 32733, 32735, 32737, 32739, 32740, 32742, 32743,
	32745, 32746, 32747, 32748, 32749, 32750, 32751, 32752,
	32753, 32754, 32755, 32756, 32757, 32757, 32758, 32758,
	32759, 32760, 32760, 32761, 32761, 32761, 32762, 32762,
	32763, 32763, 32763, 32764, 32764, 32764, 32764, 32765,
	32765, 32765, 32765, 32766, 32766, 32766, 32766, 32767,
};


/*
 * Generate a random integer number of NORMAL distribution
 *
 * The table above is used to generate a psuedo-normal distribution,
 * in a manner which is much faster than calling a transcendental
 * function to calculate a true normal distribution.
 *
 * Basically, entry 64*N in the table above represents the number of
 * times out of 32767 that a random variable with normal distribution
 * will fall within N standard deviations of the mean.  That is, about
 * 68 percent of the time for N=1 and 95 percent of the time for N=2.
 *
 * The table above contains a "faked" final entry which allows us to
 * pretend that all values in a normal distribution are strictly less
 * than four standard deviations away from the mean.  This results in
 * "conservative" distribution of approximately 1/32768 values.
 *
 * Note that the binary search takes up to 16 quick iterations.
 */
static int rng_normal(lua_State *L)
{
	int mean = luaL_checknumber(L, 1);
	int stand = luaL_checknumber(L, 2);
	int tmp;
	int offset;

	int low = 0;
	int high = RANDNOR_NUM;

	/* Paranoia */
	if (stand < 1)
	{
		lua_pushnumber(L, mean);
		return 1;
	}

	/* Roll for probability */
	tmp = (int)rand_div(32768);

	/* Binary Search */
	while (low < high)
	{
		long mid = (low + high) >> 1;

		/* Move right if forced */
		if (randnor_table[mid] < tmp)
		{
			low = mid + 1;
		}

		/* Move left otherwise */
		else
		{
			high = mid;
		}
	}

	/* Convert the index into an offset */
	offset = (long)stand * (long)low / RANDNOR_STD;

	/* One half should be negative */
	if (rand_div(100) < 50)
	{
		lua_pushnumber(L, mean - offset);
		return 1;
	}

	/* One half should be positive */
	lua_pushnumber(L, mean + offset);
	return 1;
}

/*
 * Generate a random floating-point number of NORMAL distribution
 *
 * Uses the Box-Muller transform.
 *
 */
static int rng_normal_float(lua_State *L)
{
	static const double TWOPI = 6.2831853071795862;
	static bool stored = FALSE;
	static double z0;
	static double z1;
	double mean = luaL_checknumber(L, 1);
	double std = luaL_checknumber(L, 2);
	double u1;
	double u2;
	if (stored == FALSE)
	{
		u1 = genrand_real1();
		u2 = genrand_real1();
		u1 = sqrt(-2 * log(u1));
		z0 = u1 * cos(TWOPI * u2);
		z1 = u1 * sin(TWOPI * u2);
		lua_pushnumber(L, (z0*std)+mean);
		stored = TRUE;
	}
	else
	{
		lua_pushnumber(L, (z1*std)+mean);
		stored = FALSE;
	}
	return 1;
}

static const struct luaL_Reg rnglib[] =
{
	{"__call", rng_call},
	{"range", rng_range},
	{"avg", rng_avg},
	{"dice", rng_dice},
	{"seed", rng_seed},
	{"chance", rng_chance},
	{"percent", rng_percent},
	{"normal", rng_normal},
	{"normalFloat", rng_normal_float},
	{"float", rng_float},
	{NULL, NULL},
};


/******************************************************************
 ******************************************************************
 *                             Line                               *
 ******************************************************************
 ******************************************************************/
typedef struct {
	int stepx;
	int stepy;
	int e;
	int deltax;
	int deltay;
	int origx;
	int origy;
	int destx;
	int desty;
} line_data;

/* ********** bresenham line drawing ********** */
static int lua_line_init(lua_State *L)
{
	int xFrom = luaL_checknumber(L, 1);
	int yFrom = luaL_checknumber(L, 2);
	int xTo = luaL_checknumber(L, 3);
	int yTo = luaL_checknumber(L, 4);
	bool start_at_end = lua_toboolean(L, 5);

	line_data *data = (line_data*)lua_newuserdata(L, sizeof(line_data));
	auxiliar_setclass(L, "core{line}", -1);

	data->origx=xFrom;
	data->origy=yFrom;
	data->destx=xTo;
	data->desty=yTo;
	data->deltax=xTo - xFrom;
	data->deltay=yTo - yFrom;
	if ( data->deltax > 0 ) {
		data->stepx=1;
	} else if ( data->deltax < 0 ){
		data->stepx=-1;
	} else data->stepx=0;
	if ( data->deltay > 0 ) {
		data->stepy=1;
	} else if ( data->deltay < 0 ){
		data->stepy=-1;
	} else data->stepy = 0;
	if ( data->stepx*data->deltax > data->stepy*data->deltay ) {
		data->e = data->stepx*data->deltax;
		data->deltax *= 2;
		data->deltay *= 2;
	} else {
		data->e = data->stepy*data->deltay;
		data->deltax *= 2;
		data->deltay *= 2;
	}

	if (start_at_end)
	{
		data->origx=xTo;
		data->origy=yTo;
	}

	return 1;
}

static int lua_line_step(lua_State *L)
{
	line_data *data = (line_data*)auxiliar_checkclass(L, "core{line}", 1);
	bool dont_stop_at_end = lua_toboolean(L, 2);

	if ( data->stepx*data->deltax > data->stepy*data->deltay ) {
		if (!dont_stop_at_end && data->origx == data->destx ) return 0;
		data->origx+=data->stepx;
		data->e -= data->stepy*data->deltay;
		if ( data->e < 0) {
			data->origy+=data->stepy;
			data->e+=data->stepx*data->deltax;
		}
	} else {
		if (!dont_stop_at_end && data->origy == data->desty ) return 0;
		data->origy+=data->stepy;
		data->e -= data->stepx*data->deltax;
		if ( data->e < 0) {
			data->origx+=data->stepx;
			data->e+=data->stepy*data->deltay;
		}
	}
	lua_pushnumber(L, data->origx);
	lua_pushnumber(L, data->origy);
	return 2;
}

static int lua_free_line(lua_State *L)
{
	(void)auxiliar_checkclass(L, "core{line}", 1);
	lua_pushnumber(L, 1);
	return 1;
}

static const struct luaL_Reg linelib[] =
{
	{"new", lua_line_init},
	{NULL, NULL},
};

static const struct luaL_Reg line_reg[] =
{
	{"__gc", lua_free_line},
	{"__call", lua_line_step},
	{NULL, NULL},
};

/******************************************************************
 ******************************************************************
 *                            ZLIB                                *
 ******************************************************************
 ******************************************************************/

static int lua_zlib_compress(lua_State *L)
{
	uLongf len;
	const char *data = luaL_checklstring(L, 1, (size_t*)&len);
	uLongf reslen = len * 1.1 + 12;
#ifdef __APPLE__
	unsigned
#endif
	char *res = malloc(reslen);
	z_stream zi;

	zi.next_in = (
#ifdef __APPLE__
	unsigned
#endif
	char *)data;
	zi.avail_in = len;
	zi.total_in = 0;

	zi.total_out = 0;

	zi.zalloc = NULL;
	zi.zfree = NULL;
	zi.opaque = NULL;

	deflateInit2(&zi, Z_BEST_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY);

	int deflateStatus;
	do {
		zi.next_out = res + zi.total_out;

		// Calculate the amount of remaining free space in the output buffer
		// by subtracting the number of bytes that have been written so far
		// from the buffer's total capacity
		zi.avail_out = reslen - zi.total_out;

		/* deflate() compresses as much data as possible, and stops/returns when
		 the input buffer becomes empty or the output buffer becomes full. If
		 deflate() returns Z_OK, it means that there are more bytes left to
		 compress in the input buffer but the output buffer is full; the output
		 buffer should be expanded and deflate should be called again (i.e., the
		 loop should continue to rune). If deflate() returns Z_STREAM_END, the
		 end of the input stream was reached (i.e.g, all of the data has been
		 compressed) and the loop should stop. */
		deflateStatus = deflate(&zi, Z_FINISH);
	}
	while (deflateStatus == Z_OK);

	if (deflateStatus == Z_STREAM_END)
	{
		lua_pushlstring(L, (char *)res, zi.total_out);
		free(res);
		return 1;
	}
	else
	{
		free(res);
		return 0;
	}
}


static const struct luaL_Reg zliblib[] =
{
	{"compress", lua_zlib_compress},
	{NULL, NULL},
};

int luaopen_core(lua_State *L)
{
	auxiliar_newclass(L, "core{line}", line_reg);
	luaL_openlib(L, "core.mouse", mouselib, 0);
	luaL_openlib(L, "core.key", keylib, 0);
	luaL_openlib(L, "core.zlib", zliblib, 0);

	luaL_openlib(L, "core.game", gamelib, 0);
	lua_pushliteral(L, "VERSION");
	lua_pushnumber(L, TE4CORE_VERSION);
	lua_settable(L, -3);

	luaL_openlib(L, "rng", rnglib, 0);
	luaL_openlib(L, "bresenham", linelib, 0);

	lua_settop(L, 0);

	return 1;
}
