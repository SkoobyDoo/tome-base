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
extern int luaopen_colors (lua_State *L);
extern int luaopen_core_mouse(lua_State *L);
extern int luaopen_navmesh(lua_State *L);
extern int luaopen_particles_system(lua_State *L);
extern int luaopen_map2d(lua_State *L);

extern int luaopen_loader(lua_State *L);
extern void loader_tick();

extern int luaopen_wait(lua_State *L);
extern bool draw_waiting(lua_State *L);
extern bool is_waiting();

extern void create_particles_thread();
extern void free_particles_thread();
extern void free_profile_thread();
extern void lua_particles_system_clean();
extern void threaded_runner_keyframe(float nb_keyframes);

extern void copy_surface_to_texture(SDL_Surface *s);
extern GLenum sdl_gl_texture_format(SDL_Surface *s);
