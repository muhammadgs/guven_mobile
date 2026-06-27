#version 460 core
#include <flutter/runtime_effect.glsl>

// Flowing "liquid" blue/violet gradient for the onboarding background.
//
// Uses Inigo-Quilez style domain warping over fbm value-noise to grow large,
// organic blobs with bright ridges where they fold toward the light — the
// fluid-wallpaper look. Everything is procedural and animates off uTime.

precision highp float;

uniform vec2 uResolution;
uniform float uTime;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = m * p;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  vec2 p = uv;
  p.x *= uResolution.x / uResolution.y; // aspect correct
  p *= 1.6;                             // blob scale

  float t = uTime * 0.25;              // flow speed

  // Domain warp: warp the sample point by fbm of itself, twice.
  vec2 q = vec2(
    fbm(p + vec2(0.0, 0.0) + 0.12 * t),
    fbm(p + vec2(5.2, 1.3) - 0.10 * t)
  );

  vec2 r = vec2(
    fbm(p + 3.5 * q + vec2(1.7, 9.2) + 0.20 * t),
    fbm(p + 3.5 * q + vec2(8.3, 2.8) - 0.16 * t)
  );

  float f = fbm(p + 3.5 * r);

  // Palette: deep navy valleys -> royal blue -> violet, bright ridges.
  vec3 deep   = vec3(0.015, 0.010, 0.055);
  vec3 navy   = vec3(0.050, 0.065, 0.320);
  vec3 royal  = vec3(0.130, 0.200, 0.880);
  vec3 violet = vec3(0.430, 0.190, 0.930);
  vec3 hi     = vec3(0.820, 0.860, 1.000);

  vec3 col = deep;
  col = mix(col, navy,   smoothstep(0.05, 0.65, f));
  col = mix(col, royal,  smoothstep(0.30, 0.98, f));
  col = mix(col, violet, clamp(length(q) - 0.25, 0.0, 1.0));

  float ridge = pow(clamp(f, 0.0, 1.0), 2.2);
  col = mix(col, hi, ridge * clamp(r.x, 0.0, 1.0) * 0.85);

  // Soft vignette to settle the corners.
  vec2 cc = uv - 0.5;
  float vig = smoothstep(1.10, 0.35, length(cc) * 1.25);
  col *= mix(0.80, 1.0, vig);

  fragColor = vec4(col, 1.0);
}
