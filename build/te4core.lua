-- T-Engine4
-- Copyright (C) 2009, 2010, 2011, 2012, 2013 Nicolas Casalini
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

-- capture the output of a command
function os.capture(cmd, raw)
	local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
	if raw then return s end
	s = string.gsub(s, '^%s+', '')
	s = string.gsub(s, '%s+$', '')
	s = string.gsub(s, '[\n\r]+', ' ')
	return s
end

project "TEngine"
	kind "WindowedApp"
	language "C++"
	targetname("t-engine")
	files { "../src/*.c", "../src/*.cpp", }
	if _OPTIONS.steam then
		files { "../steamworks/luasteam.c", }
	end
	links { "physfs", "lua".._OPTIONS.lua, "fov", "luasocket", "luaprofiler", "lpeg", "tcodimport", "lxp", "expatstatic", "luamd5", "luazlib", "luabitop", "te4-bzip", "utf8proc", "te4-renderer", "te4-particles-system", "te4-navmesh", "te4-spriter", "tinyxml2", "te4-freetype-gl", "te4-tinyobjloader", "te4-box2d-".._OPTIONS.box2d:lower(), "te4-poly2tri", "te4-clipper", "te4-muparser" }
	defines { "_DEFAULT_VIDEOMODE_FLAGS_='SDL_HWSURFACE|SDL_DOUBLEBUF'" }
	defines { [[TENGINE_HOME_PATH='".t-engine"']], "TE4CORE_VERSION="..TE4CORE_VERSION }
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then
		defines { "TE4_PROFILING" }
		buildoptions { "-fno-omit-frame-pointer" }
		linkoptions{ "-fno-omit-frame-pointer" }
		links{"profiler"}
	end

	if _OPTIONS.relpath=="32" then linkoptions{"-Wl,-rpath -Wl,\\\$\$ORIGIN/lib "} end
	if _OPTIONS.relpath=="64" then linkoptions{"-Wl,-rpath -Wl,\\\$\$ORIGIN/lib64 "} end

	if _OPTIONS.relpath == "32" then defines{"TE4_RELPATH32"} end
	if _OPTIONS.relpath == "64" then defines{"TE4_RELPATH64"} end

	links { "m" }

	if _OPTIONS.no_rwops_size then defines{"NO_RWOPS_SIZE"} end

	if _OPTIONS.steam then
		dofile("../steamworks/build/steam-build.lua")
	end

	if _OPTIONS.wincross then
		prelinkcommands { "i686-w64-mingw32.shared-ranlib ../bin/Debug/*.a" }
	end

	configuration "macosx"
		files { "../src/mac/SDL*" }
		includedirs {
			"/System/Library/Frameworks/OpenGL.framework/Headers",
			"/System/Library/Frameworks/OpenAL.framework/Headers",

			"/Library/Frameworks/SDL2.framework/Headers",
			"/Library/Frameworks/SDL2_image.framework/Headers",
			"/Library/Frameworks/libpng.framework/Headers",
			"/Library/Frameworks/ogg.framework/Headers",
			"/Library/Frameworks/vorbis.framework/Headers",

			-- MacPorts paths
			"/opt/local/include",
			"/opt/local/include/Vorbis",

			-- Homebrew paths
			"/usr/local/include",
			"/usr/local/opt/libpng12/include",
		}
		defines { "USE_TENGINE_MAIN", 'SELFEXE_MACOSX', [[TENGINE_HOME_PATH='"/Library/Application Support/T-Engine/"']]  }
		linkoptions {
			"-framework Cocoa",
			"-framework OpenGL",
			"-framework OpenAL",

			"-framework SDL2",
			"-framework SDL2_image",
			"-framework libpng",
			"-framework ogg",
			"-framework vorbis",
			"-Wl,-rpath,'@loader_path/../Frameworks'",
		}
		if _OPTIONS.lua == "jit2" then
			linkoptions {
				-- These two options are mandatory for LuaJIT to work
				"-pagezero_size 10000",
				"-image_base 100000000",
			}
		end
		targetdir "."
		links { "IOKit" }

	configuration "windows"
		links { "mingw32", "freetype", "SDL2main", "SDL2", "SDL2_image", "OpenAL32", "vorbisfile", "opengl32", "glu32", "wsock32", "png" }
		defines { [[TENGINE_HOME_PATH='"T-Engine"']], 'SELFEXE_WINDOWS'  }
		if _OPTIONS.wincross then
			prebuildcommands { "i686-w64-mingw32.shared-windres ../src/windows/icon.rc -O coff -o ../src/windows/icon.res" }
		else
			prebuildcommands { "windres ../src/windows/icon.rc -O coff -o ../src/windows/icon.res" }
		end
		linkoptions { "../src/windows/icon.res" }
		linkoptions { "-mwindows", "-static-libgcc", "-static-libstdc++" }
		defines { [[TENGINE_HOME_PATH='"T-Engine"']], 'SELFEXE_WINDOWS' }

	configuration "linux"
		libdirs {"/opt/SDL-2.0/lib/"}
		links { "dl", "freetype", "SDL2", "SDL2_image", "png", "openal", "vorbisfile", "GL", "GLU", "m", "pthread" }
		linkoptions { "-Wl,-E" }
		defines { [[TENGINE_HOME_PATH='".t-engine"']], 'SELFEXE_LINUX' }
		if steamlin64 then steamlin64() end

	configuration "bsd"
		libdirs {"/usr/local/lib/"}
		links { "SDL2", "SDL2_image", "png", "openal", "vorbisfile", "GL", "GLU", "m", "pthread" }
		defines { [[TENGINE_HOME_PATH='".t-engine"']], 'SELFEXE_BSD' }

	configuration {"Debug"}
		if _OPTIONS.wincross then
			postbuildcommands { "cp ../bin/Debug/t-engine.exe ../", }
		else
			if os.get() ~= "macosx" then postbuildcommands { "cp ../bin/Debug/t-engine ../", }
			else postbuildcommands { "cp ../build/t-engine.app/Contents/MacOS/t-engine ../mac/base_app/Contents/MacOS", }
			end
		end
	configuration {"Release"}
		if _OPTIONS.wincross then
			postbuildcommands { "cp ../bin/Release/t-engine.exe ../", }
		else
			if os.get() ~= "macosx" then postbuildcommands { "cp ../bin/Release/t-engine ../", }
			else postbuildcommands { "cp ../build/t-engine.app/Contents/MacOS/t-engine ../mac/base_app/Contents/MacOS", }
			end
		end


----------------------------------------------------------------
----------------------------------------------------------------
-- Librairies used by T-Engine
----------------------------------------------------------------
----------------------------------------------------------------
project "physfs"
	kind "StaticLib"
	language "C"
	targetname "physfs"

	defines {"PHYSFS_SUPPORTS_ZIP"}
	if _OPTIONS.no_rwops_size then defines{"NO_RWOPS_SIZE"} end
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/physfs/*.c", "../src/zlib/*.c", "../src/physfs/archivers/*.c", }

	configuration "linux"
		files { "../src/physfs/platform/unix.c", "../src/physfs/platform/posix.c",  }
	configuration "bsd"
		files { "../src/physfs/platform/unix.c", "../src/physfs/platform/posix.c",  }
	configuration "windows"
		files { "../src/physfs/platform/windows.c",  }
	configuration "macosx"
		files { "../src/physfs/platform/macosx.c", "../src/physfs/platform/posix.c",  }
                includedirs { "/Library/Frameworks/SDL.framework/Headers" }

if _OPTIONS.lua == "default" then
	project "luadefault"
		kind "StaticLib"
		language "C"
		targetname "lua"

		files { "../src/lua/*.c", }
elseif _OPTIONS.lua == "jit2" then
	project "minilua"
		kind "ConsoleApp"
		language "C"
		targetname "minilua"
		links { "m" }
		if _OPTIONS.wincross then
			links {"mingw32"}
		end

		files { "../src/luajit2/src/host/minilua.c" }

		local arch_test
		if _OPTIONS.wincross then
			arch_test = os.capture("i686-w64-mingw32.shared-gcc -E ../src/luajit2/src/lj_arch.h -dM", true)
		else
			arch_test = os.capture("gcc -E ../src/luajit2/src/lj_arch.h -dM", true)
		end

		if string.find(arch_test, "LJ_TARGET_X64") then
			target_arch = "x64"
		elseif string.find(arch_test, "LJ_TARGET_X86") then
			target_arch = "x86"
		elseif string.find(arch_test, "LJ_TARGET_ARM") then
			target_arch = "arm"
		elseif string.find(arch_test, "LJ_TARGET_PPC") then
			target_arch = "ppc"
		elseif string.find(arch_test, "LJ_TARGET_PPCSPE") then
			target_arch = "ppcspe"
		elseif string.find(arch_test, "LJ_TARGET_MIPS") then
			target_arch = "mips"
		else
			error("Unsupported target architecture, use architecture agnostic lua with --lua=default")
		end
		defines { "LUAJIT_TARGET=LUAJIT_ARCH_" .. target_arch }

		if string.find(arch_test, "LJ_ARCH_HASFPU 1") then
			defines { "LJ_ARCH_HASFPU=1" }
		else
			defines { "LJ_ARCH_HASFPU=0" }
		end
		if string.find(arch_test, "LJ_ABI_SOFTFP 1") then
			defines { "LJ_ABI_SOFTFP=1" }
		else
			defines { "LJ_ABI_SOFTFP=0" }
		end

		configuration {"Debug"}
			if _OPTIONS.wincross then
				-- postbuildcommands {
				-- 	'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Debug/minilua/minilua.cross.o" -c "../src/luajit2/src/host/minilua.c"',
				-- 	'gcc -o ../bin/Debug/minilua ../obj/Debug/minilua/minilua.cross.o  -m32 -L/Test/xcompile/local/lib   -lm',
				-- }
				postbuildcommands { "cp ../bin/Debug/minilua.exe ../src/luajit2/src/host/", }
			else
				postbuildcommands { "cp ../bin/Debug/minilua ../src/luajit2/src/host/", }
			end
		configuration {"Release"}
			if _OPTIONS.wincross then
				postbuildcommands {
					'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Release/minilua/minilua.cross.o" -c "../src/luajit2/src/host/minilua.c"',
					'gcc -o ../bin/Release/minilua ../obj/Release/minilua/minilua.cross.o  -m32 -L/Test/xcompile/local/lib   -lm',
				}
			end
			postbuildcommands { "cp ../bin/Release/minilua ../src/luajit2/src/host/", }

	project "buildvm"
		kind "ConsoleApp"
		language "C"
		targetname "buildvm"
		links { "minilua" }

		local dasm_flags = ""
		local arch_test
		if _OPTIONS.wincross then
			arch_test = os.capture("i686-w64-mingw32.shared-gcc -E ../src/luajit2/src/lj_arch.h -dM", true)
		else
			arch_test = os.capture("gcc -E ../src/luajit2/src/lj_arch.h -dM", true)
		end

		if string.find(arch_test, "LJ_TARGET_X64") then
			target_arch = "x64"
		elseif string.find(arch_test, "LJ_TARGET_X86") then
			target_arch = "x86"
		elseif string.find(arch_test, "LJ_TARGET_ARM") then
			target_arch = "arm"
		elseif string.find(arch_test, "LJ_TARGET_PPC") then
			target_arch = "ppc"
		elseif string.find(arch_test, "LJ_TARGET_PPCSPE") then
			target_arch = "ppcspe"
		elseif string.find(arch_test, "LJ_TARGET_MIPS") then
			target_arch = "mips"
		else
			error("Unsupported target architecture, use architecture agnostic lua with --lua=default")
		end
		defines { "LUAJIT_TARGET=LUAJIT_ARCH_" .. target_arch }

		if string.find(arch_test, "LJ_ARCH_HASFPU 1") then
			defines { "LJ_ARCH_HASFPU=1" }
		else
			defines { "LJ_ARCH_HASFPU=0" }
		end
		if string.find(arch_test, "LJ_ABI_SOFTFP 1") then
			defines { "LJ_ABI_SOFTFP=1" }
		else
			defines { "LJ_ABI_SOFTFP=0" }
		end

		dasm_flags = dasm_flags .. " -D VER="

		if string.find(arch_test, "LJ_ARCH_BITS 64") then
			dasm_flags = dasm_flags .. " -D P64"
		end
		if string.find(arch_test, "LJ_HASJIT 1") then
			dasm_flags = dasm_flags .. " -D JIT"
		end
		if string.find(arch_test, "LJ_HASFFI 1") then
			dasm_flags = dasm_flags .. " -D FFI"
		end
		if string.find(arch_test, "LJ_DUALNUM 1") then
			dasm_flags = dasm_flags .. " -D DUALNUM"
		end
		if string.find(arch_test, "LJ_ARCH_HASFPU 1") then
			dasm_flags = dasm_flags .. " -D FPU"
		end
		if not string.find(arch_test, "LJ_ABI_SOFTFP 1") then
			dasm_flags = dasm_flags .. " -D HFABI"
		end
		if target_arch == "x86" and string.find(arch_test, "__SSE2__") then
			dasm_flags = dasm_flags .. " -D SSE"
		end
		if string.find(arch_test, "LJ_ARCH_SQRT 1") then
			dasm_flags = dasm_flags .. " -D SQRT"
		end
		if string.find(arch_test, "LJ_ARCH_ROUND 1") then
			dasm_flags = dasm_flags .. " -D ROUND"
		end
		if string.find(arch_test, "LJ_ARCH_PPC64 1") then
			dasm_flags = dasm_flags .. " -D GPR64"
		end

		if target_arch == "x64" then
			target_arch = "x86"
		end

		local dasc = "../src/luajit2/src/vm_" .. target_arch .. ".dasc"

		prebuildcommands{ "../src/luajit2/src/host/minilua ../src/luajit2/dynasm/dynasm.lua" .. dasm_flags .. " -o ../src/luajit2/src/host/buildvm_arch.h " .. dasc }

		files { "../src/luajit2/src/host/buildvm*.c" }

		configuration {"Debug"}
			if _OPTIONS.wincross then
				-- postbuildcommands {
				-- 	'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Debug/buildvm/buildvm_lib.cross.o" -c "../src/luajit2/src/host/buildvm_lib.c"',
				-- 	'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Debug/buildvm/buildvm_asm.cross.o" -c "../src/luajit2/src/host/buildvm_asm.c"',
				-- 	'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Debug/buildvm/buildvm_peobj.cross.o" -c "../src/luajit2/src/host/buildvm_peobj.c"',
				-- 	'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Debug/buildvm/buildvm_fold.cross.o" -c "../src/luajit2/src/host/buildvm_fold.c"',
				-- 	'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Debug/buildvm/buildvm.cross.o" -c "../src/luajit2/src/host/buildvm.c"',
				-- 	'gcc -o ../bin/Debug/buildvm ../obj/Debug/buildvm/buildvm_lib.cross.o ../obj/Debug/buildvm/buildvm_asm.cross.o ../obj/Debug/buildvm/buildvm_peobj.cross.o ../obj/Debug/buildvm/buildvm_fold.cross.o ../obj/Debug/buildvm/buildvm.cross.o  -m32 -L/Test/xcompile/local/lib',
				-- }
				postbuildcommands { "cp ../bin/Debug/buildvm.exe ../src/luajit2/src/", }
			else
				postbuildcommands { "cp ../bin/Debug/buildvm ../src/luajit2/src/", }
			end
		configuration {"Release"}
			if _OPTIONS.wincross then
				postbuildcommands {
					'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Release/buildvm/buildvm_lib.cross.o" -c "../src/luajit2/src/host/buildvm_lib.c"',
					'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Release/buildvm/buildvm_asm.cross.o" -c "../src/luajit2/src/host/buildvm_asm.c"',
					'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Release/buildvm/buildvm_peobj.cross.o" -c "../src/luajit2/src/host/buildvm_peobj.c"',
					'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Release/buildvm/buildvm_fold.cross.o" -c "../src/luajit2/src/host/buildvm_fold.c"',
					'gcc -MMD -MP -DGLEW_STATIC -DLUAJIT_TARGET=LUAJIT_ARCH_x86 -DLJ_ARCH_HASFPU=1 -DLJ_ABI_SOFTFP=0 -I../src -I../src/luasocket -I../src/fov -I../src/expat -I../src/lxp -I../src/libtcod_import -I../src/physfs -I../src/zlib -I../src/bzip2 -I../src/luajit2/src -I../src/luajit2/dynasm -g -m32 -ggdb -o "../obj/Release/buildvm/buildvm.cross.o" -c "../src/luajit2/src/host/buildvm.c"',
					'gcc -o ../bin/Release/buildvm ../obj/Release/buildvm/buildvm_lib.cross.o ../obj/Release/buildvm/buildvm_asm.cross.o ../obj/Release/buildvm/buildvm_peobj.cross.o ../obj/Release/buildvm/buildvm_fold.cross.o ../obj/Release/buildvm/buildvm.cross.o  -m32 -L/Test/xcompile/local/lib',
				}
			end
			postbuildcommands { "cp ../bin/Release/buildvm ../src/luajit2/src/", }

	project "luajit2"
		kind "StaticLib"
		language "C"
		targetname "lua"
		links { "buildvm" }
		if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

		files { "../src/luajit2/src/*.c", "../src/luajit2/src/*.s", "../src/luajit2/src/lj_vm.s", "../src/luajit2/src/lj_bcdef.h", "../src/luajit2/src/lj_ffdef.h", "../src/luajit2/src/lj_ffdef.h", "../src/luajit2/src/lj_libdef.h", "../src/luajit2/src/lj_recdef.h", "../src/luajit2/src/lj_folddef.h" }
		excludes { "../src/luajit2/src/buildvm*.c", "../src/luajit2/src/luajit.c", "../src/luajit2/src/ljamalg.c" }

		configuration "linux"
			if not _OPTIONS["no-cleanup-jit2"] then
			local list = "../src/luajit2/src/lib_base.c ../src/luajit2/src/lib_math.c ../src/luajit2/src/lib_bit.c ../src/luajit2/src/lib_string.c ../src/luajit2/src/lib_table.c ../src/luajit2/src/lib_io.c ../src/luajit2/src/lib_os.c ../src/luajit2/src/lib_package.c ../src/luajit2/src/lib_debug.c ../src/luajit2/src/lib_jit.c ../src/luajit2/src/lib_ffi.c"
			prebuildcommands{
				"../src/luajit2/src/buildvm -m elfasm -o ../src/luajit2/src/lj_vm.s",
				"../src/luajit2/src/buildvm -m bcdef -o ../src/luajit2/src/lj_bcdef.h "..list,
				"../src/luajit2/src/buildvm -m ffdef -o ../src/luajit2/src/lj_ffdef.h "..list,
				"../src/luajit2/src/buildvm -m libdef -o ../src/luajit2/src/lj_libdef.h "..list,
				"../src/luajit2/src/buildvm -m recdef -o ../src/luajit2/src/lj_recdef.h "..list,
				"../src/luajit2/src/buildvm -m vmdef -o ../src/luajit2/vmdef.lua "..list,
				"../src/luajit2/src/buildvm -m folddef -o ../src/luajit2/src/lj_folddef.h ../src/luajit2/src/lj_opt_fold.c",
			}
			end

		configuration "bsd"
			if not _OPTIONS["no-cleanup-jit2"] then
			local list = "../src/luajit2/src/lib_base.c ../src/luajit2/src/lib_math.c ../src/luajit2/src/lib_bit.c ../src/luajit2/src/lib_string.c ../src/luajit2/src/lib_table.c ../src/luajit2/src/lib_io.c ../src/luajit2/src/lib_os.c ../src/luajit2/src/lib_package.c ../src/luajit2/src/lib_debug.c ../src/luajit2/src/lib_jit.c ../src/luajit2/src/lib_ffi.c"
			prebuildcommands{
				"../src/luajit2/src/buildvm -m elfasm -o ../src/luajit2/src/lj_vm.s",
				"../src/luajit2/src/buildvm -m bcdef -o ../src/luajit2/src/lj_bcdef.h "..list,
				"../src/luajit2/src/buildvm -m ffdef -o ../src/luajit2/src/lj_ffdef.h "..list,
				"../src/luajit2/src/buildvm -m libdef -o ../src/luajit2/src/lj_libdef.h "..list,
				"../src/luajit2/src/buildvm -m recdef -o ../src/luajit2/src/lj_recdef.h "..list,
				"../src/luajit2/src/buildvm -m vmdef -o ../src/luajit2/vmdef.lua "..list,
				"../src/luajit2/src/buildvm -m folddef -o ../src/luajit2/src/lj_folddef.h ../src/luajit2/src/lj_opt_fold.c",
			}
			end

		configuration "macosx"
			local list = "../src/luajit2/src/lib_base.c ../src/luajit2/src/lib_math.c ../src/luajit2/src/lib_bit.c ../src/luajit2/src/lib_string.c ../src/luajit2/src/lib_table.c ../src/luajit2/src/lib_io.c ../src/luajit2/src/lib_os.c ../src/luajit2/src/lib_package.c ../src/luajit2/src/lib_debug.c ../src/luajit2/src/lib_jit.c ../src/luajit2/src/lib_ffi.c"
			prebuildcommands{
				"../src/luajit2/src/buildvm -m machasm -o ../src/luajit2/src/lj_vm.s",
				"../src/luajit2/src/buildvm -m bcdef -o ../src/luajit2/src/lj_bcdef.h "..list,
				"../src/luajit2/src/buildvm -m ffdef -o ../src/luajit2/src/lj_ffdef.h "..list,
				"../src/luajit2/src/buildvm -m libdef -o ../src/luajit2/src/lj_libdef.h "..list,
				"../src/luajit2/src/buildvm -m recdef -o ../src/luajit2/src/lj_recdef.h "..list,
				"../src/luajit2/src/buildvm -m vmdef -o ../src/luajit2/vmdef.lua "..list,
				"../src/luajit2/src/buildvm -m folddef -o ../src/luajit2/src/lj_folddef.h ../src/luajit2/src/lj_opt_fold.c",
			}

		configuration "windows"
			if not _OPTIONS["no-cleanup-jit2"] then
			local list = "../src/luajit2/src/lib_base.c ../src/luajit2/src/lib_math.c ../src/luajit2/src/lib_bit.c ../src/luajit2/src/lib_string.c ../src/luajit2/src/lib_table.c ../src/luajit2/src/lib_io.c ../src/luajit2/src/lib_os.c ../src/luajit2/src/lib_package.c ../src/luajit2/src/lib_debug.c ../src/luajit2/src/lib_jit.c ../src/luajit2/src/lib_ffi.c"
			prebuildcommands{
				"../src/luajit2/src/buildvm -m coffasm -o ../src/luajit2/src/lj_vm.s",
				"../src/luajit2/src/buildvm -m bcdef -o ../src/luajit2/src/lj_bcdef.h "..list,
				"../src/luajit2/src/buildvm -m ffdef -o ../src/luajit2/src/lj_ffdef.h "..list,
				"../src/luajit2/src/buildvm -m libdef -o ../src/luajit2/src/lj_libdef.h "..list,
				"../src/luajit2/src/buildvm -m recdef -o ../src/luajit2/src/lj_recdef.h "..list,
				"../src/luajit2/src/buildvm -m vmdef -o ../src/luajit2/vmdef.lua "..list,
				"../src/luajit2/src/buildvm -m folddef -o ../src/luajit2/src/lj_folddef.h ../src/luajit2/src/lj_opt_fold.c",
			}
			end

end

project "luasocket"
	kind "StaticLib"
	language "C"
	targetname "luasocket"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	configuration "not windows"
		files {
			"../src/luasocket/auxiliar.c",
			"../src/luasocket/buffer.c",
			"../src/luasocket/except.c",
			"../src/luasocket/inet.c",
			"../src/luasocket/io.c",
			"../src/luasocket/luasocket.c",
			"../src/luasocket/options.c",
			"../src/luasocket/select.c",
			"../src/luasocket/tcp.c",
			"../src/luasocket/timeout.c",
			"../src/luasocket/udp.c",
			"../src/luasocket/usocket.c",
			"../src/luasocket/mime.c",
		}
	configuration "windows"
		files {
			"../src/luasocket/auxiliar.c",
			"../src/luasocket/buffer.c",
			"../src/luasocket/except.c",
			"../src/luasocket/inet.c",
			"../src/luasocket/io.c",
			"../src/luasocket/luasocket.c",
			"../src/luasocket/options.c",
			"../src/luasocket/select.c",
			"../src/luasocket/tcp.c",
			"../src/luasocket/timeout.c",
			"../src/luasocket/udp.c",
			"../src/luasocket/wsocket.c",
			"../src/luasocket/mime.c",
		}

project "fov"
	kind "StaticLib"
	language "C"
	targetname "fov"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/fov/*.c", }

project "lpeg"
	kind "StaticLib"
	language "C"
	targetname "lpeg"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/lpeg/*.c", }

project "luaprofiler"
	kind "StaticLib"
	language "C"
	targetname "luaprofiler"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/luaprofiler/*.c", }

project "tcodimport"
	kind "StaticLib"
	language "C"
	targetname "tcodimport"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/libtcod_import/*.c", }

project "expatstatic"
	kind "StaticLib"
	language "C"
	targetname "expatstatic"
	defines{ "HAVE_MEMMOVE" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/expat/*.c", }

project "lxp"
	kind "StaticLib"
	language "C"
	targetname "lxp"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/lxp/*.c", }

project "utf8proc"
	kind "StaticLib"
	language "C"
	targetname "utf8proc"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/utf8proc/utf8proc.c", }

project "luamd5"
	kind "StaticLib"
	language "C"
	targetname "luamd5"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/luamd5/*.c", }

project "luazlib"
	kind "StaticLib"
	language "C"
	targetname "luazlib"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/lzlib/*.c", }

project "luabitop"
	kind "StaticLib"
	language "C"
	targetname "luabitop"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/luabitop/*.c", }

project "te4-bzip"
	kind "StaticLib"
	language "C"
	targetname "te4-bzip"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/bzip2/*.c", }

project "te4-freetype-gl"
	kind "StaticLib"
	language "C"
	targetname "te4-freetype-gl"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end
	if _OPTIONS.wincross then
		includedirs{'/opt/mxe/usr/i686-w64-mingw32.shared/include/freetype2'}
	end

	files { "../src/freetype-gl/*.c", }

if _OPTIONS['web-cef3'] and not _OPTIONS.wincross then
project "te4-web"
	kind "SharedLib"
	language "C++"
	targetname "te4-web"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	if _OPTIONS.relpath=="32" then linkoptions{"-Wl,-rpath -Wl,\\\$\$ORIGIN "} end
	if _OPTIONS.relpath=="64" then linkoptions{"-Wl,-rpath -Wl,\\\$\$ORIGIN "} end

	files { "../src/web-cef3/*.cpp", }

	configuration "macosx"
		defines { 'SELFEXE_MACOSX' }
		libdirs {"/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/xcodebuild/Release/", "/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/Release/"}
		includedirs {"/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/include/", "/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/"}
		links { "cef", "cef_dll_wrapper" }

	configuration "windows"
		defines { 'SELFEXE_WINDOWS' }

	configuration "linux"
		buildoptions{"-Wall -pthread -I/usr/include/gtk-2.0 -I/usr/lib64/gtk-2.0/include -I/usr/include/atk-1.0 -I/usr/include/cairo -I/usr/include/gdk-pixbuf-2.0 -I/usr/include/pango-1.0 -I/usr/include/glib-2.0 -I/usr/lib64/glib-2.0/include -I/usr/include/pixman-1 -I/usr/include/freetype2 -I/usr/include/libpng15 -I/usr/include/libdrm"}
		libdirs {"/opt/cef3/1547/out/Release/obj.target/", "/opt/cef3/1547/Release/"}
		includedirs {"/opt/cef3/1547/include/", "/opt/cef3/1547/"}
		links { "cef", "cef_dll_wrapper" }
		defines { 'SELFEXE_LINUX' }


project "cef3spawn"
	kind "WindowedApp"
	language "C++"
	targetname "cef3spawn"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	includedirs {"../src/web-cef3/", }
	files {
		"../src/web-cef3/spawn.cpp",
	}

	configuration "macosx"
		defines { 'SELFEXE_MACOSX' }
		libdirs {"/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/xcodebuild/Release/", "/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/Release/"}
		includedirs {"/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/include/", "/users/tomedev/downloads/cef_binary_3.1547.1597_macosx64/"}
		links { "cef", "cef_dll_wrapper" }

	configuration "linux"
		buildoptions{"-Wall -pthread -I/usr/include/gtk-2.0 -I/usr/lib64/gtk-2.0/include -I/usr/include/atk-1.0 -I/usr/include/cairo -I/usr/include/gdk-pixbuf-2.0 -I/usr/include/pango-1.0 -I/usr/include/glib-2.0 -I/usr/lib64/glib-2.0/include -I/usr/include/pixman-1 -I/usr/include/freetype2 -I/usr/include/libpng15 -I/usr/include/libdrm"}
		libdirs {"/opt/cef3/1547/out/Release/obj.target/", "/opt/cef3/1547/Release/"}
		includedirs {"/opt/cef3/1547/include/", "/opt/cef3/1547/"}
		links { "cef", "cef_dll_wrapper" }
		if _OPTIONS.relpath=="32" then linkoptions{"-Wl,-rpath -Wl,\\\$\$ORIGIN/lib "} end
		if _OPTIONS.relpath=="64" then linkoptions{"-Wl,-rpath -Wl,\\\$\$ORIGIN/lib64 "} end
		defines { 'SELFEXE_LINUX' }
end

project "tinyxml2"
	kind "StaticLib"
	language "C++"
	targetname "tinyxml2"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/tinyxml2/*.cpp", }

if _OPTIONS.steam then
	dofile("../steamworks/build/steam-code.lua")
end

project "te4-renderer"
	kind "StaticLib"
	language "C++"
	targetname "te4-renderer"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/renderer-moderngl/*.cpp", "../src/displayobjects/*.cpp", }

project "te4-navmesh"
	kind "StaticLib"
	language "C++"
	targetname "te4-navmesh"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/navmesh/*.cpp" }


if _OPTIONS.steam then
	dofile("../steamworks/build/steam-code.lua")
end

project "te4-spriter"
	kind "StaticLib"
	language "C++"
	targetname "te4-spriter"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/spriterengine/animation/*.cpp", "../src/spriterengine/charactermap/*.cpp", "../src/spriterengine/entity/*.cpp", "../src/spriterengine/file/*.cpp", "../src/spriterengine/global/*.cpp", "../src/spriterengine/loading/*.cpp", "../src/spriterengine/model/*.cpp", "../src/spriterengine/objectinfo/*.cpp", "../src/spriterengine/objectref/*.cpp", "../src/spriterengine/override/*.cpp", "../src/spriterengine/timeinfo/*.cpp", "../src/spriterengine/timeline/*.cpp", "../src/spriterengine/variable/*.cpp", "../src/spriter/*.cpp", }

project "te4-tinyobjloader"
	kind "StaticLib"
	language "C++"
	targetname "te4-tinyobjloader"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/tinyobjloader/*.cc", }

project "te4-clipper"
	kind "StaticLib"
	language "C++"
	targetname "te4-clipper"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/clipper/**.cpp", }

project "te4-poly2tri"
	kind "StaticLib"
	language "C++"
	targetname "te4-poly2tri"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/poly2tri/**.cc", }

project "te4-muparser"
	kind "StaticLib"
	language "C++"
	targetname "te4-muparser"
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	includedirs{ "../src/muparser/include/" }
	files { "../src/muparser/src/**.cpp", }

project "te4-particles-system"
	kind "StaticLib"
	language "C++"
	targetname "te4-particles-system"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/particles-system/**.cpp", }

if _OPTIONS.box2d == "ST" then
project "te4-box2d-st"
	kind "StaticLib"
	language "C++"
	targetname "te4-box2d-st"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/Box2D/**.h", "../src/Box2D/**.cpp", }
elseif _OPTIONS.box2d == "MT" then
project "te4-box2d-mt"
	kind "StaticLib"
	language "C++"
	targetname "te4-box2d-mt"
	buildoptions { "-std=gnu++11" }
	if _OPTIONS.profiling then buildoptions { "-fno-omit-frame-pointer" } linkoptions{ "-fno-omit-frame-pointer" } end

	files { "../src/Box2D-MT/**.h", "../src/Box2D-MT/**.cpp", }
end


if _OPTIONS.steam then
	dofile("../steamworks/build/steam-code.lua")
end
