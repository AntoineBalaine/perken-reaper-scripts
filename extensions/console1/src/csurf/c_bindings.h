/* The C declarations that the Zig sources of Console1 and MFT use, translated
 * by the build into the "c" module. Because @cImport is gone since Zig 0.17,
 * the includes and definitions that each file's @cImport held live here. */
#ifndef CONSOLE1_C_BINDINGS_H
#define CONSOLE1_C_BINDINGS_H

/* ARM64 has unsigned char by default, so WDL's signedness assertion is skipped. */
#define WDL_ALLOW_UNSIGNED_DEFAULT_CHAR 1
#ifndef _WIN32
#define SWELL_PROVIDED_BY_APP
#endif

#include "csurf/control_surface_wrapper.h"
#ifdef _WIN32
#include <windows.h>
#else
#include "WDL/swell/swell-types.h"
#include "WDL/swell/swell-functions.h"
#endif
#include "WDL/win32_utf8.h"
#include "WDL/wdltypes.h"
#include "resource.h"
#include "csurf/midi_wrapper.h"

#endif
