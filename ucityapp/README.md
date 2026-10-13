# The Garden (ucityapp)

The community app for **UCity The Church**, built with Flutter. Members can:

- **Events**: see the church calendar, RSVP, and sign up for volunteer tasks
- **Prayer Wall**: share prayer requests and tap "Praying"
- **Needs & Offers**: ask for help or offer it, and message the poster
- **Chat**: 1:1 messaging (Stream Chat)
- **Profile**: upcoming RSVPs, blocked members, guidelines, privacy policy, delete account

Backend: Firebase Auth + Cloud Firestore (project `ucity-garden`), Stream Chat for messaging.

## Layout
```
lib/
  main.dart                 app, auth gate, tab bar
  theme.dart                colors, AppConfig (support email, Stream key, flags)
  services/                 chat connection, moderation (report/block), user profile
  screens/                  auth, events, prayer wall, needs board, chat, profile, legal
firestore.rules             database security rules (deploy these!)
assets/icon/                app icon sources
```

## Run
```bash
flutter pub get
flutter run
```
Against local Firebase emulators (no real data touched):
```bash
firebase emulators:start --only auth,firestore --project ucity-garden
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

## Release
See [`../STORE_RELEASE.md`](../STORE_RELEASE.md). Builds run on Codemagic (`../codemagic.yaml`).
