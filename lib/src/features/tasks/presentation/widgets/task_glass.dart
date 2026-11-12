/// The Tapşırıqlar screen's own palette.
///
/// It borrows the signed-in app's ink and lift from `home_glass.dart` — the
/// two screens sit on the same background and must read as the same app — but
/// the surfaces here are different in kind. The cards are *not* lenses: the
/// design asks for a flat mint fill over a plain background blur, and only the
/// scope indicator and the two tool buttons are real glass.
library;

import 'package:flutter/material.dart';

import '../../../../shared/glass/app_glass.dart';

export '../../../home/presentation/widgets/home_glass.dart'
    show
        AppGlassStyle,
        AppGlassSurface,
        glassAtRadius,
        kGlassInk,
        kGlassInkMuted,
        kGlassLift,
        kNavIndicatorRestFill,
        lerpAppGlassStyle;

/// The card's fill: the design's `D5F3F2`, held back to a little over half
/// opacity so the blurred background still moves under it. At full opacity the
/// card is a flat mint rectangle and the blur below it is wasted.
const Color kTaskCardFill = Color(0x94D5F3F2);

/// Blur under a card.
///
/// The design says 15. Figma measures a background blur by its kernel and
/// Flutter by the gaussian's sigma, which is about half of it — this is that
/// 15 converted, and the knob to turn if the cards read too crisp or too soft.
const double kTaskCardBlurSigma = 7.5;

/// The card's corner, on the phone canvas.
const double kTaskCardRadius = 24;

/// The scope bar itself: flat grey, no glass. Only the marker travelling
/// across it is a lens.
const Color kScopeBarFill = Color(0xFFEDEFF0);

/// The hairline around that bar, so it still reads as a container on the
/// palest part of the background.
const Color kScopeBarBorder = Color(0x14202B3A);

/// An unselected cell's icon and label.
const Color kScopeInkMuted = Color(0x8C121A26);

/// The ink on a card's description — a step down from the headline without
/// going grey, which at this size would read as disabled.
const Color kTaskBodyInk = Color(0xCC0C1017);

/// Printed on the gradient buttons and the status chips. Both sit on
/// saturated colour, so this is the app's ink rather than white: the design's
/// buttons carry dark labels.
const Color kTaskButtonInk = Color(0xFF10151C);

/// Under a card. Barely there — the cards are close together and a deep
/// shadow on each one turns the list grey between them.
const List<BoxShadow> kTaskCardLift = <BoxShadow>[
  BoxShadow(
    color: Color(0x142B4A7A),
    blurRadius: 18,
    spreadRadius: -8,
    offset: Offset(0, 8),
  ),
];

/// The filter and new-task buttons.
///
/// Small, round, and sitting on the bare background rather than on another
/// surface, so they carry more tint than the wide surfaces on the home screen.
const AppGlassStyle kTaskToolGlass = AppGlassStyle(
  cornerRadius: 22,
  glassColor: Color(0x1F000000),
  blur: 0,
);

/// The filter panel's glass — the design's Figma numbers.
///
/// The Figma layer is a white fill at 79% under a Glass effect with Frost 27,
/// which maps one to one onto [AppGlassStyle.blur]. That 27 is a heavy frost
/// and the single knob to turn if the panel reads too soft over the task
/// list. It is *not* the same conversion as [kTaskCardBlurSigma]: that one
/// comes from Figma's plain background-blur effect, which is measured as a
/// kernel and halves.
const AppGlassStyle kTaskFilterGlass = AppGlassStyle(
  cornerRadius: 30,
  glassColor: Color(0xC9FFFFFF),
  blur: 27,
);

/// Under the filter panel. Deeper than [kGlassLift]: this one floats over the
/// whole screen rather than sitting in the layout, and the shadow is most of
/// what says so.
const List<BoxShadow> kTaskFilterLift = <BoxShadow>[
  BoxShadow(
    color: Color(0x2E1B3055),
    blurRadius: 40,
    spreadRadius: -12,
    offset: Offset(0, 18),
  ),
];

/// A filter row that is doing something — the selected column, and a value
/// that is ticked. Glass over glass would muddy both, so the marker is a plain
/// white capsule, the way the design draws it.
const Color kTaskFilterRowFill = Color(0x8FFFFFFF);

/// The ink on a filter row that is not selected.
const Color kTaskFilterRowInk = Color(0xD90C1017);

/// The count on a column that is narrowing the list, and on the filter button
/// itself. The site marks an active column in blue and so does this.
const Color kTaskFilterBadge = Color(0xFF4AB6FF);

// ── Yeni tapşırıq ─────────────────────────────────────────────────────────
//
// The chooser and the sheet are deliberately *not* given a glass of their own:
// they are one surface growing out of the `+` button, and the user asked for
// the filter's glass exactly — so [kTaskFilterGlass] is what they wear, and
// there is one set of Figma numbers on this screen rather than two that drift.

/// How dark the screen goes behind the open sheet, and how far it is blurred.
///
/// The chooser barely shades anything (it is a menu, and the list behind it is
/// still the subject); the sheet is a page in its own right and the design
/// pushes the task list well back behind it.
const Color kNewTaskMenuScrim = Color(0x14101826);
const Color kNewTaskSheetScrim = Color(0x66070C14);
const double kNewTaskSheetBlur = 14;

/// A field's box inside the sheet.
///
/// A small piece of glass sitting on a big one, so it carries only a faint
/// tint; its rim is what says "this is a box you can press" on a surface with
/// no fill of its own.
const AppGlassStyle kNewTaskFieldGlass = AppGlassStyle(
  cornerRadius: 23,
  glassColor: Color(0x14101826),
  blur: 6,
);

/// What a box is drawn as while the sheet is still flying.
///
/// Not a preference — a necessity. The sheet's contents cross-fade inside the
/// glass, and a fade is an `Opacity`, which opens a `saveLayer`. A lens under
/// one samples that empty layer and renders **black**
/// ([backdrop-filter-black-flash]). So for the few hundred milliseconds the
/// form is fading in, the boxes are this flat fill instead, and they become
/// lenses on the frame the flight lands. It is the same colour as
/// [kNewTaskFieldGlass]'s tint, so the swap is a rim appearing, not a colour
/// changing.
const Color kNewTaskFieldFill = Color(0x14101826);

/// What a field says once it has been answered.
const Color kNewTaskValueInk = Color(0xE6070C14);

/// …and while it has not.
const Color kNewTaskHintInk = Color(0x73101826);

/// The option list that grows out of a field.
///
/// Dark, per the design: it opens *over* the sheet rather than beside it, and
/// a pale panel on a pale panel leaves the eye nothing to separate them by.
/// The darkness is also what stops the two lenses reading as a double image —
/// this one keeps very little of the sheet's own refraction.
const AppGlassStyle kNewTaskPickerGlass = AppGlassStyle(
  cornerRadius: 26,
  glassColor: Color(0xA0CACACA),
  blur: 22,
);

/// Type on the dark picker.
const Color kNewTaskPickerInk = Color(0xFF000000);
const Color kNewTaskPickerInkMuted = Color(0xFF000000);

/// The capsule under the option that is already chosen.
const Color kNewTaskPickerRowFill = Color(0x1FFFFFFF);

/// The two buttons at the foot of the sheet, in the design's own stops.
const List<Color> kNewTaskCancelGradient = <Color>[
  Color(0xFFFE8750),
  Color(0xFFFF0048),
];
const List<Color> kNewTaskSubmitGradient = <Color>[
  Color(0xFF2BF07E),
  Color(0xFF00E0EB),
];

/// The waveform of a voice note: the part already played, and the part not.
const Color kVoiceWaveLive = Color(0xFF2E9BF0);
const Color kVoiceWaveRest = Color(0x662E9BF0);

/// The recorder's own controls — delete, pause, send, microphone.
const Color kVoiceControlInk = Color(0xFF2E9BF0);
const Color kVoiceDeleteInk = Color(0xFF6B7684);
