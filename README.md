# flutter_application_1

## Running on an Android phone

The default API address (`10.0.2.2`) is for the Android emulator. For a physical
phone, connect it and the computer running the backend to the same Wi-Fi
network, then run the app with the computer's local IP address:

```sh
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Replace `192.168.1.10` with the computer's actual local IP. Keep the backend
running on port `3000` and allow that port through the computer's firewall.
Requests time out after 15 seconds if the server cannot be reached. The Android
debug build permits local HTTP for development; use an HTTPS API URL for
release builds.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
