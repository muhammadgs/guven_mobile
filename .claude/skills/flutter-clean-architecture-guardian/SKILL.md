# Flutter Clean Architecture Guardian

## Purpose

Use this skill when creating, reviewing, refactoring, or organizing Flutter project structure, feature folders, shared widgets, app-level configuration, API layers, storage layers, models, services, repositories, and state management boundaries.

This project is the native Flutter mobile application for the Güvən Finans platform. The project is expected to grow into a real production-style app with authentication, role-based routing, owner/worker/admin dashboards, task management, file handling, notifications, and backend API integration.

## Main Responsibility

Protect the codebase from becoming messy.

Always prioritize:
- clear folder structure
- focused files
- small widgets/classes
- separation of concerns
- maintainability
- predictable naming
- scalable feature organization
- minimal unrelated changes
- no over-engineering too early

## Project Architecture Direction

Target structure:

```txt
lib
├── main.dart
└── src
    ├── app
    │   ├── guven_app.dart
    │   ├── app_theme.dart
    │   ├── app_routes.dart
    │   └── app_router.dart
    │
    ├── core
    │   ├── constants
    │   ├── network
    │   ├── storage
    │   ├── errors
    │   ├── utils
    │   └── config
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
        ├── layout
        ├── theme
        ├── extensions
        └── models

Do not create every folder immediately unless needed. Empty folders are not tracked by Git unless .gitkeep is added.

Layer Rules
App Layer

Use lib/src/app for:

root app widget
MaterialApp
theme
routing
global navigation setup
app-level dependency initialization later

Examples:

guven_app.dart
app_theme.dart
app_routes.dart
app_router.dart

Do not put feature UI or API calls directly in app layer.

Core Layer

Use lib/src/core for technical foundations used across the app.

Examples:

API client
Dio/http setup
secure storage
token manager
constants
environment config
error classes
result types
validators
date formatting helpers
file helpers
permission helpers

Do not put screen-specific widgets in core.

Features Layer

Use lib/src/features/<feature> for business modules.

Recommended feature structure:

features/auth
├── data
│   ├── models
│   ├── services
│   └── repositories
├── domain
│   └── entities
└── presentation
    ├── login_screen.dart
    └── widgets

For early-stage work, do not force full clean architecture if the feature is simple. Start with:

features/auth/presentation

Then add data, domain, or state folders when needed.

Shared Layer

Use lib/src/shared for reusable UI and helpers that are not tied to one feature.

Examples:

GuvenPrimaryButton
GuvenTextField
GuvenCard
GuvenStatusChip
GuvenLoader
GuvenEmptyState
GuvenAppBar

Only move something to shared when it is reused or clearly intended to be reused.

File Naming Rules

Use snake_case for file names:

login_screen.dart
task_card.dart
auth_service.dart
user_model.dart
app_routes.dart

Use PascalCase for Dart classes:

LoginScreen
TaskCard
AuthService
UserModel
AppRoutes

Avoid vague names:

helper.dart
common.dart
manager.dart without context
screen.dart
page.dart
utils.dart with unrelated functions

Prefer specific names:

auth_token_storage.dart
task_status_chip.dart
owner_dashboard_screen.dart
date_formatter.dart
Import Rules

Use clean relative imports inside lib/src when appropriate.

Avoid messy long chains when possible.

Do not create circular imports.

Do not import UI files into core/network/storage layers.

Core can be used by features.
Features should not depend heavily on each other.
Shared can be used by features.
App can wire everything together.

UI Separation Rules

Do not place an entire complex screen in one huge build method.

For small screens:

one screen file is fine

For medium/large screens:

split into local private widgets
or create widgets/ folder inside the feature

Example:

features/tasks/presentation/task_list_screen.dart
features/tasks/presentation/widgets/task_card.dart
features/tasks/presentation/widgets/task_filter_bar.dart
features/tasks/presentation/widgets/task_empty_state.dart
API Separation Rules

Never put raw HTTP calls directly in widgets.

Bad:

onPressed: () async {
  final response = await http.post(...);
}

Better:

UI widget
  -> controller/state
  -> repository/service
  -> API client

Early simple version:

LoginScreen
  -> AuthService.login()
  -> ApiClient.post()

Later scalable version:

LoginScreen
  -> AuthController/AuthNotifier
  -> AuthRepository
  -> AuthRemoteDataSource/AuthService
  -> ApiClient
State Management Rules

Do not introduce state management packages without approval.

Start simple:

StatefulWidget
ValueNotifier
local state

When app grows, consider with approval:

Riverpod
Bloc
Provider
Cubit
GetIt

Do not add any of these automatically.

Model Rules

Use models for API response/request structures.

Model files should be specific:

login_request.dart
login_response.dart
user_model.dart
task_model.dart
company_model.dart

Do not create one giant models.dart file with many unrelated classes.

Use fromJson and toJson when needed.

Do not invent backend fields unless known from the API or user-provided source.

Constants Rules

Use constants for repeated values.

Possible files:

core/constants/app_constants.dart
core/constants/storage_keys.dart
core/constants/api_endpoints.dart

Avoid scattering strings like:

token key
base URL
route names
role names

Role names should be centralized when role routing begins.

Error Handling Rules

Eventually create a consistent error approach.

Possible future structure:

core/errors/app_exception.dart
core/errors/failure.dart

For now:

do not swallow errors silently
show useful UI errors
keep debug logs controlled
avoid exposing raw backend errors directly to users
Auth Architecture Direction

Expected auth flow:

SplashScreen
  -> check token
  -> /login if no token
  -> /dashboard if token valid
  -> role-based dashboard

Roles may include:

owner
worker
admin

Token should eventually be stored securely, not plain localStorage like the web app.

Use mobile secure storage later with approval.

Routing Rules

Early stage:

named routes are acceptable

Later:

use go_router or another router only with approval

Routes should be centralized:

AppRoutes
later AppRouter

Do not navigate using hardcoded route strings throughout the app.

Prefer:

Navigator.of(context).pushNamed(AppRoutes.login);

over:

Navigator.of(context).pushNamed('/login');
Dependency Rules

Do not add packages without explicit approval.

When a package is needed, explain:

why it is needed
what alternatives exist
why built-in Flutter is not enough
package name
where it will be used

Likely future packages, only with approval:

dio
flutter_secure_storage
go_router
image_picker
file_picker
permission_handler
intl
Git Safety Rules

Before making changes:

understand the request
identify exact files to change
avoid unrelated formatting
do not delete files unless asked
do not rename files unless asked
do not run destructive commands

Never run:

git reset --hard
git clean -fd
force push
delete branches
remove project folders
mass refactor without explicit approval

When done:

summarize changed files
mention how to test
recommend running flutter analyze
Implementation Workflow

When asked to implement:

Restate the target briefly.
Identify files to modify/create.
Keep changes minimal and focused.
Preserve existing architecture.
Do not add packages unless approved.
Write readable Flutter/Dart code.
Run or suggest:
flutter analyze
flutter run
Summarize exactly what changed.
Review Workflow

When asked to review:

Inspect relevant files.
Identify architecture issues.
Separate high/medium/low priority.
Suggest improvements.
Do not edit unless explicitly requested.
Refactor Rules

Only refactor when asked.

Refactor should:

preserve behavior
improve readability
reduce duplication
keep file structure clear
not mix with new feature work unless asked

Avoid massive refactors during active feature implementation.

Flutter Quality Checklist

Before finalizing code:

Does the project still compile?
Are imports valid?
Are files in correct folders?
Are widgets small enough?
Is API logic outside UI?
Are route names centralized?
Are repeated UI patterns shared only when appropriate?
Is there unnecessary package usage?
Are changes focused?
Strict Constraints

Never:

Add dependencies without approval.
Modify unrelated files.
Mix UI, API, storage, and routing all in one file.
Create giant screens with hundreds of lines unless temporary and approved.
Invent backend fields or business rules.
Use WebView unless explicitly requested.
Rewrite the whole project architecture without approval.
Run destructive Git commands.
Commit changes unless explicitly asked.
