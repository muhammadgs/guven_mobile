# Material 3 Flutter System

## Purpose

Use this skill when creating or improving the Flutter Material 3 design system, app theme, colors, typography, buttons, inputs, cards, chips, navigation, dialogs, bottom sheets, and reusable UI foundations.

This project is the native Flutter mobile app for Güvən Finans. The UI should feel modern, professional, clean, mobile-native, and maintainable.

## Main Responsibility

Build UI using Flutter and Material 3 principles.

Prefer:
- `ThemeData`
- `ColorScheme`
- `TextTheme`
- Material 3 components
- reusable shared widgets
- consistent spacing
- consistent radius
- consistent input/button/card behavior
- theme-driven styling

Avoid:
- random hardcoded colors everywhere
- inconsistent button styles
- duplicated `TextStyle`s
- one-off card designs repeated manually
- mixing many unrelated design languages
- adding UI packages without approval

## Theme Philosophy

The app should have one clear visual foundation.

The theme should define:
- primary color
- secondary color
- background color
- surface color
- error color
- text colors
- app bar style
- button style
- input style
- card style
- chip style
- bottom sheet style
- dialog style

Feature screens should consume the theme instead of reinventing styles.

## Project Theme Location

Use this file for app-level theme:

```txt
lib/src/app/app_theme.dart

Later, if the design system grows, split into:

lib/src/shared/theme/app_colors.dart
lib/src/shared/theme/app_spacing.dart
lib/src/shared/theme/app_radius.dart
lib/src/shared/theme/app_shadows.dart
lib/src/shared/theme/app_text_styles.dart

Do not over-engineer too early. Start simple and extract only when repeated patterns appear.

Material 3 Setup

Use:

ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppTheme.primaryColor,
    brightness: Brightness.light,
  ),
)

Use ColorScheme for semantic colors:

final colors = Theme.of(context).colorScheme;

colors.primary
colors.onPrimary
colors.secondary
colors.surface
colors.onSurface
colors.error
colors.onError

Avoid using arbitrary colors without reason.

Color Rules

For Güvən Finans, prefer calm, trustworthy colors.

Good palette direction:

soft violet / blue as primary
clean off-white background
white or near-white surfaces
dark readable text
muted gray secondary text
green for success
amber/orange for warning
red for error
subtle borders

Avoid:

too many strong colors
neon colors
low contrast text
random gradients everywhere
childish color combinations
Typography Rules

Use TextTheme where possible.

Recommended mapping:

headlineLarge  -> big hero titles
headlineMedium -> screen titles
titleLarge     -> section titles
titleMedium    -> card titles
bodyLarge      -> main body text
bodyMedium     -> secondary body text
labelLarge     -> button labels
labelMedium    -> chips/badges
labelSmall     -> metadata

Example:

final theme = Theme.of(context);

Text(
  'Güvən Finans',
  style: theme.textTheme.headlineMedium?.copyWith(
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
  ),
)

Avoid repeating raw large TextStyle blocks unless the style is truly unique.

Spacing System

Use consistent spacing:

2   -> micro adjustment
4   -> tiny
8   -> small
12  -> compact
16  -> default
20  -> medium
24  -> screen padding / section padding
32  -> large section
40  -> hero gap
48+ -> special hero spacing

Avoid random values such as 17, 23, 31, 37 unless a design reason exists.

Radius System

Use consistent radius:

8   -> tiny chips / small badges
12  -> chips / compact controls
16  -> inputs / small cards
20  -> buttons / standard cards
24  -> large cards
28  -> premium cards / sheets
32+ -> hero panels

Avoid inconsistent radius values across similar components.

Button Rules

Primary actions should be obvious.

Use Material buttons when possible:

FilledButton
ElevatedButton
OutlinedButton
TextButton
IconButton

Primary button style:

height 52-56
radius 16-20
strong primary color
clear white/onPrimary text
loading state eventually
disabled state clearly visible

Example theme direction:

filledButtonTheme: FilledButtonThemeData(
  style: FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    textStyle: const TextStyle(
      fontWeight: FontWeight.w700,
    ),
  ),
),

Avoid making the main submit action transparent or weak.

Input Rules

Text fields should feel mobile-native.

Use:

TextFormField
InputDecorationTheme
clear labels/hints
correct keyboard type
password visibility toggle
validation message support
comfortable height
rounded border
filled background

Recommended:

radius 16-20
content padding 16 horizontal
input height around 52-58
readable label and hint
focused border visible

Example theme direction:

inputDecorationTheme: InputDecorationTheme(
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(
      color: Colors.black.withValues(alpha: 0.06),
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(
      color: AppTheme.primaryColor,
      width: 1.4,
    ),
  ),
),
Card Rules

Cards should organize information clearly.

Use:

enough padding
readable hierarchy
clear title
subtle border/shadow
consistent radius
theme surface colors

For repeated list cards, prefer solid soft cards over heavy glass blur.

Good task card:

title
status chip
assignee
deadline
priority
short action

Avoid overcrowding cards.

Chip and Badge Rules

Use chips for:

status
priority
category
role
filters

Status colors:

success/completed -> green tone
pending/waiting -> amber tone
failed/overdue -> red tone
active/in progress -> blue/violet tone
neutral/draft -> gray tone

Chips should be readable and not too bright.

AppBar Rules

Mobile app bars should be clean.

Use:

transparent or surface background
clear title
optional back button
optional action icons
no crowded toolbar

For dashboard screens, a custom header may be better than default AppBar.

Bottom Navigation Rules

Use bottom navigation for high-level app areas if role flow requires it.

Possible role-aware navigation:

Dashboard
Tasks
Files
Profile

Admin/owner complex navigation may need drawer or menu screen.

Do not copy desktop sidebar directly into mobile.

Bottom Sheet Rules

Use bottom sheets for:

filters
task actions
pickers
quick forms
confirmation choices

Bottom sheets should have:

top radius 24-28
safe bottom padding
clear title
enough spacing
obvious actions
Dialog Rules

Use dialogs for:

destructive confirmation
critical warning
short decision

Avoid using dialogs for long forms. Use bottom sheets or full screens.

Loading, Empty, Error States

Every real data screen should eventually have:

loading state
empty state
error state
retry action
unauthorized/session expired handling

Do not leave blank screens.

Create reusable shared widgets later:

GuvenLoader
GuvenEmptyState
GuvenErrorState
Shared Widget Rules

Create shared widgets when a pattern appears more than once.

Possible shared widgets:

GuvenPrimaryButton
GuvenTextField
GuvenCard
GuvenGlassCard
GuvenStatusChip
GuvenSectionHeader
GuvenAppBar
GuvenLoader

Do not create shared widgets too early if used only once.

Implementation Rules

When implementing Material 3 UI:

Use Theme.of(context).
Use ColorScheme.
Keep styling consistent.
Prefer reusable theme configuration.
Use const where possible.
Avoid large repeated inline decoration blocks.
Do not add dependencies without approval.
Do not modify unrelated files.
Keep mobile usability more important than visual decoration.
App Theme Improvement Checklist

Before finalizing theme changes, check:

Does MaterialApp use the theme?
Are colors semantic?
Are text styles readable?
Are buttons consistent?
Are inputs consistent?
Are cards consistent?
Is background calm?
Is contrast acceptable?
Is the design mobile-friendly?
Did we avoid over-engineering?
Strict Constraints

Never:

Add UI packages without approval.
Replace Flutter Material system unnecessarily.
Hardcode a new color system inside every screen.
Use inconsistent radius/shadow values.
Sacrifice usability for decoration.
Modify backend/API logic during theme work.
Rewrite the whole project unless explicitly requested.
