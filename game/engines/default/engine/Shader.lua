-- TE4 - T-Engine 4
-- Copyright (C) 2009 - 2016 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

require "engine.class"

--- Handles a particles system
-- Used by engine.Map
-- @classmod engine.Shader
module(..., package.seeall, class.make)

_M.verts = {}
_M.frags = {}
_M.progsperm = {}
_M.progs = {}
_M.progsreset = {}

loadNoDelay = true

function core.shader.allow(kind)
	return config.settings['shaders_kind_'..kind] and core.shader.active(4)
end

function _M:cleanup()
	local time = os.time()
	local todel = {}
	for name, s in pairs(self.progs) do
		if s.dieat < time then todel[name] = true end
	end
	for name, _ in pairs(todel) do
		self.progs[name] = nil
		self.progsreset[name] = nil
		print("Deleting temp shader", name)
	end
end

--- Make a shader
function _M:init(name, args, unique)
	self.args = args or {}
	if type(name) == "table" then
		self.name = name[1]
		self.shader_def = name[2]
	else
		self.name = name
	end
	self.totalname = self:makeTotalName(nil, unique)
--	print("[SHADER] making shader from", name, " into ", self.totalname)

	if args and args.require_shader then
		if not core.shader.active(4) or not core.shader.active(args.require_shader) then return end
	end
	if args and args.require_kind then
		if not core.shader.active(4) or not core.shader.allow(args.require_kind) then return end
	end

	if not core.shader.active() then return end

	if not self.args.delay_load then
		self:loaded()
	else
		self.old_meta = getmetatable(self)
		setmetatable(self, {__index=function(t, k)
			if k ~= "shad" then return _M[k] end
			print("Shader delayed load running for", t.name)
			t:loaded()
			setmetatable(t, t.old_meta)
			t.old_meta = nil
			return t.shad
		end})
	end
end

function _M:makeTotalName(add, unique)
	local str = {}
	local args = self.args
	if add then args = table.clone(add) table.merge(args, self.args) end
	for k, v in pairs(args) do
		if type(v) == "function" then v = v(self) end
		if type(v) == "number" then
			str[#str+1] = k.."="..tostring(v)
		elseif type(v) == "table" then
			if v.texture then
				if v.is3d then str[#str+1] = k.."=tex3d("..v.texture..")"
				else str[#str+1] = k.."=tex3d("..v.texture..")" end
			elseif #v == 2 then
				str[#str+1] = k.."=vec2("..v[1]..","..v[2]..")"
			elseif #v == 3 then
				str[#str+1] = k.."=vec3("..v[1]..","..v[2]..","..v[3]..")"
			elseif #v == 4 then
				str[#str+1] = k.."=vec4("..v[1]..","..v[2]..","..v[3]..","..v[4]..")"
			end
		end
	end
	table.sort(str)
	if unique then str[#str+1] = "uniqueid="..rng.range(1, 99999) end
	return self.name.."["..table.concat(str,",").."]"
end

--- Serialization
function _M:save()
	return class.save(self, {
		shad = true,
	})
end

function _M:loadFile(file)
	local f = fs.open(file, "r")
	local code = {}
	while true do
		local l = f:read(1)
		if not l then break end
		code[#code+1] = l
	end
	f:close()
	return table.concat(code)
end

function _M:getFragment(name, def)
	if not name then return nil end
	if self.frags[name] then return self.frags[name] end
	local code = self:loadFile("/data/gfx/shaders/"..name..".frag")
	code = self:rewriteShaderFrag(code, def)
	self.frags[name] = core.shader.newShader(code)
	print("[SHADER] created fragment shader from /data/gfx/shaders/"..name..".frag")
	return self.frags[name]
end

function _M:getVertex(name, def)
	if not name then name = "default/gl" end
	if self.verts[name] then print("[SHADER] reusing vertex shader from /data/gfx/shaders/"..name..".vert") return self.verts[name] end
	local code = self:loadFile("/data/gfx/shaders/"..name..".vert")
	code = self:rewriteShaderVert(code, def)
	self.verts[name] = core.shader.newShader(code, true)
	print("[SHADER] created vertex shader from /data/gfx/shaders/"..name..".vert")
	return self.verts[name]
end

function _M:createProgram(def)
	local shad = core.shader.newProgram()
	if not shad then return nil end
	def.vert = def.vert or "default/gl"
	if def.vert then shad:attach(self:getVertex(def.vert, def)) end
	if def.frag then shad:attach(self:getFragment(def.frag, def)) end
	if not shad:compile() then return nil end
	shad:setName(self.name)
	return shad
end

function _M:loaded()
	local def = nil
	if _M.progsperm[self.totalname] then
		-- print("[SHADER] using permcached shader "..self.totalname)
		self.shad = _M.progsperm[self.totalname]
	elseif _M.progs[self.totalname] then
		-- print("[SHADER] using cached shader "..self.totalname)
		self.shad = _M.progs[self.totalname].shad
		_M.progs[self.totalname].dieat = os.time() + 60*4
		if _M.progsreset[self.totalname] and self.shad then
			self.shad = self.shad:clone()
		end
	elseif self.shader_def then
		print("[SHADER] Loading from dynamic data")
		def = self.shader_def
	elseif not self.shader_def then
		print("[SHADER] Loading from /data/gfx/shaders/"..self.name..".lua")
		local f, err = loadfile("/data/gfx/shaders/"..self.name..".lua")
		if not f and err then error(err) end
		setfenv(f, setmetatable(self.args or {}, {__index=_G}))
		def = f()

		if def.require_shader then
			if not core.shader.active(def.require_shader) then return end
		end
		if def.require_kind then
			if not core.shader.allow(def.require_kind) then return end
		end
	end

	if def then
		print("[SHADER] Loaded shader with totalname", self.totalname)
		if def.data then self.data = def.data end

		if not _M.progs[self.totalname] then
			_M.progs[self.totalname] = {shad=self:createProgram(def), dieat=(os.time() + 60*4)}
		else
			_M.progs[self.totalname].dieat = (os.time() + 60*4)
		end

		if def.resetargs then
			_M.progsreset[self.totalname] = def.resetargs
		end


		self.shad = _M.progs[self.totalname].shad
		if self.shad then
			for k, v in pairs(def.args or {}) do
				self:setUniform(k, v)
			end
		end

		if def.permanent then _M.progsperm[self.totalname] = self.shad end
	end

	if self.shad and _M.progsreset[self.totalname] then
		self.shad:resetClean()
		for k, v in pairs(_M.progsreset[self.totalname]) do
			self:setResetUniform(k, util.getval(v, self))
		end
	end
end

function _M:setUniform(k, v)
	if type(v) == "number" then
--		print("[SHADER] setting param", k, v)
		self.shad:paramNumber(k, v)
	elseif type(v) == "table" then
		if v.texture then
--			print("[SHADER] setting texture param", k, v.texture)
			self.shad:paramTexture(k, v.texture, v.is3d)
		elseif #v == 2 then
--			print("[SHADER] setting vec2 param", k, v[1], v[2])
			self.shad:paramNumber2(k, v[1], v[2])
		elseif #v == 3 then
--			print("[SHADER] setting vec3 param", k, v[1], v[2], v[3])
			self.shad:paramNumber3(k, v[1], v[2], v[3])
		elseif #v == 4 then
--			print("[SHADER] setting vec4 param", k, v[1], v[2], v[3], v[4])
			self.shad:paramNumber4(k, v[1], v[2], v[3], v[4])
		end
	end
end

function _M:setResetUniform(k, v)
	if type(v) == "number" then
		print("[SHADER] setting reset param", k, v)
		self.shad:resetParamNumber(k, v)
	elseif type(v) == "table" then
		if v.texture then
--			print("[SHADER] setting texture param", k, v.texture)
			self.shad:resetParamTexture(k, v.texture, v.is3d)
		elseif #v == 2 then
--			print("[SHADER] setting vec2 param", k, v[1], v[2])
			self.shad:resetParamNumber2(k, v[1], v[2])
		elseif #v == 3 then
--			print("[SHADER] setting vec3 param", k, v[1], v[2], v[3])
			self.shad:resetParamNumber3(k, v[1], v[2], v[3])
		elseif #v == 4 then
--			print("[SHADER] setting vec4 param", k, v[1], v[2], v[3], v[4])
			self.shad:resetParamNumber4(k, v[1], v[2], v[3], v[4])
		end
	end
end

----------------------------------------------------------------------------
-- Default shaders
----------------------------------------------------------------------------
default = {}

function _M:setDefault(kind, name, args)
	local shad = _M.new(name, args)
	if not shad.shad then return end
	
	if kind == "text" then core.renderer.defaultTextShader(shad.shad) end
	print("[SHADER] defining default "..kind.." to ", shad, shad.shad)
	default[kind] = shad
end

function _M:getDefault(kind)
	return default[kind]
end

----------------------------------------------------------------------------
-- Shaders rewriting
-- Later on this can be extended to support various GLSL versions
----------------------------------------------------------------------------

function _M:preprocess(code, kind, def)
	code = code:gsub("gl_TexCoord%[0%]", "te4_uv")
	code = code:gsub("gl_Color", "te4_fragcolor")

	if kind == "frag" then
		code = code:gsub("#kinddefinitions#", function()
			local selectors = self.data.kindselectors or {[0] = "normal"}
			local blocks = {}
			for kind, file in pairs(selectors) do
				local subcode = self:loadFile("/data/gfx/shaders/modules/"..file..".frag")
				subcode = self:preprocess(subcode, "frag", def)
				blocks[#blocks+1] = subcode
			end
			return table.concat(blocks, "\n")
		end)
		code = code:gsub("#kindselectors#", function()
			local selectors = self.data.kindselectors or {[0] = "normal"}
			local blocks = {}
			for kind, file in pairs(selectors) do
				local isfirst = #blocks == 0
				
				blocks[#blocks+1] = ("%s (kind == %0.1f) { gl_FragColor = map_shader_%s(); }\n"):format(isfirst and "if" or "else if", kind, file)
			end
			return table.concat(blocks)
		end)
	end
	code = code:gsub('#include "([^"]+)"', function(file)
		local subcode = self:loadFile("/data/gfx/shaders/"..file)
		subcode = self:preprocess(subcode, kind, def)
		return subcode
	end)
	code = code:gsub('#resetarg ([^=]+)=([^\n]+)', function(name, val)
		def.resetargs = def.resetargs or {}
		local f, err = loadstring("return "..val)
		if not f then error(err) end
		local ok, val = pcall(f, self)
		if not ok then error(val) end
		def.resetargs[name] = val
		return ''
	end)
	code = code:gsub('#arg ([^=]+)=([^\n]+)', function(name, val)
		self.args = self.args or {}
		local f, err = loadstring("return "..val)
		if not f then error(err) end
		local ok, val = pcall(f, self)
		if not ok then error(val) end
		self.args[name] = val
		return ''
	end)
	return code
end

function _M:rewriteShaderFrag(code, def)
	code = [[
	varying vec2 te4_uv;
	varying vec4 te4_fragcolor;		
	]]..code
	code = self:preprocess(code, "frag", def)
	if __ANDROID__ then code = "precision mediump float;\n"..code end
	print("=====frag\n", self.name)
	print(code)
	print("=====frag+\n")
	return code
end

function _M:rewriteShaderVert(code, def)
	code = [[
	attribute vec4 te4_position;
	attribute vec2 te4_texcoord;
	attribute vec4 te4_color;
	varying vec2 te4_uv;
	varying vec4 te4_fragcolor;
	]]..code
	code = self:preprocess(code, "vert", def)
	if __ANDROID__ then code = "precision mediump float;\n"..code end
	print("=====vert\n", self.name)
	print(code)
	print("=====vert+\n")
	return code
end
