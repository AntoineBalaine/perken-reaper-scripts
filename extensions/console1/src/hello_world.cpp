// Bare-bone REAPER extension
//
// 1. Grab reaper_plugin.h from
// https://github.com/justinfrankel/reaper-sdk/raw/main/sdk/reaper_plugin.h
// 2. Grab reaper_plugin_functions.h by running the REAPER action "[developer]
// Write C++ API functions header"
// 3. Grab WDL: git clone https://github.com/justinfrankel/WDL.git
// 4. Build then copy or link the binary file into <REAPER resource
// directory>/UserPlugins
//
// Linux
// =====
//
// c++ -fPIC -O2 -std=c++14 -IWDL/WDL -shared reaper_barebone.cpp -o reaper_barebone.so
// 
//
// macOS
// =====
//
// c++ -fPIC -O2 -std=c++14 -IWDL/WDL -dynamiclib reaper_barebone.cpp -o
// reaper_barebone.dylib
//
// Windows
// =======
//
// (Use the VS Command Prompt matching your REAPER architecture, eg. x64 to use
// the 64-bit compiler) cl /nologo /O2 /Z7 /Zo /DUNICODE reaper_barebone.cpp
// /link /DEBUG /OPT:REF /PDBALTPATH:%_PDB% /DLL /OUT:reaper_barebone.dll

#define REAPERAPI_IMPLEMENT
#include "reaper_plugin_functions.h"

#include <cstdio>
#include "fakeCsurf.h"


extern "C" REAPER_PLUGIN_DLL_EXPORT int
REAPER_PLUGIN_ENTRYPOINT(REAPER_PLUGIN_HINSTANCE instance,
                         reaper_plugin_info_t *rec) {

  FakeCsurf *fake_csurf = NULL;
  if (!rec) {
    // cleanup code here

    return 0;
  }

  if (rec->caller_version != REAPER_PLUGIN_VERSION)
    return 0;

  // see also https://gist.github.com/cfillion/350356a62c61a1a2640024f8dc6c6770
  ShowConsoleMsg = (decltype(ShowConsoleMsg))rec->GetFunc("ShowConsoleMsg");

  if (!ShowConsoleMsg) {
    fprintf(stderr, "[reaper_barebone] Unable to import ShowConsoleMsg\n");
    return 0;
  }

  // initialization code here
  if (rec->GetFunc) {
    plugin_register =
        (decltype(plugin_register))rec->GetFunc("plugin_register");
  }
  if (!plugin_register) {

    ShowConsoleMsg("no register!\n");
  } else {

    fake_csurf = new FakeCsurf();
    plugin_register("csurf_inst", fake_csurf);
    ShowConsoleMsg("Hello World!\n");
  }

  return 1;
}
