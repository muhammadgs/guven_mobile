# guven_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Glass renderer trial

App surfaces use `liquid_glass_renderer` by default through the app-owned
`AppGlassSurface` adapter. The bottom navigation remains on
`flutter_liquid_glass_plus`, which uses the same renderer internally.

To run the previous `liquid_glass_easy` implementation without changing source
code:

```sh
flutter run --dart-define=GUVEN_GLASS_BACKEND=easy
```

Omitting the define, or setting it to `renderer`, selects the new renderer.
