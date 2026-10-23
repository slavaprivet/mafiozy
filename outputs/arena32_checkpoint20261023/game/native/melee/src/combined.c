/* Composition only. The two accepted numerical translation units are copied
 * byte-for-byte, compiled independently, and retain all their original guards. */
#include "gdextension_interface.h"
#include <string.h>

GDExtensionBool melee_native_init(GDExtensionInterfaceGetProcAddress,
                                 GDExtensionClassLibraryPtr,
                                 GDExtensionInitialization *);
GDExtensionBool melee_skin_init(GDExtensionInterfaceGetProcAddress,
                               GDExtensionClassLibraryPtr,
                               GDExtensionInitialization *);
static GDExtensionInitialization geometry, skin;

static void initialize(void *unused, GDExtensionInitializationLevel level) {
  (void)unused;
  geometry.initialize(geometry.userdata, level);
  skin.initialize(skin.userdata, level);
}
static void deinitialize(void *unused, GDExtensionInitializationLevel level) {
  (void)unused;
  skin.deinitialize(skin.userdata, level);
  geometry.deinitialize(geometry.userdata, level);
}

__declspec(dllexport) GDExtensionBool
melee_kernels_init(GDExtensionInterfaceGetProcAddress get,
                   GDExtensionClassLibraryPtr library,
                   GDExtensionInitialization *out) {
  memset(&geometry, 0, sizeof(geometry));
  memset(&skin, 0, sizeof(skin));
  if (!melee_native_init(get, library, &geometry) ||
      !melee_skin_init(get, library, &skin))
    return 0;
  if (geometry.minimum_initialization_level != GDEXTENSION_INITIALIZATION_SCENE ||
      skin.minimum_initialization_level != GDEXTENSION_INITIALIZATION_SCENE ||
      !geometry.initialize || !geometry.deinitialize || !skin.initialize ||
      !skin.deinitialize)
    return 0;
  out->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
  out->userdata = NULL;
  out->initialize = initialize;
  out->deinitialize = deinitialize;
  return 1;
}
