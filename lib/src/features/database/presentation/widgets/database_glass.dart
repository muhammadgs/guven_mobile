/// The `Baza` tab's own palette.
///
/// Two kinds of surface, deliberately different. The rows of `Əsas panel` are
/// *not* glass — the design asks for a flat grey fill over a plain background
/// blur — while the menu button and the `Detallar` menu that grows out of it
/// are the task list's filter button and filter panel exactly, so they wear
/// that screen's glass rather than a copy of it that could drift.
library;

import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';

export '../../../tasks/presentation/widgets/task_glass.dart'
    show
        AppGlassBackend,
        AppGlassSurface,
        kGlassInk,
        kGlassInkMuted,
        kGlassLift,
        kTaskFilterGlass,
        kTaskFilterLift,
        kTaskToolGlass,
        lerpAppGlassStyle;

/// The width of the phone the `Baza` designs are drawn on: an iPhone 16 Pro.
///
/// Every dimension on this tab is written as the design gives it on that
/// frame and multiplied by [databaseScale] — not by `scaled`, which assumes
/// the app's 390pt canvas and would make the whole tab 3% too large.
const double kDatabaseFrame = 402;

/// The multiplier for a dimension measured on the [kDatabaseFrame].
double databaseScale(BuildContext context) =>
    uiScaleForFrame(context, kDatabaseFrame);

/// The face every figure on this tab is set in.
const String kDatabaseFigureFont = 'ChakraPetch';

/// A row's fill: the design's `A2A2A2` at 20%, as Figma gives it.
const Color kDatabaseRowFill = Color(0x33A2A2A2);

/// Blur under a row.
///
/// The design gives the fill but not the blur, so this is the task cards'
/// value — Figma's 15, halved into a sigma (see `kTaskCardBlurSigma`) — which
/// keeps the two lists reading as one app. The knob to turn if the rows look
/// too crisp or too soft.
const double kDatabaseRowBlurSigma = 7.5;

/// The arc's thickness at its widest, on the phone canvas.
const double kDatabaseArcThickness = 5.5;

/// The screen behind the open menu: a light grey veil and a heavy blur, the
/// way the design pushes the page back without darkening it.
const Color kDatabaseMenuScrim = Color(0x1F0C1017);
const double kDatabaseMenuBlur = 8;

/// The capsule under a menu row that is open, current, or under a finger.
///
/// Grey, as this design draws it — darker than the panel, where the filter's
/// capsule is lighter than its own.
const Color kDatabaseMenuRowFill = Color(0x1C000000);
