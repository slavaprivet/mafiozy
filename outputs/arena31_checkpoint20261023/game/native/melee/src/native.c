#include "gdextension_interface.h"
#include "kernel.h"
#include <stdlib.h>
#include <string.h>
#include <windows.h>
/* Isolated prototype: plain C ABI, exact dumped 4.7.2 single-precision x64 ABI.
 * PackedFloat64Array payloads cross the boundary once per batch. */
#define MAX_V 65536
#define MAX_T 131072
#define WIDTH 16
typedef struct {
  V lo, hi;
  int left, right, first, count;
} Node;
typedef struct {
  Hit h;
  int tri, limb;
} Candidate;
typedef struct {
  V *vertices, *centers;
  int *indices, *order, *stack;
  Node *nodes;
  int nv, nt, nn, ready;
  int64_t revision, query;
  Candidate *hits;
  size_t nh, cap, cursor;
  int query_ready;
} Context;
typedef union {
  uint64_t align[2];
  unsigned char bytes[16];
} Packed;
_Static_assert(sizeof(void *) == 8 && sizeof(float) == 4 &&
                   sizeof(double) == 8 && sizeof(Packed) == 16,
               "Pinned Windows x64 single-real ABI required");
static GDExtensionClassLibraryPtr library;
static DWORD main_thread;
static uint64_t class_name, parent_name, run_name, vertices_name, empty_name,
    arg_name;
static uint64_t empty_string;
static GDExtensionInterfaceStringNameNewWithUtf8Chars sn;
static GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
static GDExtensionInterfaceGetVariantToTypeConstructor to_type;
static GDExtensionInterfaceVariantGetType variant_type;
static GDExtensionInterfaceVariantGetPtrConstructor constructor;
static GDExtensionInterfaceVariantGetPtrDestructor destructor;
static GDExtensionInterfacePackedFloat64ArrayOperatorIndex array_at;
static GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst array_read;
static GDExtensionPtrBuiltInMethod array_size, array_resize, vertices_size;
static GDExtensionInterfacePackedVector3ArrayOperatorIndexConst vertex_read;
static GDExtensionInterfaceClassdbConstructObject3 construct_object;
static GDExtensionInterfaceObjectSetInstance set_instance;
static GDExtensionInterfaceObjectMethodBindPtrcall object_ptrcall;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
static GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
static GDExtensionMethodBindPtr notification;
static Context *sort_context;
static int sort_axis;
static double axis(V p, int a) { return a == 0 ? p.x : a == 1 ? p.y : p.z; }
static V low(V a, V b) {
  return v(fmin(a.x, b.x), fmin(a.y, b.y), fmin(a.z, b.z));
}
static V high(V a, V b) {
  return v(fmax(a.x, b.x), fmax(a.y, b.y), fmax(a.z, b.z));
}
static void clear_query(Context *c) {
  c->nh = 0;
  c->cursor = 0;
  c->query_ready = 0;
  c->query++;
}
static void clear_mesh(Context *c) {
  free(c->vertices);
  free(c->centers);
  free(c->indices);
  free(c->order);
  free(c->stack);
  free(c->nodes);
  free(c->hits);
  memset(c, 0, sizeof(*c));
  c->revision = -1;
}
static int order_compare(const void *pa, const void *pb) {
  int a = *(const int *)pa, b = *(const int *)pb;
  double aa = axis(sort_context->centers[a], sort_axis),
         bb = axis(sort_context->centers[b], sort_axis);
  return aa < bb ? -1 : aa > bb ? 1 : a < b ? -1 : a > b;
}
static int hit_compare(const void *pa, const void *pb) {
  const Candidate *a = pa, *b = pb;
  if (a->h.score < b->h.score)
    return -1;
  if (a->h.score > b->h.score)
    return 1;
  if (a->tri != b->tri)
    return a->tri < b->tri ? -1 : 1;
  return a->limb < b->limb ? -1 : a->limb > b->limb;
}
static int build(Context *c, int first, int count) {
  int at = c->nn++;
  Node *n = &c->nodes[at];
  n->first = first;
  n->count = count;
  n->left = n->right = -1;
  if (count <= 4)
    return at;
  V lo = c->centers[c->order[first]], hi = lo;
  for (int i = 1; i < count; i++) {
    V p = c->centers[c->order[first + i]];
    lo = low(lo, p);
    hi = high(hi, p);
  }
  V e = sub(hi, lo);
  sort_axis = e.x >= e.y && e.x >= e.z ? 0 : e.y >= e.z ? 1 : 2;
  sort_context = c;
  qsort(c->order + first, count, sizeof(int), order_compare);
  int middle = count / 2;
  n->left = build(c, first, middle);
  n->right = build(c, first + middle, count - middle);
  return at;
}
static void refit(Context *c) {
  for (int at = c->nn - 1; at >= 0; at--) {
    Node *n = &c->nodes[at];
    if (n->left >= 0) {
      n->lo = low(c->nodes[n->left].lo, c->nodes[n->right].lo);
      n->hi = high(c->nodes[n->left].hi, c->nodes[n->right].hi);
    } else {
      V lo = c->vertices[c->indices[c->order[n->first] * 3]], hi = lo;
      for (int t = 0; t < n->count; t++)
        for (int j = 0; j < 3; j++) {
          V p = c->vertices[c->indices[c->order[n->first + t] * 3 + j]];
          lo = low(lo, p);
          hi = high(hi, p);
        }
      n->lo = lo;
      n->hi = hi;
    }
  }
}
static int overlap(Node *n, V lo, V hi) {
  return n->hi.x >= lo.x && n->lo.x <= hi.x && n->hi.y >= lo.y &&
         n->lo.y <= hi.y && n->hi.z >= lo.z && n->lo.z <= hi.z;
}
static int append_hit(Context *c, Hit h, int tri, int limb, int limbs) {
  if (c->nh == c->cap) {
    size_t cap = c->cap ? c->cap * 2 : 256, max = (size_t)c->nt * limbs;
    if (cap > max)
      cap = max;
    if (cap <= c->cap)
      return 0;
    void *p = realloc(c->hits, cap * sizeof(Candidate));
    if (!p)
      return 0;
    c->hits = p;
    c->cap = cap;
  }
  c->hits[c->nh++] = (Candidate){h, tri, limb};
  return 1;
}
static void write_v(double *p, V a) {
  p[0] = a.x;
  p[1] = a.y;
  p[2] = a.z;
}
static void write_hit(double *p, Hit h) {
  write_v(p + 2, h.point);
  write_v(p + 5, h.line);
  write_v(p + 8, h.normal);
  write_v(p + 11, h.weights);
  p[14] = h.score;
  p[15] = h.dist;
}
static int make_array(Packed *out, int64_t size) {
  constructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY, 0)(out, NULL);
  const void *args[] = {&size};
  int64_t error = 0;
  array_resize(out, args, &error, 1);
  return error == 0;
}
static void error_array(Packed *out, int code) {
  if (!make_array(out, 2))
    return;
  double *p = array_at(out, 0);
  p[0] = -1;
  p[1] = code;
}
static void scalar_array(Packed *out, double a, double b, double d) {
  if (!make_array(out, 3))
    return;
  double *p = array_at(out, 0);
  p[0] = a;
  p[1] = b;
  p[2] = d;
}
static int exact_int(double x, int lo, int hi) {
  return isfinite(x) && x >= lo && x <= hi && floor(x) == x;
}
static int valid_revision(double x) {
  return isfinite(x) && x >= 0 && x <= 9007199254740991.0 && floor(x) == x;
}
static void page(Context *c, int count, Packed *out) {
  size_t n = c->nh - c->cursor;
  if (n > (size_t)count)
    n = count;
  if (!make_array(out, 7 + n * WIDTH))
    return;
  double *p = array_at(out, 0);
  p[0] = 1;
  p[1] = (double)c->revision;
  p[2] = (double)c->query;
  p[3] = (double)c->nh;
  p[4] = (double)c->cursor;
  p[5] = (double)n;
  p[6] = WIDTH;
  for (size_t i = 0; i < n; i++) {
    Candidate *x = &c->hits[c->cursor + i];
    double *r = p + 7 + i * WIDTH;
    r[0] = x->tri;
    r[1] = x->limb;
    write_hit(r, x->h);
  }
  c->cursor += n;
}
static void dispatch(Context *c, const double *p, int64_t len, Packed *out) {
  if (GetCurrentThreadId() != main_thread || !c || len < 1 ||
      !exact_int(p[0], 0, 5)) {
    error_array(out, 1);
    return;
  }
  int op = (int)p[0];
  if (op == 0) {
    if (len != 17) {
      error_array(out, 2);
      return;
    }
    V a = readv(p + 8), b = readv(p + 11), d = readv(p + 14),
      from = readv(p + 1), to = readv(p + 4);
    double r = p[7];
    if (!finite_v(a) || !finite_v(b) || !finite_v(d) || !finite_v(from) ||
        !finite_v(to) || !isfinite(r) || r <= 0 || r > .5) {
      error_array(out, 3);
      return;
    }
    Hit h = sample(from, to, r, a, b, d);
    if (!make_array(out, WIDTH))
      return;
    double *q = array_at(out, 0);
    q[0] = h.valid;
    q[1] = h.hit;
    write_hit(q, h);
    return;
  }
  if (op == 1) {
    if (c->ready || c->vertices) {
      error_array(out, 4);
      return;
    }
    if (len < 4 || !valid_revision(p[1]) || !exact_int(p[2], 1, MAX_V) ||
        !exact_int(p[3], 1, MAX_T)) {
      error_array(out, 5);
      return;
    }
    int nv = p[2], nt = p[3];
    if (len != 4 + (int64_t)nv * 3 + (int64_t)nt * 3) {
      error_array(out, 2);
      return;
    }
    for (int i = 0; i < nv; i++)
      if (!finite_v(readv(p + 4 + i * 3))) {
        error_array(out, 3);
        return;
      }
    for (int i = 0; i < nt * 3; i++)
      if (!exact_int(p[4 + nv * 3 + i], 0, nv - 1)) {
        error_array(out, 6);
        return;
      }
    c->vertices = malloc(nv * sizeof(V));
    c->centers = malloc(nt * sizeof(V));
    c->indices = malloc(nt * 3 * sizeof(int));
    c->order = malloc(nt * sizeof(int));
    c->nodes = calloc(nt * 2, sizeof(Node));
    c->stack = malloc(nt * 2 * sizeof(int));
    if (!c->vertices || !c->centers || !c->indices || !c->order || !c->nodes ||
        !c->stack) {
      clear_mesh(c);
      error_array(out, 7);
      return;
    }
    c->nv = nv;
    c->nt = nt;
    for (int i = 0; i < nv; i++)
      c->vertices[i] = readv(p + 4 + i * 3);
    for (int i = 0; i < nt * 3; i++)
      c->indices[i] = (int)p[4 + nv * 3 + i];
    for (int i = 0; i < nt; i++) {
      c->order[i] = i;
      c->centers[i] = mul(add(add(c->vertices[c->indices[i * 3]],
                                  c->vertices[c->indices[i * 3 + 1]]),
                              c->vertices[c->indices[i * 3 + 2]]),
                          1.0 / 3.0);
    }
    build(c, 0, nt);
    refit(c);
    free(c->centers);
    c->centers = NULL;
    c->ready = 1;
    c->revision = (int64_t)p[1];
    scalar_array(out, 1, nv, nt);
    return;
  }
  if (op == 2) {
    clear_query(c);
    c->ready = 0;
    if (len < 3 || !c->vertices || !valid_revision(p[1]) ||
        p[1] <= c->revision || p[2] != c->nv || len != 3 + (int64_t)c->nv * 3) {
      error_array(out, 8);
      return;
    }
    for (int i = 0; i < c->nv; i++)
      if (!finite_v(readv(p + 3 + i * 3))) {
        error_array(out, 3);
        return;
      }
    for (int i = 0; i < c->nv; i++)
      c->vertices[i] = readv(p + 3 + i * 3);
    refit(c);
    c->revision = (int64_t)p[1];
    c->ready = 1;
    scalar_array(out, 1, c->revision, c->nn);
    return;
  }
  if (op == 5) {
    if (len != 1) {
      error_array(out, 2);
      return;
    }
    clear_query(c);
    scalar_array(out, 1, c->revision, c->query);
    return;
  }
  if (op == 4) {
    if (len != 4 || !c->query_ready || p[1] != c->revision ||
        p[2] != c->query || !exact_int(p[3], 1, 256)) {
      error_array(out, 9);
      return;
    }
    page(c, (int)p[3], out);
    return;
  }
  clear_query(c);
  if (len < 4 || !c->ready || p[1] != c->revision || !exact_int(p[2], 1, 4) ||
      !exact_int(p[3], 1, 256) || len != 4 + p[2] * 7) {
    error_array(out, 10);
    return;
  }
  int limbs = p[2];
  for (int s = 0; s < limbs; s++) {
    const double *k = p + 4 + s * 7;
    V from = readv(k), to = readv(k + 3);
    double r = k[6];
    if (!finite_v(from) || !finite_v(to) || !isfinite(r) || r <= 0 || r > .5) {
      error_array(out, 3);
      return;
    }
  }
  for (int s = 0; s < limbs; s++) {
    const double *k = p + 4 + s * 7;
    V from = readv(k), to = readv(k + 3);
    double r = k[6];
    /* The exact kernel accepts squared distances through r*r + 1e-10.
     * Broadphase must contain that whole band, including outward rounding of
     * sqrt and endpoint +/- extent. The narrowphase still receives original r. */
    double extent = nextafter(sqrt(r * r + 1e-10), INFINITY);
    V lo = sub(low(from, to), v(extent, extent, extent));
    V hi = add(high(from, to), v(extent, extent, extent));
    lo = v(nextafter(lo.x, -INFINITY), nextafter(lo.y, -INFINITY),
           nextafter(lo.z, -INFINITY));
    hi = v(nextafter(hi.x, INFINITY), nextafter(hi.y, INFINITY),
           nextafter(hi.z, INFINITY));
    int stack = 0;
    c->stack[stack++] = 0;
    while (stack) {
      Node *n = &c->nodes[c->stack[--stack]];
      if (!overlap(n, lo, hi))
        continue;
      if (n->left >= 0) {
        c->stack[stack++] = n->left;
        c->stack[stack++] = n->right;
        continue;
      }
      for (int i = 0; i < n->count; i++) {
        int tri = c->order[n->first + i];
        V a = c->vertices[c->indices[tri * 3]],
          b = c->vertices[c->indices[tri * 3 + 1]],
          d = c->vertices[c->indices[tri * 3 + 2]];
        Node box = {.lo = low(low(a, b), d), .hi = high(high(a, b), d)};
        if (!overlap(&box, lo, hi))
          continue;
        Hit h = sample(from, to, r, a, b, d);
        if (!h.valid) {
          clear_query(c);
          error_array(out, 11);
          return;
        }
        if (h.hit && !append_hit(c, h, tri, s, limbs)) {
          clear_query(c);
          error_array(out, 7);
          return;
        }
      }
    }
  }
  if (c->nh > 1)
    qsort(c->hits, c->nh, sizeof(Candidate), hit_compare);
  c->query_ready = 1;
  page(c, (int)p[3], out);
}
/* float_64 API: native Vector3 is exactly three float32 components, Packed
 * array metadata stays opaque. Widen each component identically to GDScript
 * float. */
static void direct_refit(Context *c, const void *packed, int64_t revision,
                         Packed *out) {
  if (GetCurrentThreadId() != main_thread || !c) {
    error_array(out, 1);
    return;
  }
  clear_query(c);
  c->ready = 0;
  int64_t len = 0;
  vertices_size((void *)packed, NULL, &len, 0);
  if (!c->vertices || len != c->nv || revision < 0 ||
      revision > 9007199254740991LL || revision <= c->revision) {
    error_array(out, 8);
    return;
  }
  const float *p = (const float *)vertex_read(packed, 0);
  for (int i = 0; i < c->nv; i++)
    if (!finite_v(v(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]))) {
      error_array(out, 3);
      return;
    }
  for (int i = 0; i < c->nv; i++)
    c->vertices[i] = v(p[i * 3], p[i * 3 + 1], p[i * 3 + 2]);
  refit(c);
  c->revision = revision;
  c->ready = 1;
  scalar_array(out, 1, revision, c->nn);
}
static void vertices_ptrcall(void *userdata,
                             GDExtensionClassInstancePtr instance,
                             const GDExtensionConstTypePtr *args,
                             GDExtensionTypePtr result) {
  direct_refit(instance, args[0], *(const int64_t *)args[1], result);
}
static void vertices_call(void *userdata, GDExtensionClassInstancePtr instance,
                          const GDExtensionConstVariantPtr *args,
                          GDExtensionInt count, GDExtensionVariantPtr result,
                          GDExtensionCallError *error) {
  Packed out;
  if (GetCurrentThreadId() != main_thread || !instance) {
    error_array(&out, 1);
  } else if (count != 2 ||
      variant_type(args[0]) != GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY ||
      variant_type(args[1]) != GDEXTENSION_VARIANT_TYPE_INT) {
    /* A failed owner-thread refit must never expose the preceding pose. This
     * branch cannot enter direct_refit, so invalidate here before reporting. */
    Context *c = instance;
    clear_query(c);
    c->ready = 0;
    error_array(&out, 12);
  } else {
    Packed in;
    int64_t revision;
    to_type(GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY)(&in,
                                                           (void *)args[0]);
    to_type(GDEXTENSION_VARIANT_TYPE_INT)(&revision, (void *)args[1]);
    direct_refit(instance, &in, revision, &out);
    destructor(GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY)(&in);
  }
  from_type(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY)(result, &out);
  destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY)(&out);
  error->error = GDEXTENSION_CALL_OK;
}
static void ptrcall(void *userdata, GDExtensionClassInstancePtr instance,
                    const GDExtensionConstTypePtr *args,
                    GDExtensionTypePtr result) {
  int64_t len = 0;
  array_size((void *)args[0], NULL, &len, 0);
  const double *p = len ? array_read(args[0], 0) : NULL;
  dispatch(instance, p, len, result);
}
static void call(void *userdata, GDExtensionClassInstancePtr instance,
                 const GDExtensionConstVariantPtr *args, GDExtensionInt count,
                 GDExtensionVariantPtr result, GDExtensionCallError *error) {
  Packed out;
  if (count != 1 ||
      variant_type(args[0]) != GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY) {
    error_array(&out, 12);
  } else {
    Packed in;
    to_type(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY)(&in,
                                                           (void *)args[0]);
    int64_t len = 0;
    array_size(&in, NULL, &len, 0);
    dispatch(instance, len ? array_read(&in, 0) : NULL, len, &out);
    destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY)(&in);
  }
  from_type(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY)(result, &out);
  destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY)(&out);
  error->error = GDEXTENSION_CALL_OK;
}
static GDExtensionObjectPtr create(void *userdata, GDExtensionBool notify) {
  Context *c = calloc(1, sizeof(Context));
  if (!c)
    return NULL;
  c->revision = -1;
  GDExtensionObjectPtr obj = construct_object(&parent_name);
  set_instance(obj, &class_name, c);
  if (notify) {
    int64_t what = 0;
    GDExtensionBool reversed = 0;
    const void *args[] = {&what, &reversed};
    object_ptrcall(notification, obj, args, NULL);
  }
  return obj;
}
static void release(void *userdata, GDExtensionClassInstancePtr instance) {
  Context *c = instance;
  clear_mesh(c);
  free(c);
}
static void initialize(void *userdata, GDExtensionInitializationLevel level) {
  if (level != GDEXTENSION_INITIALIZATION_SCENE)
    return;
  main_thread = GetCurrentThreadId();
  sn(&class_name, "MeleeNativeGeometry");
  sn(&parent_name, "Object");
  sn(&run_name, "run");
  sn(&vertices_name, "refit_vertices");
  sn(&empty_name, "");
  sn(&arg_name, "payload");
  constructor(GDEXTENSION_VARIANT_TYPE_STRING, 0)(&empty_string, NULL);
  GDExtensionClassCreationInfo6 info = {0};
  info.is_exposed = 1;
  info.create_instance_func = create;
  info.free_instance_func = release;
  register_class(library, &class_name, &parent_name, &info);
  GDExtensionPropertyInfo property = {
      .type = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,
      .name = &arg_name,
      .class_name = &empty_name,
      .hint = 0,
      .hint_string = &empty_string,
      .usage = 6};
  GDExtensionClassMethodArgumentMetadata metadata =
      GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
  GDExtensionClassMethodInfo method = {0};
  method.name = &run_name;
  method.call_func = call;
  method.ptrcall_func = ptrcall;
  method.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
  method.has_return_value = 1;
  method.return_value_info = &property;
  method.argument_count = 1;
  method.arguments_info = &property;
  method.arguments_metadata = &metadata;
  register_method(library, &class_name, &method);
  GDExtensionPropertyInfo arguments[2] = {property, property};
  arguments[0].type = GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY;
  arguments[1].type = GDEXTENSION_VARIANT_TYPE_INT;
  GDExtensionClassMethodArgumentMetadata metas[2] = {
      GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
      GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64};
  method.name = &vertices_name;
  method.call_func = vertices_call;
  method.ptrcall_func = vertices_ptrcall;
  method.argument_count = 2;
  method.arguments_info = arguments;
  method.arguments_metadata = metas;
  register_method(library, &class_name, &method);
}
static void deinitialize(void *userdata, GDExtensionInitializationLevel level) {
  if (level != GDEXTENSION_INITIALIZATION_SCENE)
    return;
  unregister_class(library, &class_name);
  uint64_t *names[] = {&class_name,    &parent_name, &run_name,
                       &vertices_name, &empty_name,  &arg_name};
  for (int i = 0; i < 6; i++)
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(names[i]);
  destructor(GDEXTENSION_VARIANT_TYPE_STRING)(&empty_string);
}
#define LOAD(var, type, name)                                                  \
  var = (type)get(name);                                                       \
  if (!var)                                                                    \
  return 0
__declspec(dllexport)
GDExtensionBool melee_native_init(GDExtensionInterfaceGetProcAddress get,
                                  GDExtensionClassLibraryPtr lib,
                                  GDExtensionInitialization *init) {
  GDExtensionInterfaceGetGodotVersion2 version_func =
      (GDExtensionInterfaceGetGodotVersion2)get("get_godot_version2");
  if (!version_func)
    return 0;
  GDExtensionGodotVersion2 version;
  version_func(&version);
  if (version.major != 4 || version.minor != 7 || version.patch != 2)
    return 0;
  library = lib;
  LOAD(vertex_read, GDExtensionInterfacePackedVector3ArrayOperatorIndexConst,
       "packed_vector3_array_operator_index_const");
  LOAD(sn, GDExtensionInterfaceStringNameNewWithUtf8Chars,
       "string_name_new_with_utf8_chars");
  LOAD(from_type, GDExtensionInterfaceGetVariantFromTypeConstructor,
       "get_variant_from_type_constructor");
  LOAD(to_type, GDExtensionInterfaceGetVariantToTypeConstructor,
       "get_variant_to_type_constructor");
  LOAD(variant_type, GDExtensionInterfaceVariantGetType, "variant_get_type");
  LOAD(constructor, GDExtensionInterfaceVariantGetPtrConstructor,
       "variant_get_ptr_constructor");
  LOAD(destructor, GDExtensionInterfaceVariantGetPtrDestructor,
       "variant_get_ptr_destructor");
  LOAD(array_at, GDExtensionInterfacePackedFloat64ArrayOperatorIndex,
       "packed_float64_array_operator_index");
  LOAD(array_read, GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst,
       "packed_float64_array_operator_index_const");
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
  LOAD(object_ptrcall, GDExtensionInterfaceObjectMethodBindPtrcall,
       "object_method_bind_ptrcall");
  /* Default Vector3 construction must write exactly twelve zero bytes. Larger
   * scratch permits safe rejection of double-real builds before any packed
   * read. */
  uint64_t scratch[8];
  memset(scratch, 0xa5, sizeof(scratch));
  constructor(GDEXTENSION_VARIANT_TYPE_VECTOR3, 0)(scratch, NULL);
  unsigned char *bytes = (unsigned char *)scratch;
  for (int i = 0; i < 64; i++)
    if (bytes[i] != (i < 12 ? 0 : 0xa5))
      return 0;
  GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin =
      (GDExtensionInterfaceVariantGetPtrBuiltinMethod)get(
          "variant_get_ptr_builtin_method");
  uint64_t size_name, resize_name, object_name, notification_name;
  sn(&size_name, "size");
  sn(&resize_name, "resize");
  sn(&object_name, "Object");
  sn(&notification_name, "notification");
  vertices_size = builtin(GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,
                          &size_name, 3173160232);
  array_size = builtin(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,
                       &size_name, 3173160232);
  array_resize = builtin(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,
                         &resize_name, 848867239);
  GDExtensionInterfaceClassdbGetMethodBind bind =
      (GDExtensionInterfaceClassdbGetMethodBind)get("classdb_get_method_bind");
  notification = bind(&object_name, &notification_name, 4023243586);
  uint64_t *names[] = {&size_name, &resize_name, &object_name,
                       &notification_name};
  for (int i = 0; i < 4; i++)
    destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(names[i]);
  if (!vertices_size || !array_size || !array_resize || !notification)
    return 0;
  init->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
  init->initialize = initialize;
  init->deinitialize = deinitialize;
  init->userdata = NULL;
  return 1;
}
