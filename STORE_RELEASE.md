# The Garden: Store Release Guide

This is the checklist for getting **The Garden** (UCity The Church) into the Apple App Store and Google Play.
The branch `tab/store-ready` has the code changes the stores require. The **Only you can do this** steps are
things that need your accounts, so nobody else can do them for you.

| | iOS | Android |
|---|---|---|
| App name | The Garden | The Garden |
| Bundle / application ID | `com.shymin.thegardenbyucity` | `com.shymin.thegardenbyucity` |
| Version | `1.0.0` (build number set by Codemagic) | same |
| Build system | Codemagic workflow `ios-release` | Codemagic workflow `android-release` |

---

## 0. Before either store (about 20 minutes, Only you can do this)

### 0.1 Lock down the database (do this first, today)
Right now the Firestore database is in open "test mode". Anyone on the internet can read every member's name and
email, and change or delete anything.

1. Open https://console.firebase.google.com → project **ucity-garden** → **Firestore Database** → **Rules**.
2. Replace everything with the contents of `ucityapp/firestore.rules` from this branch and click **Publish**.
3. (Optional) Make yourself a moderator: **Firestore Database** → **Data** → **Start collection** `admins` →
   Document ID = your user UID (from **Authentication** → **Users**) → add any field, e.g. `name: "Shy"` → Save.
   Admins can delete any post and read reports.

> Old app builds (before this branch) save prayers without a `creatorId`, so they can't post prayers once the new
> rules are live. Ship the new build to testers right after publishing the rules.

### 0.2 Make chat secure (recommended before public release)
Today the app signs in to Stream Chat with "development tokens". That only works because **Disable Auth Checks**
is turned on in the Stream dashboard, and it means anyone with the app's key could pose as any member in chat.

The fix is Stream's official Firebase extension. It needs Firebase's **Blaze (pay-as-you-go)** plan, which means
putting a card on file. A church-sized app stays inside the free allowance.

1. Firebase console → ⚙ **Usage and billing** → **Modify plan** → **Blaze**. Set a budget alert (e.g. $5).
2. Install the extension **Authenticate with Stream Chat** (https://extensions.dev/extensions/stream/auth-chat).
   Region `us-central1`. It asks for your Stream **API key** (`srzvkmn6xvrj`) and **API secret** (Stream
   dashboard → your app → **Overview**).
3. Stream dashboard → **Chat** → **Overview** → turn **Disable Auth Checks** **OFF**.
4. In `codemagic.yaml`, add `--dart-define=STREAM_DEV_TOKENS=false` to both `flutter build` commands.

The app already calls the extension's `ext-auth-chat-getStreamUserToken` function first and only falls back to
development tokens when the extension isn't installed, so no other code change is needed. The extension also
deletes a member's chat account when they delete their app account.

If you skip this for now, the app still works. Just do it before you share the app widely.

### 0.3 Publish the privacy policy (both stores require a public URL)
The policy is in the app (Profile → Privacy Policy). The stores also need it at a web address.
`docs/privacy-policy.html` in this branch is a ready-to-publish page. Any of these works:
- GitHub Pages: repo **Settings** → **Pages** → Source **Deploy from a branch** → `main` / `/docs` (after merging).
  The URL will be `https://shy-min.github.io/ucity_garden/privacy-policy.html`.
- The church website: paste the text onto a page.

Check the contact email (currently `yminor13@gmail.com`) in `ucityapp/lib/theme.dart` (`AppConfig.supportEmail`)
and in the HTML. Change it if you'd rather use a church address.

### 0.4 Merge the branch
Open https://github.com/shy-min/ucity_garden/compare/main...tab/store-ready → **Create pull request** →
**Merge**. Codemagic builds from the branch you pick, so you can also build `tab/store-ready` directly.

### 0.5 A reviewer test account
Apple and Google both need a login to review the app.
Create one in the app (e.g. `appreview@<your domain>` with a simple password), add a couple of sample events,
prayers and needs, and keep the email and password for steps 1.4 and 2.5.

---

## 1. Apple App Store

You already have: an Apple Developer membership (the bundle ID is registered), and Codemagic set up with the
`CM_Key` App Store Connect API key. Each successful `ios-release` build uploads to TestFlight on its own.

### 1.1 Create the app record (once)
App Store Connect → **Apps** → **+** → **New App**
- Platform **iOS**, Name **The Garden** (if it's taken, try "The Garden – UCity"), Primary language English (U.S.)
- Bundle ID **com.shymin.thegardenbyucity**, SKU `thegarden-ucity`, User Access **Full Access**

### 1.2 Build and upload
Codemagic → ucity_garden → **Start new build** → branch `tab/store-ready` (or `main` after merging) → workflow
**iOS Release**. About 20 to 30 minutes. The build shows up under App Store Connect → **TestFlight**. Install it on
your iPhone with the TestFlight app and walk through sign-up, events, prayers, needs, chat, report/block and
delete account.

### 1.3 Store listing (App Store Connect → your app → **1.0 Prepare for Submission**)
- **Screenshots**: iPhone 6.9" (1320 × 2868) is required. Take them on an iPhone 15/16 Pro Max (or Plus) with
  the TestFlight build: Events, Prayer Wall, Needs & Offers, Chat, Profile. The `ucity-*.png` previews show the screens.
- **Promotional text / Description**, e.g.:
  > The Garden is the community app for UCity The Church. See upcoming events and RSVP, sign up to volunteer,
  > share prayer requests and let others know you're praying, post needs and offers to help one another, and
  > message other members.
- **Keywords**: `church,community,prayer,events,volunteer,ucity,bible,fellowship`
- **Support URL**: the church website. **Marketing URL**: optional.
- **Category**: Lifestyle (secondary: Social Networking). **Age rating**: answer the questionnaire. Choose
  "Yes" for unrestricted user-generated content / messaging. That gives 12+ or 17+, which is fine.
- **App Privacy** → **Privacy Policy URL** from 0.3. Data types: **Contact Info → Name, Email Address**;
  **User Content → Messages, Photos or Videos, Other User Content**; **Identifiers → User ID**. For each one:
  *Linked to user: Yes*, *Used for tracking: No*, purpose *App Functionality*.
- **Copyright**: `2026 UCity The Church`.

### 1.4 App Review information
- **Sign-in required**: Yes. Enter the reviewer account from 0.5.
- **Notes** (paste):
  > The Garden is a private community app for members of UCity The Church. Members can report any post or
  > conversation (••• menu) and block other members. Reports are reviewed within 24 hours. Users must accept
  > the Community Guidelines (zero tolerance for objectionable content) at sign-up. Accounts can be deleted
  > in-app: Profile → Delete Account.

### 1.5 Submit
Under **Build**, pick the TestFlight build → **Add for Review** → **Submit**. Review usually takes 1 to 3 days.
Export compliance is already answered in Info.plist (`ITSAppUsesNonExemptEncryption = NO`).

---

## 2. Google Play

### 2.1 Developer account (Only you can do this)
https://play.google.com/console/signup. One-time **$25**, identity verification, 1 to 2 days. As an
**Organization** account (the church) you can publish to production right away. A **Personal** account first
needs a **closed test with at least 12 testers for 14 days** before it can apply for production. The church
community is a good group for that.

### 2.2 Signing
Codemagic already has an Android keystore named **UCityY** (referenced in `codemagic.yaml`). That keystore is
your **upload key**. Back it up somewhere safe (Codemagic → Teams → Code signing identities → download). Losing it
means asking Google to reset the upload key. When you create the app, keep **Play App Signing** on (the default).

### 2.3 Build the AAB
Codemagic → **Start new build** → workflow **Android Release**. The artifact is
`build/app/outputs/bundle/release/app-release.aab`. Codemagic sets the build number, so each upload gets a
new `versionCode` on its own.

### 2.4 Create the app (Play Console → **Create app**)
- App name **The Garden**, language English (US), **App**, **Free**. Accept the declarations.
- **Dashboard → Set up your app** tasks:
  - **Privacy policy**: URL from 0.3
  - **App access**: "All or some functionality is restricted" → add the reviewer account from 0.5
  - **Ads**: No ads
  - **Content rating**: questionnaire. Category *Social / Communication*. Answer **Yes** to "users can interact /
    exchange content" and "users can share info".
  - **Target audience**: 13+ (not designed for children)
  - **Data safety**: *Collects data*: Name, Email address, User IDs, Messages, Photos/videos, Other
    user-generated content. All **Collected**, **Not shared**, encrypted in transit, **users can request
    deletion** (in-app Profile → Delete Account, or email). Purpose: App functionality, Account management.
  - **Account deletion URL** (required for apps with accounts): the privacy policy URL works, because it explains
    how to delete in-app and by email.
  - **Government apps / Financial features / Health**: No
- **Store listing**: short description (80 chars), e.g. "Events, prayer, needs & chat for the UCity The Church
  family." Full description: the same as iOS. **App icon** 512×512 (`ucityapp/assets/icon/app_icon.png` scaled
  down). **Feature graphic** 1024×500. **Phone screenshots**: at least 2 (the `ucity-*.png` previews work).

### 2.5 Release
1. **Testing → Internal testing** → Create release → upload the `.aab` → add your own Gmail as a tester → roll
   out. Install from the opt-in link and test on a real Android phone.
2. Personal account: **Closed testing** with 12 or more testers for 14 days, then **Apply for production**.
   Organization account: go straight to step 3.
3. **Production** → Create release → same `.aab` → **Send for review**. The first review takes a few days.

---

## 3. After launch
- **Reports**: check Firestore → `reports` each day (or ask for a small moderator screen / email alert).
  Apple expects action within 24 hours.
- **Updates**: bump `version:` in `ucityapp/pubspec.yaml` (e.g. `1.0.1+1`) for user-visible versions. Codemagic
  supplies build numbers.
- **Icon**: the current icon is a clean placeholder (green flower on charcoal, matching the app). To use the church
  logo, replace `ucityapp/assets/icon/app_icon.png` (1024×1024, no transparency) and
  `app_icon_foreground.png`, then run `dart run flutter_launcher_icons` and
  `dart run flutter_native_splash:create`.

## 4. Local development
```bash
cd ucityapp
flutter pub get
flutter run                       # against the live Firebase project
# Fully local, against the Firebase emulators (no real data touched):
firebase emulators:start --only auth,firestore --project demo-ucity
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```
