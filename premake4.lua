dofile("build/options.lua")

solution "TEngine"
	configurations { "Debug", "Release" }
	objdir "obj"
	defines {"GLEW_STATIC"}
	if _OPTIONS.force32bits then
		buildoptions{"-m32"} linkoptions{"-m32"}
		if not _OPTIONS.wincross then libdirs{"/usr/lib32"} end
	end

	buildoptions { "-O3" }

	includedirs {
		"src",
		"src/luasocket",
		"src/fov",
		"src/expat",
		"src/lxp",
		"src/libtcod_import",
		"src/physfs",
		"src/zlib",
		"src/bzip2",
		"src/glm",
	}
	if _OPTIONS['web-awesomium'] then
		includedirs { "src/web-awesomium" }
	end
	if _OPTIONS['web-cef3'] then
		includedirs { "src/web-cef3" }
	end
	if _OPTIONS.wincross then
		includedirs {
			"/usr/i686-pc-mingw32/usr/include/",
			"/usr/i686-pc-mingw32/usr/include/GL/",
		}
	else
		includedirs {
			"/opt/SDL-2.0/include/SDL2",
			"/usr/include/GL",
			"/usr/include/freetype2",
		}
	end
	if _OPTIONS.lua == "default" then includedirs{"src/lua"}
	elseif _OPTIONS.lua == "jit2" then includedirs{"src/luajit2/src", "src/luajit2/dynasm",}
	end
	if _OPTIONS.box2d == "MT" then defines{"BOX2D_MT"} end

if _OPTIONS.steam then
	dofile("steamworks/build/steam-def.lua")
end

configuration "bsd"
	libdirs {
		"/usr/local/lib",
	}
	includedirs {
		"/usr/local/include",
	}

if _OPTIONS.wincross then
configuration "windows"
	libdirs {
		"/Test/xcompile/local//lib",
	}
	includedirs {
		"/Test/xcompile/local/include/SDL2",
		"/Test/xcompile/local/include",
	}
	defines{'MINGW_WIN_THREAD_COMPAT'}
else
configuration "windows"
 	libdirs {
		"/c/code/SDL/lib",
 	}
 	includedirs {
		"/c/code/SDL/include/SDL2",
		"/c/code/SDL/include",
		"/c/mingw2/include/GL",
 	}
end

configuration "macosx"
	buildoptions { "-isysroot /Developer/SDKs/MacOSX10.6.sdk", "-mmacosx-version-min=10.6" }


configuration "Debug"
	defines { }
	flags { "Symbols" }
	buildoptions { "-ggdb" }
--	buildoptions { "-O3" }
	targetdir "bin/Debug"
	if _OPTIONS.luaassert then defines {"LUA_USE_APICHECK", "LUA_USE_ASSERT"} end
	if _OPTIONS.pedantic then buildoptions { "-Wall" } end
	defines {"TE4_LUA_ALLOW_GENERIC_IO"}

configuration "Release"
	defines { "NDEBUG=1" }
	flags { "Optimize", "NoFramePointer" }
	buildoptions { "-O2" }
	targetdir "bin/Release"


--dofile("build/runner.lua")
dofile("build/te4core.lua")
