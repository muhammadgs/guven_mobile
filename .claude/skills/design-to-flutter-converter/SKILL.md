# Design To Flutter Converter

## Purpose

Use this skill when converting an existing website design, screenshot, HTML/CSS layout, or UI mockup into native Flutter mobile UI.

This project is the Flutter mobile version of the Güvən Finans web platform. The goal is to rebuild the web platform as a polished native Android/iOS app, not to copy the website directly or wrap it in WebView.

## Main Responsibility

When the user provides:
- a screenshot
- a website section
- an HTML/CSS layout
- an existing web page structure
- a Figma-like visual description
- a mobile redesign request

Convert it into:
- clean Flutter widgets
- mobile-first layout
- reusable components when appropriate
- responsive screens
- Material 3 compatible UI
- maintainable feature-based code

## Conversion Philosophy

Do not translate web code literally.

Translate the design intention.

The website is desktop/web-oriented. The mobile app must feel native, comfortable, touch-friendly, and professional.

Preserve:
- information hierarchy
- business meaning
- labels
- user actions
- data structure
- brand feeling
- important visual identity

Adapt:
- layout
- spacing
- navigation
- card structure
- input sizing
- touch target size
- scroll behavior
- mobile ergonomics

## HTML/CSS To Flutter Mapping

Use this mapping as a mental model:

```txt
HTML page             -> Flutter Screen
HTML section          -> Flutter section widget
div container         -> Container / Padding / DecoratedBox
CSS flex column       -> Column
CSS flex row          -> Row
CSS grid              -> GridView / Wrap / SliverGrid
CSS card              -> Container / Card with BoxDecoration
CSS button            -> FilledButton / ElevatedButton / custom button
CSS input             -> TextFormField / custom GuvenTextField
CSS label             -> Text / InputDecoration label
CSS navbar            -> AppBar / Drawer / BottomNavigationBar / custom shell
CSS sidebar           -> Drawer / NavigationRail / custom adaptive menu
CSS modal             -> Dialog / BottomSheet
CSS table             -> ListView of cards on mobile
CSS box-shadow        -> BoxShadow
CSS border-radius     -> BorderRadius.circular(...)
CSS backdrop blur     -> ClipRRect + BackdropFilter
CSS sticky header     -> SliverAppBar / pinned header
Mobile Adaptation Rules

Desktop tables should usually become mobile cards.

Example:

Web table:
Task name | Worker | Deadline | Status | Actions

Mobile:
TaskCard
- task title
- status badge
- worker name
- deadline row
- primary action
- overflow menu

Desktop sidebars should become:

Drawer
bottom navigation
role-based dashboard shell
expandable menu

Desktop multi-column forms should become:

single-column forms
grouped sections
collapsible advanced sections if needed

Desktop large dashboards should become:

summary cards
horizontal metric cards
vertical sections
filtered lists
bottom sheets for actions
Screenshot Analysis Procedure

When analyzing a screenshot, always identify:

Screen purpose
Main user action
Secondary actions
Information hierarchy
Layout regions
Repeated components
Spacing pattern
Colors and visual style
Mobile constraints
Flutter widget breakdown

Before coding, produce a clear component plan if the user asks for planning.

Example output structure:

Screen: Task Assignment

Main widgets:
- TaskAssignmentScreen
- TaskAssignmentHeader
- TaskFormSection
- AssigneeSelector
- PrioritySelector
- AttachmentPicker
- SubmitTaskButton

Shared widgets:
- GuvenTextField
- GuvenDropdown
- GuvenPrimaryButton
- GuvenGlassCard
Flutter Output Rules

When implementing, prefer:

lib/src/features/<feature>/presentation/<screen>.dart
lib/src/features/<feature>/presentation/widgets/<widget>.dart
lib/src/shared/widgets/<shared_widget>.dart

Use shared widgets only when the component is likely to be reused.

If the UI is one-off, keep it inside the feature.

Design Quality Rules

Every converted design should respect:

clear visual hierarchy
strong spacing rhythm
readable font sizes
touch-friendly controls
accessible contrast
comfortable mobile scrolling
consistent radius
consistent shadows
predictable navigation
no overcrowding
no desktop-style tiny controls
Flutter Layout Rules

Use:

SafeArea
SingleChildScrollView
Padding
Column
Row
Expanded
Flexible
ConstrainedBox
LayoutBuilder
ListView.builder
CustomScrollView
SliverAppBar

Avoid:

fixed absolute positioning unless necessary
large hardcoded heights
putting everything in one Stack
desktop table layouts on phones
tiny buttons
horizontal overflow
unbounded nested scroll errors
Design System Rules

Prefer extracting repeated values later into:

AppSpacing
AppRadius
AppColors
AppTextStyles
AppShadows

But do not over-engineer too early.

For now, use theme where possible:

final theme = Theme.of(context);
final colors = theme.colorScheme;
final textTheme = theme.textTheme;
Glass / Soft UI Translation

When the user asks for Apple-style glass, soft modern UI, or premium dashboard design:

Use carefully:

translucent background
soft border
blur
subtle shadow
high radius
light gradients
clean spacing

Flutter pattern:

ClipRRect(
  borderRadius: BorderRadius.circular(24),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ...
    ),
  ),
)

Use glass only where it improves the UI. Do not make every element glass.

Forms Conversion Rules

For web forms:

Convert labels and inputs into native mobile form layout.

Good mobile form:

label or hint is clear
input is large enough
validation message is visible
keyboard type is correct
password fields have visibility toggle
submit button is obvious
form scrolls when keyboard opens

Avoid:

too many fields on one screen without grouping
tiny dropdowns
web-like dense spacing
hidden required fields
Dashboard Conversion Rules

For dashboard pages:

Prefer:

top greeting/header
summary metric cards
quick actions
recent tasks
status filters
bottom navigation or drawer
role-based layout

Avoid:

copying desktop dashboard layout directly
huge tables
small sidebar links
too many buttons visible at once
Task Module Conversion Rules

The Güvən platform has a task system.

When converting task UI:

Use mobile-friendly patterns:

task cards
status chips
priority badges
assignee avatars/initials
deadline rows
attachments as compact chips
bottom sheet for actions
filters as chips or segmented controls
create task as multi-section form
Output Behavior

When asked to convert a design:

First understand the visual and business purpose.
Identify the target Flutter screen and folder.
Explain the component breakdown briefly.
Implement only the requested screen/section.
Keep changes focused.
Do not modify unrelated files.
Do not add packages without approval.
After implementation, explain how to run/test.

When asked only to analyze a design:

Do not write code.
Describe how it should become Flutter UI.
Wait for instruction.
Strict Constraints

Never:

Use WebView unless explicitly requested.
Add dependencies without user approval.
Rewrite the entire project for one screen.
Destroy existing architecture.
Mix backend/API logic into UI widgets.
Hardcode fake backend behavior as if real.
Invent business rules not present in the source.
