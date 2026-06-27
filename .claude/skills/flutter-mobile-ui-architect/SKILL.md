# Flutter Mobile UI Architect

## Purpose

Use this skill when working on Flutter mobile UI, screen architecture, widget structure, responsive layouts, and feature-based Flutter code organization.

This project is the native Flutter mobile application for the Güvən Finans platform. The goal is to rebuild the existing web platform as a professional Android/iOS Flutter app, not as a simple WebView wrapper.

## Core Principles

Always think like a senior Flutter mobile architect.

Prefer:
- Native Flutter widgets over WebView
- Clean feature-based architecture
- Small reusable widgets
- Clear separation between screen, widgets, state, service, and model layers
- Mobile-first UX
- Responsive layouts
- Material 3 compatible UI
- SafeArea-aware screens
- Theme-driven styling
- Maintainable, readable Dart code

Avoid:
- Putting large screens entirely inside one file
- Hardcoding repeated colors, spacing, text styles, and shadows everywhere
- Mixing API logic directly inside UI widgets
- Copying HTML/CSS structure literally into Flutter
- Using WebView unless explicitly requested
- Creating unnecessary abstractions too early
- Modifying unrelated files
- Adding packages without explicit approval

## Project Architecture Direction

Use this structure as the target direction:

```txt
lib
├── main.dart
└── src
    ├── app
    │   ├── guven_app.dart
    │   ├── app_theme.dart
    │   └── app_routes.dart
    │
    ├── core
    │   ├── constants
    │   ├── network
    │   ├── storage
    │   ├── errors
    │   └── utils
    │
    ├── features
    │   ├── splash
    │   ├── auth
    │   ├── dashboard
    │   ├── tasks
    │   ├── owner
    │   ├── worker
    │   ├── admin
    │   ├── profile
    │   ├── files
    │   └── notifications
    │
    └── shared
        ├── widgets
        ├── theme
        ├── layout
        └── extensions
Screen Design Rules

When creating a new screen:

Put the main screen widget inside:
lib/src/features/<feature_name>/presentation/<screen_name>.dart
If the screen becomes large, split internal UI parts into:
lib/src/features/<feature_name>/presentation/widgets/
Do not create huge widget trees inside one build() method.
Use private helper widgets only when the part is very local and small.
Use reusable shared widgets when the same UI pattern appears in multiple features.

Good examples:

LoginScreen
SplashScreen
OwnerDashboardScreen
TaskListScreen
TaskCard
GuvenPrimaryButton
GuvenTextField

Bad examples:

BigPage
MainWidget
Screen1
DashboardEverything
Helper
Common
Widget Composition Rules

Prefer composition like this:

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: LoginView(),
      ),
    );
  }
}

Then split:

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LoginHeader(),
        LoginForm(),
        LoginActions(),
      ],
    );
  }
}

Use const wherever possible.

Responsive Layout Rules

Always design for real mobile screens.

Consider:

Small Android phones
iPhone 11 size
Tall phones
Keyboard open state
Safe areas
Bottom navigation area
Landscape not required unless explicitly requested

Use:

SafeArea
SingleChildScrollView for forms
LayoutBuilder when size decisions are needed
MediaQuery.sizeOf(context) for screen size
Padding and SizedBox for spacing
ConstrainedBox for max width when needed

For auth screens and forms:

SingleChildScrollView(
  padding: const EdgeInsets.all(24),
  child: ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: MediaQuery.sizeOf(context).height,
    ),
    child: ...
  ),
)

Avoid fixed full-screen heights unless necessary.

Styling Rules

Use theme-based styling:

final theme = Theme.of(context);
final colorScheme = theme.colorScheme;
final textTheme = theme.textTheme;

Prefer:

Text(
  'Title',
  style: theme.textTheme.headlineMedium?.copyWith(
    fontWeight: FontWeight.w800,
  ),
)

Avoid repeating raw TextStyle everywhere unless the style is local and unique.

Spacing Rules

Use consistent spacing:

4   → tiny
8   → small
12  → compact
16  → normal
20  → medium
24  → section
32  → large
40+ → hero spacing

Do not use random values like 17, 23, 37 unless there is a clear design reason.

Mobile Interaction Rules

For touch targets:

Buttons should usually be at least 48px high.
Inputs should usually be 52-58px high.
Important cards should have enough padding.
Avoid tiny clickable icons without accessible touch area.

For forms:

Use correct keyboard type.
Use password visibility toggle for password inputs.
Do not hide validation errors.
Keep login/register flows simple.
Performance Rules

Prefer:

const constructors
Small widgets
Lazy lists using ListView.builder
Avoid rebuilding large trees unnecessarily
Avoid heavy work inside build()

Avoid:

Complex calculations directly in build()
Large images without optimization
Nested scroll views unless necessary
Unbounded height errors
Flutter Code Quality Rules

Before finalizing code, mentally check:

Does it compile?
Are imports correct?
Are widgets named clearly?
Is the file in the correct feature folder?
Is the UI responsive?
Is there unnecessary duplication?
Are colors/styles theme-driven where possible?
Is the code easy for another Flutter developer to understand?
When Converting From Web Design

Do not copy HTML/CSS literally.

Instead translate:

HTML section      → Flutter widget section
CSS card          → Container/Card with BoxDecoration
CSS grid          → Column/ListView/GridView/Wrap
CSS flex row      → Row
CSS flex column   → Column
CSS button        → ElevatedButton/FilledButton/custom GuvenButton
CSS input         → TextFormField/custom GuvenTextField
CSS navbar        → AppBar/Drawer/BottomNavigationBar/custom shell

Keep the business meaning and visual hierarchy, but adapt it to native mobile UX.

Output Behavior

When asked to implement UI:

Briefly explain the intended file changes.
Modify only relevant files.
Keep changes focused.
Do not rewrite the whole app unless explicitly requested.
Do not add new dependencies without asking first.
After implementation, mention how to test it with flutter run.

When asked only to inspect:

Do not modify files.
Summarize understanding.
Wait for instruction.
