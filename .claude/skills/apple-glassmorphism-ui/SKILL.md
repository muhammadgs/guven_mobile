# Apple Glassmorphism UI

## Purpose

Use this skill when designing or implementing modern Apple-inspired soft UI, glassmorphism cards, translucent panels, premium dashboard surfaces, rounded containers, blurred backgrounds, and elegant mobile interfaces in Flutter.

This project is the native Flutter mobile application for the Güvən Finans platform. The desired visual direction can include modern soft design, Apple-like glass effects, rounded corners, calm finance/business aesthetics, and premium mobile polish.

## Visual Direction

The UI should feel:
- premium
- calm
- clean
- modern
- soft
- trustworthy
- finance/business appropriate
- mobile native

Use Apple-inspired glass carefully, not excessively.

Good use cases:
- dashboard summary cards
- floating panels
- profile cards
- task detail cards
- modal/bottom sheet backgrounds
- premium headers
- status sections

Avoid making every element glass. Too much glass reduces readability and performance.

## Core Glass Principles

Glass UI should combine:

```txt
translucency
background blur
soft border
subtle shadow
large radius
clean spacing
clear readable content

A good glass card usually has:

white or surface color with alpha
thin semi-transparent border
blur behind it
soft shadow
radius between 20 and 32
enough internal padding
readable text contrast
Flutter Glass Pattern

Use this pattern when glass is needed:

import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

Only introduce a reusable GlassCard when multiple screens/components need it.

Background Rules

Glass needs something behind it to be visible.

Use subtle backgrounds:

light gradients
soft abstract blobs
very subtle colored circles
calm finance-friendly surfaces
low-opacity decorative shapes

Example background idea:

base background: very light warm/blue/gray
top-right soft purple blob
bottom-left soft blue blob
glass cards above

Avoid:

noisy images
high contrast backgrounds
too many colors
saturated gradients behind text
Color Rules

Prefer calm colors:

white
off-white
very light gray
soft blue
soft violet
subtle green for success
subtle amber for warnings
subtle red for errors

Avoid:

neon colors
strong saturated gradients everywhere
childish color combinations
too many accent colors on one screen

For Güvən Finans, the interface should look serious and trustworthy.

Radius Rules

Apple-style soft UI usually uses high radius:

Small chips:        10-14
Inputs:             16-20
Buttons:            16-22
Cards:              20-28
Hero panels:        28-36
Bottom sheets:      28 top radius

Use consistent radius. Do not mix random radius values.

Shadow Rules

Use soft shadows:

BoxShadow(
  color: Colors.black.withValues(alpha: 0.06),
  blurRadius: 24,
  offset: const Offset(0, 12),
)

For stronger elevated cards:

BoxShadow(
  color: Colors.black.withValues(alpha: 0.10),
  blurRadius: 32,
  offset: const Offset(0, 16),
)

Avoid harsh shadows:

black with high opacity
small blur with large offset
multiple heavy shadows
Border Rules

Glass borders should be subtle:

Border.all(
  color: Colors.white.withValues(alpha: 0.30),
)

For light non-glass cards:

Border.all(
  color: Colors.black.withValues(alpha: 0.06),
)

Borders should help separation without looking heavy.

Blur Rules

Use blur moderately:

sigmaX: 12-20
sigmaY: 12-20

High blur everywhere can hurt performance.

Avoid using many BackdropFilter widgets inside long scrolling lists. For lists, prefer solid soft cards instead of many blurred cards.

Typography Rules

Glass UI needs strong typography hierarchy.

Use:

bold titles
clear section labels
readable body text
muted secondary text
consistent letter spacing

Avoid placing low-contrast text on translucent backgrounds.

Button Rules

Buttons should still be clear.

Primary button:

solid accent color
high contrast white text
52-56 height
16-20 radius
optional soft shadow

Secondary button:

translucent/soft surface
border or light background
readable label

Do not make primary actions too transparent.

Input Rules

For glass/soft forms:

inputs can have filled soft background
border should be subtle
radius 16-20
height 52-58
icons can be muted
focused state should be clear

Avoid overly transparent inputs if readability suffers.

Dashboard Rules

For premium dashboard:

use a calm background
top profile/greeting area
2-4 summary cards
quick action cards
recent task cards
soft section separation
avoid dense web-dashboard layout

Glass may be used for:

hero user card
summary cards
floating quick action panel

But task list cards should usually be simple solid soft cards for readability.

Task UI Rules

For task management:

status chips should be clear
deadline and priority should be easy to scan
cards should not be overly decorative
primary action should stand out
attachments/comments should be compact

Use glass only for high-level panels, not every task row.

Performance Rules

BackdropFilter is visually beautiful but can be expensive.

Avoid:

glass on every item in a long ListView
multiple nested BackdropFilters
animated blur unless necessary
heavy shadows on dozens of cards

Prefer:

glass for headers/hero cards
solid soft cards for repeated lists
simple gradients for background
Accessibility Rules

Even beautiful UI must be readable.

Check:

contrast
font size
button visibility
input clarity
status chip readability

If glass reduces readability, reduce transparency or use solid surface.

Output Behavior

When asked to create Apple-style glass UI:

Identify which elements should be glass.
Keep primary actions solid and clear.
Use blur and translucency selectively.
Use consistent radius, spacing, and shadows.
Avoid excessive visual noise.
Keep the code Flutter-native and maintainable.
Do not add dependencies without approval.

When asked to review an existing glass design:

mention if blur is overused
mention if contrast is weak
mention if performance may suffer
suggest simpler alternatives when needed
Strict Constraints

Never:

Make every UI element glass.
Sacrifice readability for style.
Add random packages for blur/glass.
Use heavy blur in large lists.
Copy Apple UI exactly.
Use copyrighted assets.
Modify unrelated files.
