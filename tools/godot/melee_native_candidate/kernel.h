/* Exact scalar double port of current melee_triangle_contact.gd / source
 * npc_melee_contact.mjs. No fast-math or fused reassociation permitted. */
#pragma once
#include <math.h>
#include <stdint.h>
typedef struct {
  double x, y, z;
} V;
typedef struct {
  int valid, hit;
  V point, line, normal, weights;
  double score, dist;
} Hit;
static V v(double x, double y, double z) { return (V){x, y, z}; }
static V add(V a, V b) { return v(a.x + b.x, a.y + b.y, a.z + b.z); }
static V sub(V a, V b) { return v(a.x - b.x, a.y - b.y, a.z - b.z); }
static V mul(V a, double k) { return v(a.x * k, a.y * k, a.z * k); }
static double dot(V a, V b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
static V cross(V a, V b) {
  return v(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
}
static double dist2(V a, V b) { return dot(sub(a, b), sub(a, b)); }
static double clamp(double x, double a, double b) {
  return fmin(fmax(x, a), b);
}
static V readv(const double *p) { return v(p[0], p[1], p[2]); }
static int finite_only(V p) {
  return isfinite(p.x) && isfinite(p.y) && isfinite(p.z);
}
static int finite_v(V p) {
  return finite_only(p) && fabs(p.x) <= 1e7 && fabs(p.y) <= 1e7 &&
         fabs(p.z) <= 1e7;
}
static V closest(V p, V a, V b, V c) {
  V ab = sub(b, a), ac = sub(c, a), ap = sub(p, a);
  double d1 = dot(ab, ap), d2 = dot(ac, ap);
  if (d1 <= 0 && d2 <= 0)
    return a;
  V bp = sub(p, b);
  double d3 = dot(ab, bp), d4 = dot(ac, bp);
  if (d3 >= 0 && d4 <= d3)
    return b;
  double vc = d1 * d4 - d3 * d2;
  if (vc <= 0 && d1 >= 0 && d3 <= 0)
    return add(a, mul(ab, d1 / (d1 - d3)));
  V cp = sub(p, c);
  double d5 = dot(ab, cp), d6 = dot(ac, cp);
  if (d6 >= 0 && d5 <= d6)
    return c;
  double vb = d5 * d2 - d1 * d6;
  if (vb <= 0 && d2 >= 0 && d6 <= 0)
    return add(a, mul(ac, d2 / (d2 - d6)));
  double va = d3 * d6 - d5 * d4;
  if (va <= 0 && d4 - d3 >= 0 && d5 - d6 >= 0)
    return add(b, mul(sub(c, b), (d4 - d3) / ((d4 - d3) + (d5 - d6))));
  double inv = 1.0 / (va + vb + vc), u = vb * inv, w = vc * inv;
  return add(add(a, mul(ab, u)), mul(ac, w));
}
static void edge(V from, V to, V p, V q, V *line, V *point) {
  V d = sub(to, from), e = sub(q, p), r = sub(from, p);
  double aa = dot(d, d), ee = dot(e, e), f = dot(e, r), s = 0, t = 0;
  if (aa < 1e-14)
    t = ee > 1e-14 ? clamp(f / ee, 0, 1) : 0;
  else {
    double c = dot(d, r);
    if (ee < 1e-14)
      s = clamp(-c / aa, 0, 1);
    else {
      double b = dot(d, e), den = aa * ee - b * b;
      s = den > 1e-14 ? clamp((b * f - c * ee) / den, 0, 1) : 0;
      t = (b * s + f) / ee;
      if (t < 0) {
        t = 0;
        s = clamp(-c / aa, 0, 1);
      } else if (t > 1) {
        t = 1;
        s = clamp((b - c) / aa, 0, 1);
      }
    }
  }
  *line = add(from, mul(d, s));
  *point = add(p, mul(e, t));
}
static int ray(V from, V direction, V a, V b, V c, V *point) {
  V e = sub(b, a), f = sub(c, a), n = cross(e, f);
  double ddn = dot(direction, n), sign = 1;
  if (ddn > 0)
    sign = 1;
  else if (ddn < 0) {
    sign = -1;
    ddn = -ddn;
  } else
    return 0;
  V d = sub(from, a);
  double u = sign * dot(direction, cross(d, f));
  if (u < 0)
    return 0;
  double w = sign * dot(direction, cross(e, d));
  if (w < 0 || u + w > ddn)
    return 0;
  double distance = -sign * dot(d, n);
  if (distance < 0)
    return 0;
  *point = add(from, mul(direction, distance / ddn));
  return 1;
}
static Hit sample(V from, V to, double radius, V a, V b, V c) {
  Hit h = {.valid = 1};
  V ab = sub(b, a), ac = sub(c, a), normal = cross(ab, ac);
  double ns = dot(normal, normal);
  if (ns < 1e-14)
    return h;
  normal = mul(normal, 1.0 / sqrt(ns));
  V delta = sub(to, from);
  double length = sqrt(dot(delta, delta));
  V p, l;
  int intersection =
      length > 1e-10 && ray(from, mul(delta, 1.0 / length), a, b, c, &p);
  double best = 0;
  if (intersection && dist2(from, p) <= length * length + 1e-10)
    l = p;
  else {
    p = closest(from, a, b, c);
    l = from;
    best = dist2(from, p);
    V test = closest(to, a, b, c);
    double d = dist2(to, test);
    if (d < best) {
      best = d;
      p = test;
      l = to;
    }
    V ep[3] = {a, b, c}, eq[3] = {b, c, a};
    for (int i = 0; i < 3; i++) {
      V tl, tp;
      edge(from, to, ep[i], eq[i], &tl, &tp);
      d = dist2(tl, tp);
      if (d < best) {
        best = d;
        l = tl;
        p = tp;
      }
    }
  }
  if (best > radius * radius + 1e-10)
    return h;
  V outward = sub(l, p);
  double os = dot(outward, outward);
  if ((os > 1e-12 && dot(normal, outward) < 0) ||
      (os <= 1e-12 && dot(normal, delta) > 0))
    normal = mul(normal, -1);
  V ap = sub(p, a);
  double d00 = dot(ac, ac), d01 = dot(ac, ab), d02 = dot(ac, ap),
         d11 = dot(ab, ab), d12 = dot(ab, ap), det = d00 * d11 - d01 * d01;
  if (det == 0) {
    h.valid = 0;
    return h;
  }
  double inv = 1.0 / det, u = (d11 * d02 - d01 * d12) * inv,
         w = (d00 * d12 - d01 * d02) * inv;
  if (!finite_only(p) || !finite_only(l) || !isfinite(normal.x) ||
      !isfinite(normal.y) || !isfinite(normal.z) || !isfinite(u) ||
      !isfinite(w) || !isfinite(best)) {
    h.valid = 0;
    return h;
  }
  h.hit = 1;
  h.point = p;
  h.line = l;
  h.normal = normal;
  h.weights = v(1.0 - u - w, w, u);
  h.score = dist2(from, l) + best;
  h.dist = best;
  return h;
}
