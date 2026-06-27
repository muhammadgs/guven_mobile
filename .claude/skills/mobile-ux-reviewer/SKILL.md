# Mobile UX Reviewer

## Purpose

Use this skill when reviewing mobile user experience, screen usability, navigation flow, form behavior, dashboard clarity, task management UX, and overall mobile interaction quality.

This project is the native Flutter mobile application for the Güvən Finans platform. The original platform is web-based, but the mobile app must feel native, simple, fast, and comfortable on Android and iOS devices.

## Main Responsibility

Review mobile UI and UX with a senior product designer and mobile UX engineer mindset.

Focus on:
- usability
- clarity
- touch comfort
- visual hierarchy
- navigation simplicity
- form ergonomics
- mobile responsiveness
- accessibility basics
- role-based user journeys
- professional finance/business app feel

## Review Philosophy

Do not only ask: "Does it look nice?"

Ask:
- Can the user understand what to do in 3 seconds?
- Is the primary action obvious?
- Is the screen comfortable on a real phone?
- Are tap targets large enough?
- Is the information hierarchy clear?
- Is anything too web-like?
- Is there too much content on one screen?
- Does the screen work with keyboard open?
- Does the screen work on iPhone 11 size?
- Does the screen work on small Android phones?
- Is the flow suitable for owner, worker, and admin roles?

## Core Mobile UX Rules

### 1. Primary Action Clarity

Every screen should have one clear main action.

Examples:
- Login screen -> "Daxil ol"
- Create task screen -> "Tapşırıq yarat"
- Task details screen -> "Statusu yenilə" or "Cavab yaz"
- Dashboard -> "Yeni tapşırıq" or "Tapşırıqlara bax"

Avoid multiple equally loud buttons competing for attention.

### 2. Touch Target Size

Interactive elements should generally be at least:

```txt
48 x 48 px

Buttons should usually be:

height: 48-56 px

Inputs should usually be:

height: 52-60 px

Tiny icon-only buttons must still have comfortable padding.

3. Spacing Comfort

Use consistent spacing:

4   -> tiny detail spacing
8   -> compact spacing
12  -> small internal spacing
16  -> standard element spacing
20  -> medium group spacing
24  -> screen padding / section spacing
32  -> large section break
40+ -> hero/empty space

Avoid random spacing values unless required by the design.

4. Mobile First Layout

Do not copy desktop layout directly.

Convert:

tables into cards
sidebars into drawer/bottom navigation
dense forms into grouped vertical sections
multi-column dashboards into scrollable sections
hover interactions into tap interactions
desktop dropdown-heavy UI into mobile-friendly pickers/bottom sheets
5. Readability

Text should be readable on phone screens.

Recommended approximate sizes:

large hero title: 28-34
screen title: 22-28
section title: 17-20
body text: 14-16
helper text: 12-14
badges: 11-13

Avoid very small text except for secondary metadata.

6. Safe Area Awareness

All screens must respect:

status bar
camera cutout / notch
bottom gesture area
keyboard area

Use:

SafeArea
scrollable forms
bottom padding
keyboard-aware layouts
7. Keyboard Behavior

For forms:

Screen should not overflow when keyboard opens.
Important submit button should remain reachable.
Use correct keyboard type.
Password fields should have visibility toggle.
Validation errors should be visible near the field.
8. Error and Empty States

Every real app screen should eventually handle:

loading
empty data
error
no internet
unauthorized/session expired
retry action

Do not leave users on blank screens.

9. Role-Based UX

This app will have roles:

owner
worker
admin

Review screens according to role.

Owner likely needs:

overview
employees
companies
partners
tasks
reports
invitations

Worker likely needs:

assigned tasks
task updates
documents
companies/partners linked to work

Admin likely needs:

users
services
reports
system-level management

Do not show all admin/owner complexity to worker users.

10. Finance/Business App Tone

The app should feel:

trustworthy
clean
calm
structured
modern
professional
fast

Avoid:

childish visuals
overly playful animations
too many bright colors
messy shadows
crowded cards
inconsistent typography
Screen Review Checklist

When reviewing a screen, evaluate:

Purpose:
- What is this screen for?
- Is the purpose obvious?

Hierarchy:
- What is the first thing the user sees?
- What is the main action?
- What is secondary?

Layout:
- Is there enough breathing room?
- Is it scrollable if needed?
- Does it avoid horizontal overflow?

Touch:
- Are buttons large enough?
- Are icons easy to tap?
- Are list items comfortable?

Forms:
- Are labels clear?
- Are required fields obvious?
- Are errors understandable?
- Does keyboard behavior work?

Navigation:
- Can user go back?
- Is the current section clear?
- Are too many actions hidden?

Accessibility:
- Is contrast acceptable?
- Is text readable?
- Are icons supported by labels where needed?

Performance:
- Is the screen too visually heavy?
- Are there too many shadows/blurs?
- Is list rendering efficient?

Consistency:
- Does it match the app theme?
- Are radii, shadows, spacing, buttons consistent?
Login UX Rules

A good login screen should have:

clear brand identity
email/phone input
password input
password visibility toggle
forgot password link
clear login button
optional register link
clear validation errors
loading state on submit

Avoid:

too many links
hidden validation
tiny fields
hard-to-tap buttons
unclear error messages
Dashboard UX Rules

A good dashboard should have:

greeting or context header
role-aware quick actions
key summary cards
recent tasks or important updates
clear navigation
limited information density

Avoid:

web-style full tables
too many cards at once
huge sidebar copied from desktop
every metric competing visually
Task Management UX Rules

Task screens should prioritize:

task title
status
deadline
assignee
priority
latest update
attachments
main action

Task lists should use:

cards
status chips
filters
search
clear empty states
quick actions

Create task form should use:

grouped sections
clear labels
dropdowns/bottom sheets for selection
attachment picker
submit button
draft/loading/error handling eventually
Review Output Format

When reviewing UI, respond with:

UX Summary:
Short overall assessment.

Strong parts:
- ...

Issues:
- ...

Recommended improvements:
- ...

Priority:
High / Medium / Low

If implementation is requested, first explain the UX reasoning, then modify only the necessary files.

Severity Levels

Use these levels:

High:
Blocks usage, causes confusion, bad mobile behavior, impossible to tap, overflow, broken flow.

Medium:
Usability issue, weak hierarchy, too much density, inconsistent component.

Low:
Visual polish, small spacing, minor copy, shadow/radius tuning.
Strict Constraints

Never:

Make UX more complex than necessary.
Add features not requested.
Invent business rules.
Hide important actions behind unclear UI.
Copy desktop UX without adapting it.
Add dependencies without approval.
Modify unrelated files during review.
Start coding if the user only asked for review.
