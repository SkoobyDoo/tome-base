static int __KIND(color)(lua_State *L)
{
	__DISPLAY_OBJECT **c = (__DISPLAY_OBJECT**)lua_touserdata(L, 1);
	(*c)->setColor(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_tonumber(L, 5));
	return 0;
}

static int __KIND(translate)(lua_State *L)
{
	__DISPLAY_OBJECT **c = (__DISPLAY_OBJECT**)lua_touserdata(L, 1);
	(*c)->translate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int __KIND(rotate)(lua_State *L)
{
	__DISPLAY_OBJECT **c = (__DISPLAY_OBJECT**)lua_touserdata(L, 1);
	(*c)->rotate(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int __KIND(scale)(lua_State *L)
{
	__DISPLAY_OBJECT **c = (__DISPLAY_OBJECT**)lua_touserdata(L, 1);
	(*c)->scale(lua_tonumber(L, 2), lua_tonumber(L, 3), lua_tonumber(L, 4), lua_toboolean(L, 5));
	return 0;
}

static int __KIND(reset_matrix)(lua_State *L)
{
	__DISPLAY_OBJECT **c = (__DISPLAY_OBJECT**)lua_touserdata(L, 1);
	(*c)->resetModelMatrix();
	return 0;
}

static int __KIND(shown)(lua_State *L)
{
	__DISPLAY_OBJECT **c = (__DISPLAY_OBJECT**)lua_touserdata(L, 1);
	(*c)->shown(lua_toboolean(L, 2));
	return 0;
}

static int __KIND(remove_from_parent)(lua_State *L)
{
	__DISPLAY_OBJECT **c = (__DISPLAY_OBJECT**)lua_touserdata(L, 1);
	(*c)->removeFromParent();
	return 0;
}
