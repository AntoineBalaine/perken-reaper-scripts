#include "control_surface_wrapper.h"

#include "control_surface.h"
#include <new>

extern "C" {

C_ControlSurface ControlSurface_Create() {
  return new (std::nothrow) ZigControlSurface();
}

void ControlSurface_Destroy(C_ControlSurface instance) {
  delete static_cast<ZigControlSurface *>(instance);
}
}
