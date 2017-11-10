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
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "auxiliar.h"
#include <time.h>
}
#include "discord-rpc.h"

static const char* APPLICATION_ID = "378483863044882443";

static time_t start_time;

static int lua_discord_update(lua_State *L)
{
	if (!lua_istable(L, 1)) {
		lua_pushstring(L, "Table required");
		lua_error(L);
		return 0;		
	}

	char buffer[256];
	DiscordRichPresence discordPresence;
	memset(&discordPresence, 0, sizeof(discordPresence));

	lua_pushliteral(L, "state");
	lua_gettable(L, -2);
	if (lua_isstring(L, -1)) discordPresence.state = lua_tostring(L, -1);
	lua_pop(L, 1);

	lua_pushliteral(L, "details");
	lua_gettable(L, -2);
	if (lua_isstring(L, -1)) discordPresence.details = lua_tostring(L, -1);
	lua_pop(L, 1);

	lua_pushliteral(L, "large_image");
	lua_gettable(L, -2);
	if (lua_isstring(L, -1)) discordPresence.largeImageKey = lua_tostring(L, -1);
	lua_pop(L, 1);

	lua_pushliteral(L, "small_image");
	lua_gettable(L, -2);
	if (lua_isstring(L, -1)) discordPresence.smallImageKey = lua_tostring(L, -1);
	lua_pop(L, 1);

	lua_pushliteral(L, "large_image_text");
	lua_gettable(L, -2);
	if (lua_isstring(L, -1)) discordPresence.largeImageText = lua_tostring(L, -1);
	lua_pop(L, 1);

	lua_pushliteral(L, "small_image_text");
	lua_gettable(L, -2);
	if (lua_isstring(L, -1)) discordPresence.smallImageText = lua_tostring(L, -1);
	lua_pop(L, 1);

	discordPresence.startTimestamp = start_time;

	printf("[Discord] updating state: \"%s\" / \"%s\" / %s / %s\n", discordPresence.state ? discordPresence.state : "--", discordPresence.details ? discordPresence.details : "--", discordPresence.largeImageKey ? discordPresence.largeImageKey : "--", discordPresence.smallImageKey ? discordPresence.smallImageKey : "--");

	// discordPresence.endTimestamp = time(0) + 5 * 60;
	// discordPresence.partyId = "party1234";
	// discordPresence.partySize = 1;
	// discordPresence.partyMax = 6;
	// discordPresence.instance = 0;
	Discord_UpdatePresence(&discordPresence);
	return 0;
}

static void handleDiscordReady() {
	printf("Discord: ready\n");
}

static void handleDiscordDisconnected(int errcode, const char* message) {
	printf("Discord: disconnected (%d: %s)\n", errcode, message);
}

static void handleDiscordError(int errcode, const char* message) {
	printf("Discord: error (%d: %s)\n", errcode, message);
}

static void handleDiscordJoin(const char* secret) {
}

static void handleDiscordSpectate(const char* secret) {
}

static void handleDiscordJoinRequest(const DiscordJoinRequest* request) {
	Discord_Respond(request->userId, DISCORD_REPLY_NO);
}

static int lua_discord_init(lua_State *L) {
	DiscordEventHandlers handlers;
	memset(&handlers, 0, sizeof(handlers));
	handlers.ready = handleDiscordReady;
	handlers.disconnected = handleDiscordDisconnected;
	handlers.errored = handleDiscordError;
	handlers.joinGame = handleDiscordJoin;
	handlers.spectateGame = handleDiscordSpectate;
	handlers.joinRequest = handleDiscordJoinRequest;
	Discord_Initialize(APPLICATION_ID, &handlers, 1, "259680");
	return 0;
}

static const struct luaL_Reg discordlib[] = {
	{"init", lua_discord_init},
	{"updatePresence", lua_discord_update},
	{NULL, NULL},
};

extern "C" int luaopen_discord(lua_State *L) {
	start_time = time(0);
	luaL_openlib(L, "core.discord", discordlib, 0);

	lua_settop(L, 0);
	return 1;
}

extern "C" void te4_discord_update() {
	Discord_RunCallbacks();
}
