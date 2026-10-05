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

// ── The cards: Satışlar, Stok, Sifarişlər ─────────────────────────────────

/// A card's fill: the design's `FFC800` at 21% — `Satışlar`', `Stok`'s and
/// `Sifarişlər`' alike, to the pixel.
///
/// Over the blur, like `Əsas panel`'s rows and the task cards — not glass. A
/// list that can run to thousands of cards gets one shared backdrop blur and
/// a flat tint, never a lens per card.
const Color kDatabaseCardFill = Color(0x36FFC800);

/// A card's corner, on the [kDatabaseFrame]. A plain circular arc: the
/// design's corner fits one to within a pixel all the way round, where a
/// squircle of any radius does not.
const double kDatabaseCardRadius = 34.5;

/// `Postlanıb`, `Satılıb` — the document has got that far.
const Color kSaleDone = Color(0xFF00B506);

/// `Postlanmayıb`, `Satılmayıb` — it has not.
const Color kSalePending = Color(0xFFD80206);

/// An order on its way — `Yeni`, `İcradadır`, `Qismən`: the website's own
/// blue for them (`--accent`), between [kSaleDone]'s arrived and
/// [kSalePending]'s stopped. `Sifarişlər`' design draws only the green.
const Color kOrderUnderway = Color(0xFF4388FF);

// ── The filter ────────────────────────────────────────────────────────────

/// The back button, the search field and the value that is chosen: the
/// design's `D2D2D2` on the panel's white, which is black at 17.6%.
const Color kDatabaseFilterControlFill = Color(0x2D000000);

/// A column that is narrowing the list, and a value under a finger: the
/// design's `EFEFEF`, black at 6.3%.
const Color kDatabaseFilterRowFill = Color(0x10000000);

/// A column row under a finger — a shade past [kDatabaseFilterRowFill], so
/// a column already narrowing the list still answers the press.
const Color kDatabaseFilterPressFill = Color(0x1C000000);
