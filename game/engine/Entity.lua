--- A game entity
-- An entity is anything that goes on a map, terrain features, objects, monsters, player, ...
-- Usually there is no need to use it directly, and it is betetr to use specific engine.Grid, engine.Actor or engine.Object
-- classes. Most modules will want to subclass those anyway to add new comportments
module(..., package.seeall, class.make)

local next_uid = 1
local entities_load_functions = {}

-- Setup the uids repository as a weak value table, when the entities are no more used anywhere else they disappear from there too
setmetatable(__uids, {__mode="v"})

local function copy_recurs(dst, src, deep)
	for k, e in pairs(src) do
		if type(e) == "table" and e.__CLASSNAME then
			dst[k] = e
		elseif not dst[k] then
			if deep then
				dst[k] = {}
				copy_recurs(dst[k], e, deep)
			else
				dst[k] = e
			end
		elseif type(dst[k]) == "table" and type(e) == "table" and not e.__CLASSNAME then
			copy_recurs(dst[k], e, deep)
		end
	end
end

--- Initialize an entity
-- Any subclass MUST call this constructor
-- @param t a table defining the basic properties of the entity
-- @usage Entity.new{display='#', color_r=255, color_g=255, color_b=255}
function _M:init(t, no_default)
	t = t or {}
	self.uid = next_uid
	__uids[self.uid] = self

	for k, e in pairs(t) do
		local ee = e
		if type(e) == "table" and not e.__CLASSNAME then ee = table.clone(e, true) end
		self[k] = ee
	end

	if self.color then
		self.color_r = self.color.r
		self.color_g = self.color.g
		self.color_b = self.color.b
		self.color_br = self.color.br
		self.color_bg = self.color.bg
		self.color_bb = self.color.bb
		self.color = nil
	end

	if not no_default then
		self.image = self.image or nil
		self.display = self.display or '.'
		self.color_r = self.color_r or 0
		self.color_g = self.color_g or 0
		self.color_b = self.color_b or 0
		self.color_br = self.color_br or -1
		self.color_bg = self.color_bg or -1
		self.color_bb = self.color_bb or -1
	end

	if self.unique and type(self.unique) ~= "string" then self.unique = self.name end

	next_uid = next_uid + 1

	self.changed = true
end

--- If we are cloned we need a new uid
function _M:cloned()
	self.uid = next_uid
	__uids[self.uid] = self
	next_uid = next_uid + 1

	self.changed = true
end

_M.__autoload = {}
_M.loadNoDelay = true
--- If we are loaded we need a new uid
function _M:loaded()
	local ouid = self.uid
	self.uid = next_uid
	__uids[self.uid] = self
	next_uid = next_uid + 1

	self.changed = true

	-- hackish :/
	if self.autoLoadedAI then self:autoLoadedAI() end
end

--- Change the entity's uid
-- <strong>*WARNING*</strong>: ONLY DO THIS IF YOU KNOW WHAT YOU ARE DOING!. YOU DO NOT !
function _M:changeUid(newuid)
	__uids[self.uid] = nil
	self.uid = newuid
	__uids[self.uid] = self
end

--- Resolves an entity
-- This is called when generatingthe final clones of an entity for use in a level.<br/>
-- This can be used to make random enchants on objects, random properties on actors, ...<br/>
-- by default this only looks for properties with a table value containing a __resolver field
function _M:resolve(t, last)
	t = t or self
	for k, e in pairs(t) do
		if type(e) == "table" and e.__resolver and (not e.__resolve_last or last) then
			t[k] = resolvers.calc[e.__resolver](e, self)
		elseif type(e) == "table" and not e.__CLASSNAME then
			self:resolve(e, last)
		end
	end

	-- Finish resolving stuff
	if t == self then
		if last then
			if self.resolveLevel then self:resolveLevel() end

			if self.unique and type(self.unique) == "boolean" then
				self.unique = self.name
			end
		else
			-- Handle ided if possible
			if self.resolveIdentify then self:resolveIdentify() end
		end
	end
end

--- Call when the entity is actually added to a level/whatever
-- This helps ensuring uniqueness of uniques
function _M:added()
	if self.unique then
		game.uniques[self.unique] = true
		print("Added unique", self.unique)
	end
end

--- Call when the entity is actually removed from existance
-- This helps ensuring uniqueness of uniques.
-- This recursively remvoes inventories too, if you need anythign special, overload this
function _M:removed()
	if self.inven then
		for _, inven in pairs(self.inven) do
			for i, o in ipairs(inven) do
				o:removed()
			end
		end
	end

	if self.unique then
		game.uniques[self.unique] = nil
		print("Removed unique", self.unique)
	end
end

--- Check for an entity's property
-- If not a function it returns it directly, otherwise it calls the function
-- with the extra parameters
-- @param prop the property name to check
function _M:check(prop, ...)
	if type(self[prop]) == "function" then return self[prop](self, ...)
	else return self[prop]
	end
end

--- Loads a list of entities from a definition file
-- @param file the file to load from
-- @param no_default if true then no default values will be assigned
-- @param res the table to load into, defaults to a new one
-- @param mod an optional function to which will be passed each entity as they are created. Can be used to adjust some values on the fly
-- @usage MyEntityClass:loadList("/data/my_entities_def.lua")
function _M:loadList(file, no_default, res, mod)
	no_default = no_default and true or false
	res = res or {}

	local f, err = nil, nil
	if entities_load_functions[file] and entities_load_functions[file][no_default] then
		print("Loading entities file from memory", file)
		f = entities_load_functions[file][no_default]
	elseif fs.exists(file) then
		f, err = loadfile(file)
		print("Loading entities file from file", file)
		entities_load_functions[file] = entities_load_functions[file] or {}
		entities_load_functions[file][no_default] = f
	else
		-- No data
		f = function() end
	end
	if err then error(err) end

	setfenv(f, setmetatable({
		resolvers = resolvers,
		DamageType = require "engine.DamageType",
		newEntity = function(t)
			-- Do we inherit things ?
			if t.base then
				-- Append array part
				for i = 1, #t.base do
					local b = t.base[i]
					if type(b) == "table" and not b.__CLASSNAME then b = table.clone(b, true)
					elseif type(b) == "table" and b.__CLASSNAME then b = b:clone()
					end
					table.insert(t, b)
				end

				for k, e in pairs(res[t.base]) do
					if k ~= "define_as" and type(k) ~= "number" then
						if not t[k] then
							t[k] = e
						elseif type(t[k]) == "table" and type(e) == "table" then
							copy_recurs(t[k], e)
						end
					end
				end
				t.base = nil
			end

			local e = self.new(t, no_default)

			if mod then mod(e) end

			res[#res+1] = e
			if t.define_as then res[t.define_as] = e end
		end,
		load = function(f, new_mod)
			self:loadList(f, no_default, res, new_mod or mod)
		end,
		loadList = function(f, new_mod)
			return self:loadList(f, no_default, nil, new_mod or mod)
		end,
	}, {__index=_G}))
	f()

	return res
end
