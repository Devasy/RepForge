# Google Play Store Release & Build Guide

This guide walks through building, signing, and uploading the **Android App Bundle (.aab)** for **RepForge** to Google Play Console.

---

## 1. Prerequisites

1. **Google Play Developer Account**: Registered at [play.google.com/console](https://play.google.com/console).
2. **Release Keystore**: An upload keystore (or the existing release keystore used for RepForge).
3. **Flutter Environment**: Flutter 3.44+ and Java 17.

---

## 2. Keystore & Signing Configuration

RepForge's `workout-logger/android/app/build.gradle.kts` supports signing via either **environment variables** or a **`key.properties` file**.

### Option A: Using `key.properties` (Recommended for Local Builds)

1. Create a file named `key.properties` inside `workout-logger/android/`:
   ```properties
   storeFile=C:\\path\\to\\your\\release-keystore.jks
   storePassword=your_keystore_password
   keyAlias=your_key_alias
   keyPassword=your_key_password
   ```
   *(Note: `key.properties` and `*.jks` are already included in `.gitignore` so your secrets will never be committed).*

### Option B: Generating a New Upload Keystore (If you don't already have one)
If you need to generate a new key for Google Play upload:
```bash
keytool -genkey -v -keystore repforge-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias repforge-upload
```

---

## 3. Building the Android App Bundle (.aab)

Google Play requires the **Android App Bundle (.aab)** format instead of APKs.

1. Open a terminal in the `workout-logger` directory:
   ```bash
   cd workout-logger
   ```

2. Ensure dependencies are resolved:
   ```bash
   flutter pub get
   ```

3. Build the release App Bundle:
   ```bash
   flutter build appbundle --release
   ```

4. The resulting signed bundle will be located at:
   ```text
   workout-logger/build/app/outputs/bundle/release/app-release.aab
   ```

---

## 4. Play App Signing

When you create your application in the Google Play Console:
1. Google Play automatically enables **Play App Signing**.
2. When you upload your first `.aab`, Google registers your keystore as the **Upload Key**.
3. Google Play strips the upload signature and re-signs the distribution APKs with your master Google Play Signing Key.
4. *Recommendation:* Make a safe offline backup of your `.jks` file and passwords.

---

## 5. Releasing on Google Play Console

### Step 1: Create the App
1. Go to [Google Play Console](https://play.google.com/console).
2. Click **Create app**.
3. Fill in:
   - **App name:** `RepForge: Workout & Gym Log` (or `RepForge`)
   - **Default language:** English (United States) - en-US
   - **App or game:** App
   - **Free or paid:** Free
   - Accept the Developer Program Policies and US export laws.

### Step 2: Complete "Set up your app" Tasks
In the Dashboard, complete all tasks outlined in [PLAY_STORE_METADATA.md](file:///c:/Users/Devasy/OneDrive/Desktop/Workout-logger/docs/PLAY_STORE_METADATA.md):
- [x] Set privacy policy URL
- [x] App access (No restricted credentials)
- [x] Ads (No ads)
- [x] Content rating (IARC questionnaire &rarr; PEGI 3 / Everyone)
- [x] Target audience (18+)
- [x] News apps (No)
- [x] COVID-19 apps (No)
- [x] Data safety questionnaire
- [x] Health Connect declaration form
- [x] Government apps (No)
- [x] Financial features (No)

### Step 3: Main Store Listing
Navigate to **Store presence &rarr; Main store listing**:
1. Copy details from [PLAY_STORE_METADATA.md](file:///c:/Users/Devasy/OneDrive/Desktop/Workout-logger/docs/PLAY_STORE_METADATA.md):
   - **App name:** `RepForge: Workout & Gym Log`
   - **Short description:** `Workout logger with AI coaching, analytics & Health Connect integration`
   - **Full description:** Paste full description from `PLAY_STORE_METADATA.md`.
2. Upload Graphics:
   - **App Icon:** `fastlane/metadata/android/en-US/images/icon.png` (512x512)
   - **Feature Graphic:** `fastlane/metadata/android/en-US/images/featureGraphic.png` (1024x500)
   - **Phone Screenshots:** Upload screenshots from `fastlane/metadata/android/en-US/images/phoneScreenshots/` (ordered 1 to 8).

### Step 4: Release Tracks

#### Track 1: Internal Testing (Fastest Verification)
- Go to **Testing &rarr; Internal testing**.
- Click **Create new release**.
- Upload `workout-logger/build/app/outputs/bundle/release/app-release.aab`.
- Add release notes from `fastlane/metadata/android/en-US/changelogs/273.txt`.
- Save and review release.
- *Benefit:* Available immediately to your internal email testers with zero Google review delay.

#### Track 2: Closed Testing (Required for New Personal Accounts)
> [!NOTE]
> If your Google Play developer account was created after **November 13, 2023**, Google requires personal accounts to run a Closed Test with **at least 20 testers opted-in for 14 continuous days** before applying for Production release access.
- Create a closed testing track and invite 20+ testers via email or Google Groups.
- Keep the test active for 14 days, gather feedback, then apply for production access in Play Console.

#### Track 3: Production
- Once testing requirements are met, navigate to **Production &rarr; Create new release**.
- Select the verified `.aab` bundle, review warnings, and submit for Google review.
- Review typically takes 1 to 5 business days.

---

## 6. Versioning Best Practices

RepForge follows semantic versioning in `workout-logger/pubspec.yaml`:
```yaml
version: 2.1.1+35
```
- `2.1.1` is the `versionName` displayed to users.
- `35` is the `versionCode` (integer).
- **Rule for Google Play:** Every new `.aab` uploaded must have a strictly higher `versionCode` than any previously uploaded build.
- You can use the project script to bump versions:
  ```bash
  dart scripts/bump_version.dart patch
  ```

---

## 7. Automated Continuous Delivery (GitHub Actions)

RepForge includes a fully automated release pipeline in `.github/workflows/release.yml` that builds signed `.aab` bundles and publishes them directly to the Google Play **Internal Testing Track**.

### Required Secrets:
Set these in **GitHub Settings &rarr; Secrets and variables &rarr; Actions**:
- `PLAY_STORE_JSON_KEY`: Google Cloud Service Account JSON key with Play Developer API permissions.
- `KEYSTORE_BASE64`: Base64 string of `upload-keystore.jks`.
- `KEYSTORE_PASSWORD`: Keystore password.
- `KEY_ALIAS`: Keystore key alias.
- `KEY_PASSWORD`: Key password.

For full setup and service account instructions, refer to [RELEASE_WORKFLOW.md](file:///c:/Users/Devasy/OneDrive/Desktop/Workout-logger/docs/RELEASE_WORKFLOW.md).
