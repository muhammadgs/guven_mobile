#version 460 core
#include <flutter/runtime_effect.glsl>

// Liquid glass over a backdrop that was blurred ONCE.
//
// The optics are ported from liquid_glass_renderer (Tim Lehmann for
// whynotmake.it; 0.2.x MIT, 1.0 Apache-2.0): its iOS 27 "regular" glass —
// the bevel lens that pulls the backdrop inward at the edge, the glint along
// the light axis, the dark outer contour and the inner bevel shadow.
//
// What is NOT ported is how the package gets its backdrop: it reads and
// blurs the live screen through a BackdropFilter on every frame, which is
// what made a mid-range phone stutter. Here the backdrop is a picture the
// app blurred once (`glass_backdrop.dart`); this shader only samples it.
// One pass, no backdrop copy, no blur, no geometry texture: the rounded
// rectangle's distance field and normal are computed analytically.
//
// All lengths are logical pixels unless a name ends in Px.

precision highp float;

// -- Uniforms (Dart writes them in this order; see liquid_glass.dart) --------

uniform vec4 uShape;    //  0- 3: origin.xy, size.xy — canvas-local
uniform vec4 uFrame;    //  4- 7: corner radius, px per unit, fade, has backdrop
uniform vec4 uPicture;  //  8-11: this shape's rect in the picture, as uv LTRB
uniform vec4 uTint;     // 12-15: straight rgb, alpha
uniform vec4 uOptics;   // 16-19: refraction height, amount, dispersion, highlight
uniform vec4 uRim;      // 20-23: contour strength, contour directionality,
                        //        bevel shadow strength, rim sharpness
uniform vec4 uExtra;    // 24-27: saturation, has sharp, highlight opposite, —
uniform vec4 uLens;     // 28-31: magnification, bevel fits shape (1) or
                        //        clear-glass lens (0), —, —

uniform sampler2D uBlurred;  // the backdrop, blurred once
uniform sampler2D uSharp;    // the same backdrop unblurred (rim only)

out vec4 fragColor;

// -- The renderer's fixed rim geometry (GlassRim) ----------------------------

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

// Light travels down the screen: it comes from above.
const vec2 kLight = vec2(0.0, 1.0);

const float kGlintWidth = 1.2;
const float kGlintPeak = 0.252;
const float kGlintBleed = 0.21;
const float kGlintBleedReach = 4.0;
const float kGlintLuminance = 1.6;
const float kGlintVibrancy = 2.85;

const float kContourWidth = 0.75;

const float kBevelShadowDepth = 16.0;
const float kBevelShadowOffset = 6.0;
const float kBevelShadowDirectionality = 0.5;

// Below this many physical pixels of colour split, one sample is enough.
const float kDispersionSubpixel = 0.25;

// -- Sampling ----------------------------------------------------------------

// Mirrors a uv that ran off the picture back into it, so the lens at the
// screen's edge bends in the picture's own border instead of transparency.
vec2 mirrorUv(vec2 uv) {
  vec2 mirrored = vec2(1.0) - abs(mod(uv, vec2(2.0)) - vec2(1.0));
  vec2 uvOut = clamp(mirrored, vec2(0.0005), vec2(0.9995));
  // Flutter 3.44/3.45's GLES backend keeps render-to-texture images with GL's
  // bottom-left origin; 3.46 removed that and defines this macro.
#if defined(IMPELLER_TARGET_OPENGLES) && \
    !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uvOut.y = 1.0 - uvOut.y;
#endif
  return uvOut;
}

// The backdrop at [uv]: the blurred picture, with [sharpMix] of the sharp
// one laid over it.
vec4 backdropAt(vec2 uv, float sharpMix) {
  vec2 at = mirrorUv(uv);
  vec4 color = texture(uBlurred, at);
  if (sharpMix > 0.001) {
    color = mix(color, texture(uSharp, at), sharpMix);
  }
  return color;
}

// -- Rim helpers (renderer 1.0) ----------------------------------------------

float contourIntegral(float t, float width) {
  float u = clamp(t, 0.0, width);
  return u - u * u / (2.0 * width);
}

// How much of a one-pixel footprint at [outwardPx] the outer contour covers.
float contourCoverage(float outwardPx, float widthPx) {
  if (widthPx <= 0.0) return 0.0;
  return contourIntegral(max(outwardPx + 0.5, 0.0), widthPx) -
         contourIntegral(max(outwardPx - 0.5, 0.0), widthPx);
}

vec3 applySaturation(vec3 color, float saturation) {
  float luminance = dot(color, kLuma);
  float chroma = max(max(color.r, color.g), color.b) -
                 min(min(color.r, color.g), color.b);
  float chromaWeight = clamp((chroma - 0.15) / 0.65, 0.0, 1.0);
  float effective = saturation + 0.4 * chromaWeight;
  return clamp(mix(vec3(luminance), color, effective), 0.0, 1.0);
}

void main() {
  vec2 size = uShape.zw;
  vec2 local = FlutterFragCoord().xy - uShape.xy;

  float radiusSetting = uFrame.x;
  float pxPerUnit = max(uFrame.y, 0.0001);
  float fade = clamp(uFrame.z, 0.0, 1.0);
  bool hasBackdrop = uFrame.w > 0.5;

  float refractionHeight = uOptics.x;
  float refractionAmount = uOptics.y;
  float dispersion = uOptics.z;
  float highlight = uOptics.w;

  // -- Shape: signed distance to a rounded rectangle, negative inside ------
  vec2 halfSize = size * 0.5;
  vec2 p = local - halfSize;
  float halfMinor = min(halfSize.x, halfSize.y);
  float radius = min(radiusSetting, halfMinor);
  vec2 q = abs(p) - halfSize + radius;
  float sd = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
  float inward = -sd;
  float inwardPx = inward * pxPerUnit;

  float materialAlpha = clamp(inwardPx + 0.5, 0.0, 1.0);

  // -- Bevel: how deep the edge bends, and how far it reaches -----------------
  float bevel;
  float amount;
  if (uLens.y > 0.5) {
    // Regular glass: the bevel is at most a quarter of the shorter side, and
    // the edge never pulls the backdrop past the shape's centre line.
    bevel = min(refractionHeight, 0.5 * halfMinor);
    amount = min(refractionAmount, halfMinor);
  } else {
    // A clear lens keeps its bevel until it would pass the centre line; then
    // the whole lens shrinks, so the pull never changes direction.
    float lensScale = min(1.0, halfMinor / max(refractionHeight, 0.001));
    bevel = refractionHeight * lensScale;
    amount = refractionAmount * lensScale;
  }

  // -- Outward normal --------------------------------------------------------
  // Turned round a corner at least as wide as the deepest rim effect, so the
  // seam where a rectangle's normal flips from a side to the top lies deeper
  // than any of them reach (the renderer's "optical" corner).
  float opticalRadius = min(
    max(radius, max(bevel, kBevelShadowDepth + kBevelShadowOffset)),
    halfMinor
  );
  vec2 side = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
  vec2 oq = abs(p) - halfSize + opticalRadius;
  vec2 normal;
  if (oq.x > 0.0 && oq.y > 0.0) {
    normal = side * normalize(oq);
  } else if (oq.x > oq.y) {
    normal = vec2(side.x, 0.0);
  } else {
    normal = vec2(0.0, side.y);
  }

  // How square the normal is to the light: 1 on the left and right walls,
  // 0 on the top and bottom.
  float tangency = abs(dot(normal, vec2(-kLight.y, kLight.x)));

  // -- Outer contour: a hairline of shadow just outside the edge -----------
  float contourAlpha =
    contourCoverage(-inwardPx, kContourWidth * pxPerUnit) * uRim.x *
    mix(1.0, tangency, clamp(uRim.y, 0.0, 1.0)) * fade;

  if (materialAlpha <= 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, contourAlpha);
    return;
  }

  // -- Refraction: the bevel lens pulls the backdrop inward at the edge ----
  vec2 displacement = vec2(0.0);
  float bevelX = 0.0;
  if (bevel > 0.001 && inward < bevel) {
    bevelX = 1.0 - clamp(max(inward, 0.0) / bevel, 0.0, 1.0);
    float magnitude = clamp(
      amount * (1.0 - sqrt(1.0 - bevelX * bevelX)),
      0.0,
      refractionAmount
    );
    displacement = normal * (-magnitude) * fade;
  }

  // -- Transmitted light: the baked backdrop, bent -------------------------
  vec4 transmitted = vec4(0.0);
  if (hasBackdrop) {
    vec2 uvPerUnit = (uPicture.zw - uPicture.xy) / size;
    // A magnifying lens shows less of what is under it, spread wider: the
    // point it shows at [local] lies nearer its centre.
    float magnification = max(uLens.x, 0.01);
    vec2 source = halfSize + (local - halfSize) / magnification;
    vec2 uv = uPicture.xy + source * uvPerUnit;
    float sharpMix = uExtra.y > 0.5
      ? clamp(uRim.w, 0.0, 1.0) * smoothstep(0.0, 1.0, bevelX)
      : 0.0;
    float splitPx = abs(dispersion) * length(displacement) * pxPerUnit;
    if (splitPx <= kDispersionSubpixel) {
      transmitted = backdropAt(uv + displacement * uvPerUnit, sharpMix);
    } else {
      float strength = dispersion * 0.5;
      vec4 green = backdropAt(uv + displacement * uvPerUnit, sharpMix);
      float red = backdropAt(
        uv + displacement * (1.0 + strength) * uvPerUnit, sharpMix).r;
      float blue = backdropAt(
        uv + displacement * (1.0 - strength) * uvPerUnit, sharpMix).b;
      transmitted = vec4(red, green.g, blue, green.a);
    }
    transmitted *= fade;
  }

  // -- Body: the tint over what comes through (premultiplied) --------------
  float tintAlpha = clamp(uTint.a, 0.0, 1.0) * fade;
  vec4 body = vec4(uTint.rgb * tintAlpha, tintAlpha) +
              transmitted * (1.0 - tintAlpha);

  // -- Inner bevel shadow: light from above shades the top inner wall ------
  float inwardDistance = max(inward, 0.0);
  if (uRim.z >= 0.001) {
    float lightFacing = dot(normal, -kLight);
    float shadowShift = kBevelShadowOffset * lightFacing;
    float penumbra = 2.0 * shadowShift;
    float leading = penumbra > 0.001
      ? smoothstep(0.0, penumbra, inwardDistance)
      : 1.0;
    float falloff =
      1.0 - smoothstep(0.0, kBevelShadowDepth, inwardDistance - shadowShift);
    float wrapped = smoothstep(0.0, 1.0, lightFacing * 0.5 + 0.5);
    float direction = mix(1.0, wrapped, kBevelShadowDirectionality);
    float shadow = clamp(leading * falloff * direction * uRim.z, 0.0, 1.0);
    body.rgb = max(body.rgb - transmitted.rgb * (1.0 - tintAlpha) * shadow,
                   vec3(0.0));
  }

  vec3 color = body.a > 0.0001 ? body.rgb / body.a : vec3(0.0);
  if (abs(uExtra.x - 1.0) > 0.001) {
    color = applySaturation(color, uExtra.x);
  }

  // -- Glint: a thin bright line where the edge faces the light ------------
  float glintProfile =
    clamp(1.0 - inwardDistance / kGlintWidth, 0.0, 1.0) +
    kGlintBleed *
      clamp(1.0 - inwardDistance / (kGlintWidth * kGlintBleedReach), 0.0, 1.0);
  float lobe = 1.0 - tangency;
  float returnWeight = dot(normal, -kLight) >= 0.0
    ? 1.0
    : clamp(uExtra.z, 0.0, 1.0);
  float glint = clamp(
    max(highlight, 0.0) * kGlintPeak * lobe * returnWeight * glintProfile,
    0.0,
    1.0
  ) * fade;

  float alpha = body.a;
  if (glint > 0.0) {
    float luminance = dot(color, kLuma);
    vec3 target = vec3(kGlintLuminance) +
                  (color - vec3(luminance)) * kGlintVibrancy;
    color = max(mix(color, target, glint), vec3(0.0));
    alpha = mix(alpha, 1.0, glint);
  }

  vec4 glass = vec4(clamp(color, 0.0, 1.0) * alpha, alpha) * materialAlpha;
  // The contour lies under the glass, so only shows where the glass is not.
  fragColor = glass + vec4(0.0, 0.0, 0.0, contourAlpha) * (1.0 - glass.a);
}
