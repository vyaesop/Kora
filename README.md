# thread_clone_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Release APKs

Production APKs must be built with a real backend URL so they can reach your deployed API from other phones.

Example:

```bash
flutter build apk --release --dart-define=KORA_API_BASE_URL=https://your-backend.vercel.app
```

Android release builds now include `INTERNET` permission from the main manifest.


npm run dev:admin
