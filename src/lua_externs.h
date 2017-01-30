/* Some lua stuff that's external but has no headers */
extern int luaopen_bit(lua_State *L);
extern int luaopen_diamond_square(lua_State *L);
extern int luaopen_fov(lua_State *L);
extern int luaopen_gas(lua_State *L);
extern int luaopen_lanes(lua_State *L);
extern int luaopen_lpeg(lua_State *L);
extern int luaopen_lxp(lua_State *L);
extern int luaopen_map(lua_State *L);
extern int luaopen_md5_core (lua_State *L);
extern int luaopen_mime_core(lua_State *L);
extern int luaopen_noise(lua_State *L);
extern int luaopen_particles(lua_State *L);
extern int luaopen_physfs(lua_State *L);
extern int luaopen_profiler(lua_State *L);
extern int luaopen_shaders(lua_State *L);
extern int luaopen_socket_core(lua_State *L);
extern int luaopen_sound(lua_State *L);
extern int luaopen_struct(lua_State *L);
extern int luaopen_zlib (lua_State *L);

extern int luaopen_wait(lua_State *L);
extern bool draw_waiting(lua_State *L);
extern bool is_waiting();

extern void create_particles_thread();
extern void free_particles_thread();
extern void free_profile_thread();
