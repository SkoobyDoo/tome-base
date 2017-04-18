/*
	TE4 - T-Engine 4
	Copyright (C) 2009 - 2017 Nicolas Casalini

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
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include "lua_wfc_external.h"
}
#include "stdlib.h"
#include "string.h"
#include "lua_wfc.hpp"

static WFCOverlapping *parse_config_overlapping(lua_State *L) {
	WFCOverlapping *config = new WFCOverlapping();

	config->output.w = luaL_checknumber(L, 2);
	config->output.h = luaL_checknumber(L, 3);
	config->n = luaL_checknumber(L, 4);
	config->symmetry = luaL_checknumber(L, 5);
	config->periodic_out = lua_toboolean(L, 6);
	config->periodic_in = lua_toboolean(L, 7);
	config->has_foundation = lua_toboolean(L, 8);

	// Iterate the sample lines
	config->sample_w = 9999;
	config->sample_h = lua_objlen(L, 1);
	config->sample = (unsigned char**)malloc(config->sample_h * sizeof(unsigned char *));
	for (int y = 0; y < config->sample_h; y++) {
		lua_rawgeti(L, 1, y + 1);

		size_t len;
		unsigned char *line = (unsigned char*)strdup(luaL_checklstring(L, -1, &len));
		config->sample[y] = line;
		if (len < config->sample_w) config->sample_w = len;
		// printf("==sample line %d: '%s' len(%d)\n", y, line, len);

		lua_pop(L, 1);
	}

	// Generate output data
	config->output.data = (unsigned char**)malloc(config->output.h * sizeof(unsigned char *));
	for (int y = 0; y < config->output.h; y++) {
		config->output.data[y] = (unsigned char*)calloc(config->output.w, sizeof(unsigned char));
	}
	return config;
}

static void free_config_overlapping(WFCOverlapping *config) {
	for (int y = 0; y < config->sample_h; y++) free(config->sample[y]);
	for (int y = 0; y < config->output.h; y++) free(config->output.data[y]);
	free(config->sample);
	free(config->output.data);
	delete config;
}

static void generate_table_from_output(lua_State *L, WFCOutput *output) {
	lua_newtable(L);
	// printf("===========RESULT\n");
	for (int y = 0; y < output->h; y++) {
		// for (int x = 0; x < output->w; x++) {
			// printf("%c", output->data[y][x]);
		// }
		// printf("\n");
		
		lua_pushlstring(L, (const char*)output->data[y], output->w);
		lua_rawseti(L, -2, y + 1);
	}
	// printf("===========\n");
}

static int lua_wfc_overlapping(lua_State *L) {
	WFCOverlapping *config = parse_config_overlapping(L);

	if (wfc_generate_overlapping(config)) {
		generate_table_from_output(L, &config->output);
	} else {
		lua_pushnil(L);
	}

	// Cleanup
	free_config_overlapping(config);

	return 1;
}

static int thread_generate_overlapping(void *ptr) {
	WFCOverlapping *config = (WFCOverlapping*)ptr;
	if (wfc_generate_overlapping(config)) {
		return 1;
	} else {
		return 0;
	}
}

static int lua_wfc_overlapping_async(lua_State *L) {
	WFCOverlapping *config = parse_config_overlapping(L);

	SDL_Thread *thread = SDL_CreateThread(thread_generate_overlapping, "particles", config);

	WFCAsync *async = (WFCAsync*)lua_newuserdata(L, sizeof(WFCAsync));
	auxiliar_setclass(L, "wfc{async}", -1);
	async->mode = WFCAsyncMode::OVERLAPPING;
	async->overlapping_config = config;
	async->thread = thread;
	return 1;
}

static int lua_wfc_wait_all_async(lua_State *L) {
	return 0;
}

static int lua_wfc_wait_async(lua_State *L) {
	WFCAsync *async = (WFCAsync*)auxiliar_checkclass(L, "wfc{async}", 1);
	
	int ret;
	SDL_WaitThread(async->thread, &ret);
	
	WFCOutput *output;
	if (async->mode == WFCAsyncMode::OVERLAPPING) output = &async->overlapping_config->output;

	if (ret == 1) {
		generate_table_from_output(L, output);
	} else {
		lua_pushnil(L);
	}

	// Cleanup
	if (async->mode == WFCAsyncMode::OVERLAPPING) free_config_overlapping(async->overlapping_config);

	return 1;
}

static const struct luaL_Reg async_reg[] =
{
	{"wait", lua_wfc_wait_async},
	{NULL, NULL},
};

static const struct luaL_Reg wfclib[] =
{
	{"asyncOverlapping", lua_wfc_overlapping_async},
	{"asyncWaitAll", lua_wfc_wait_all_async},
	{"overlapping", lua_wfc_overlapping},
	{NULL, NULL},
};

int luaopen_wfc(lua_State *L) {
	auxiliar_newclass(L, "wfc{async}", async_reg);
	luaL_openlib(L, "core.generator.wfc", wfclib, 0);
	lua_settop(L, 0);
	return 1;
}
