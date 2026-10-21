/* Output-only prototype. Pure CPU skinning; no actor/resource/pose ownership.
 * Frozen geometry candidate is neither included nor modified. */
#include "../gdextension_interface.h"
#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#define V3 GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY
#define I32 GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY
#define F32 GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY
typedef union {
  uint64_t align[2];
  unsigned char bytes[16];
} Packed;
_Static_assert(sizeof(void *) == 8 && sizeof(float) == 4 &&
                   sizeof(Packed) == 16,
               "Pinned ABI");
static GDExtensionClassLibraryPtr lib;
static DWORD owner_thread;
static uint64_t names[8], empty_string;
static GDExtensionInterfaceStringNameNewWithUtf8Chars sn;
static GDExtensionInterfaceVariantGetPtrConstructor constructor;
static GDExtensionInterfaceVariantGetPtrDestructor destructor;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
static GDExtensionInterfaceGetVariantToTypeConstructor to_type;
static GDExtensionInterfacePackedVector3ArrayOperatorIndexConst vread;
static GDExtensionInterfacePackedVector3ArrayOperatorIndex vwrite;
static GDExtensionInterfacePackedInt32ArrayOperatorIndexConst iread;
static GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst wread;
static GDExtensionPtrBuiltInMethod sizes[3], resize;
static GDExtensionInterfaceClassdbConstructObject3 construct_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionInterfaceObjectMethodBindPtrcall object_call;
static GDExtensionMethodBindPtr notification;
static int64_t count(const void *p, int k) {
  int64_t n = 0;
  sizes[k]((void *)p, NULL, &n, 0);
  return n;
}
static int finite_position(const float *p) {
  return isfinite(p[0]) && isfinite(p[1]) && isfinite(p[2]) &&
         fabsf(p[0]) <= 1e7f && fabsf(p[1]) <= 1e7f && fabsf(p[2]) <= 1e7f;
}
/* Four packed Vector3 columns per bind frame: basis x/y/z, then origin.
 * Exactly ((a*x+b*y)+c*z)+origin, then *weight, then accumulator addition.
 * No preweighted bindpoints, combined influence matrices, or fused operations.
 */
static void calculate(const void *vertices, const void *joints,
                      const void *weights, const void *frames, Packed *out) {
  constructor(V3, 0)(out, NULL);
  if (GetCurrentThreadId() != owner_thread)
    return;
  int64_t n = count(vertices, 0), ni = count(joints, 1), nw = count(weights, 2),
          nf = count(frames, 0);
  if (n < 1 || n > 65536 || ni != n * 4 || nw != ni || nf < 4 || nf > 4096 ||
      nf % 4)
    return;
  const float *p = (const float *)vread(vertices, 0),
              *f = (const float *)vread(frames, 0), *w = wread(weights, 0);
  const int32_t *b = iread(joints, 0);
  int64_t nb = nf / 4;
  for (int64_t i = 0; i < n; i++)
    if (!finite_position(p + i * 3))
      return;
  for (int64_t i = 0; i < nf * 3; i++)
    if (!isfinite(f[i]) || fabsf(f[i]) > 1e7f)
      return;
  for (int64_t i = 0; i < ni; i++)
    if (!isfinite(w[i]) || w[i] < 0 || w[i] > 1 ||
        (w[i] > 0 && (b[i] < 0 || b[i] >= nb)))
      return;
  const void *args[] = {&n};
  int64_t error = 0;
  resize(out, args, &error, 1);
  if (error)
    return;
  float *q = (float *)vwrite(out, 0);
  for (int64_t v = 0; v < n; v++) {
    float x = p[v * 3], y = p[v * 3 + 1], z = p[v * 3 + 2], outx = 0, outy = 0,
          outz = 0;
    for (int j = 0; j < 4; j++) {
      int64_t at = v * 4 + j;
      if (w[at] <= 0)
        continue;
      const float *m = f + (int64_t)b[at] * 12;
      float tx = ((m[0] * x + m[3] * y) + m[6] * z) + m[9];
      float ty = ((m[1] * x + m[4] * y) + m[7] * z) + m[10];
      float tz = ((m[2] * x + m[5] * y) + m[8] * z) + m[11];
      outx = outx + tx * w[at];
      outy = outy + ty * w[at];
      outz = outz + tz * w[at];
    }
    if (!isfinite(outx) || !isfinite(outy) || !isfinite(outz)) {
      int64_t zero = 0;
      const void *reset[] = {&zero};
      resize(out, reset, &error, 1);
      return;
    }
    q[v * 3] = outx;
    q[v * 3 + 1] = outy;
    q[v * 3 + 2] = outz;
  }
}
static void ptrcall(void *userdata, GDExtensionClassInstancePtr instance,
                    const GDExtensionConstTypePtr *args,
                    GDExtensionTypePtr result) {
  calculate(args[0], args[1], args[2], args[3], result);
}
static void call(void *userdata, GDExtensionClassInstancePtr instance,
                 const GDExtensionConstVariantPtr *args, GDExtensionInt n,
                 GDExtensionVariantPtr result, GDExtensionCallError *error) {
  Packed out;
  GDExtensionVariantType types[4] = {V3, I32, F32, V3};
  int valid = n == 4 && GetCurrentThreadId() == owner_thread;
  if (valid)
    for (int i = 0; i < 4; i++)
      if (variant_type(args[i]) != types[i])
        valid = 0;
  if (!valid)
    constructor(V3, 0)(&out, NULL);
  else {
    Packed in[4];
    for (int i = 0; i < 4; i++)
      to_type(types[i])(&in[i], (void *)args[i]);
    calculate(&in[0], &in[1], &in[2], &in[3], &out);
    for (int i = 0; i < 4; i++)
      destructor(types[i])(&in[i]);
  }
  from_type(V3)(result, &out);
  destructor(V3)(&out);
  error->error = GDEXTENSION_CALL_OK;
}
static GDExtensionObjectPtr create(void *data, GDExtensionBool notify) {
  void *instance = malloc(1);
  if (!instance)
    return NULL;
  GDExtensionObjectPtr obj = construct_object(&names[1]);
  set_instance(obj, &names[0], instance);
  if (notify) {
    int64_t what = 0;
    GDExtensionBool reverse = 0;
    const void *args[] = {&what, &reverse};
    object_call(notification, obj, args, NULL);
  }
  return obj;
}
static void release(void *data, GDExtensionClassInstancePtr instance) {
  free(instance);
}
static void initialize(void *data, GDExtensionInitializationLevel level) {
  if (level != GDEXTENSION_INITIALIZATION_SCENE)
    return;
  owner_thread = GetCurrentThreadId();
  const char *text[] = {"MeleeNativeSkin", "Object", "skin",    "",
                        "vertices",        "joints", "weights", "frames"};
  for (int i = 0; i < 8; i++)
    sn(&names[i], text[i]);
  constructor(GDEXTENSION_VARIANT_TYPE_STRING, 0)(&empty_string, NULL);
  GDExtensionClassCreationInfo6 info = {0};
  info.is_exposed = 1;
  info.create_instance_func = create;
  info.free_instance_func = release;
  register_class(lib, &names[0], &names[1], &info);
  GDExtensionPropertyInfo result = {.type = V3,
                                    .name = &names[3],
                                    .class_name = &names[3],
                                    .hint_string = &empty_string,
                                    .usage = 6};
  GDExtensionPropertyInfo args[4] = {result, result, result, result};
  GDExtensionVariantType types[] = {V3, I32, F32, V3};
  GDExtensionClassMethodArgumentMetadata metadata[4] = {0};
  for (int i = 0; i < 4; i++) {
    args[i].type = types[i];
    args[i].name = &names[4 + i];
  }
  GDExtensionClassMethodInfo method = {0};
  method.name = &names[2];
  method.call_func = call;
  method.ptrcall_func = ptrcall;
  method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
  method.has_return_value = 1;
  method.return_value_info = &result;
  method.argument_count = 4;
  method.arguments_info = args;
  method.arguments_metadata = metadata;
  register_method(lib, &names[0], &method);
}
static void deinitialize(void *data, GDExtensionInitializationLevel level) {
  if (level != GDEXTENSION_INITIALIZATION_SCENE)
    return;
  unregister_class(lib, &names[0]);
  for (int i = 0; i < 8; i++)
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(&names[i]);
  destructor(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}
#define LOAD(var, type, name)                                                  \
  var = (type)get(name);                                                       \
  if (!var)                                                                    \
  return 0
__declspec(dllexport)
GDExtensionBool melee_skin_init(GDExtensionInterfaceGetProcAddress get,
                                GDExtensionClassLibraryPtr library,
                                GDExtensionInitialization *init) {
  lib = library;
  GDExtensionInterfaceGetGodotVersion2 vf =
      (GDExtensionInterfaceGetGodotVersion2)get("get_godot_version2");
  if (!vf)
    return 0;
  GDExtensionGodotVersion2 version;
  vf(&version);
  if (version.major != 4 || version.minor != 7 || version.patch != 2)
    return 0;
  LOAD(sn, GDExtensionInterfaceStringNameNewWithUtf8Chars,
       "string_name_new_with_utf8_chars");
  LOAD(constructor, GDExtensionInterfaceVariantGetPtrConstructor,
       "variant_get_ptr_constructor");
  LOAD(destructor, GDExtensionInterfaceVariantGetPtrDestructor,
       "variant_get_ptr_destructor");
  LOAD(variant_type, GDExtensionInterfaceVariantGetType, "variant_get_type");
  LOAD(from_type, GDExtensionInterfaceGetVariantFromTypeConstructor,
       "get_variant_from_type_constructor");
  LOAD(to_type, GDExtensionInterfaceGetVariantToTypeConstructor,
       "get_variant_to_type_constructor");
  uint64_t scratch[8];
  memset(scratch, 0xa5, sizeof(scratch));
  constructor(GDEXTENSION_VARIANT_TYPE_VECTOR3, 0)(scratch, NULL);
  for (int i = 0; i < 64; i++)
    if (((unsigned char *)scratch)[i] != (i < 12 ? 0 : 0xa5))
      return 0;
  LOAD(vread, GDExtensionInterfacePackedVector3ArrayOperatorIndexConst,
       "packed_vector3_array_operator_index_const");
  LOAD(vwrite, GDExtensionInterfacePackedVector3ArrayOperatorIndex,
       "packed_vector3_array_operator_index");
  LOAD(iread, GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,
       "packed_int32_array_operator_index_const");
  LOAD(wread, GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst,
       "packed_float32_array_operator_index_const");
  LOAD(construct_object, GDExtensionInterfaceClassdbConstructObject3,
       "classdb_construct_object3");
  LOAD(set_instance, GDExtensionInterfaceObjectSetInstance,
       "object_set_instance");
  LOAD(register_class, GDExtensionInterfaceClassdbRegisterExtensionClass6,
       "classdb_register_extension_class6");
  LOAD(register_method, GDExtensionInterfaceClassdbRegisterExtensionClassMethod,
       "classdb_register_extension_class_method");
  LOAD(unregister_class, GDExtensionInterfaceClassdbUnregisterExtensionClass,
       "classdb_unregister_extension_class");
  LOAD(object_call, GDExtensionInterfaceObjectMethodBindPtrcall,
       "object_method_bind_ptrcall");
  GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin =
      (GDExtensionInterfaceVariantGetPtrBuiltinMethod)get(
          "variant_get_ptr_builtin_method");
  GDExtensionInterfaceClassdbGetMethodBind bind =
      (GDExtensionInterfaceClassdbGetMethodBind)get("classdb_get_method_bind");
  if (!builtin || !bind)
    return 0;
  uint64_t size_name, resize_name, object_name, notify_name;
  sn(&size_name, "size");
  sn(&resize_name, "resize");
  sn(&object_name, "Object");
  sn(&notify_name, "notification");
  GDExtensionVariantType types[] = {V3, I32, F32};
  for (int i = 0; i < 3; i++)
    sizes[i] = builtin(types[i], &size_name, 3173160232);
  resize = builtin(V3, &resize_name, 848867239);
  notification = bind(&object_name, &notify_name, 4023243586);
  uint64_t *cleanup[] = {&size_name, &resize_name, &object_name, &notify_name};
  for (int i = 0; i < 4; i++)
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(cleanup[i]);
  if (!sizes[0] || !sizes[1] || !sizes[2] || !resize || !notification)
    return 0;
  init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
  init->initialize = initialize;
  init->deinitialize = deinitialize;
  init->userdata = NULL;
  return 1;
}
