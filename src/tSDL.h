#ifdef __APPLE__
#include <SDL2/SDL.h>
#include <SDL2_ttf/SDL_ttf.h>
#include <SDL2_image/SDL_image.h>
#elif defined(__FreeBSD__)
#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <SDL2/SDL_image.h>
#elif defined(USE_ANDROID)
#include "SDL.h"
#include "SDL_ttf.h"
#include "SDL_image.h"
#else
#include <SDL.h>
#include <SDL_ttf.h>
#include <SDL_image.h>
#endif
