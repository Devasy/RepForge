# Automated Release Workflow

This repository uses GitHub Actions to automatically create releases when PRs are merged to the `main` branch.

## 🚀 How It Works

1. **PR Merge**: When a pull request is merged to `main`, the workflow triggers automatically
2. **Version Bump**: The script increments the patch version and build number in `pubspec.yaml`
3. **Commit & Tag**: Changes are committed and a new git tag is created (e.g., `v1.0.3`)
4. **Build APK**: Flutter builds a release APK for Android
5. **Create Release**: A GitHub release is created with the APK attached

## 📋 Version Bumping Strategy

- **Automatic**: Patch version increments on every merge (e.g., `1.0.2` → `1.0.3`)
- **Build number**: Also increments automatically (e.g., `+3` → `+4`)
- **Manual bumps**: For minor/major version changes, edit `pubspec.yaml` manually before merging

### Version Format
 
```yaml
version: MAJOR.MINOR.PATCH+BUILD
# Example: 1.0.2+3
```

## 🔧 Setup Instructions

### 1. Enable GitHub Actions
 
Ensure GitHub Actions is enabled in your repository settings:
- Go to **Settings** → **Actions** → **General**
- Under "Actions permissions", select "Allow all actions and reusable workflows"

### 2. Configure Branch Protection (Optional but Recommended)
If you have branch protection on `main`:
- Go to **Settings** → **Branches** → **Branch protection rules**
- Edit the rule for `main`
- Under "Allow specified actors to bypass required pull requests", add `github-actions[bot]`
- This allows the workflow to push version bump commits

### 3. Verify Workflow Permissions
The workflow needs write permissions to create releases:
- Go to **Settings** → **Actions** → **General**
- Under "Workflow permissions", ensure "Read and write permissions" is selected
- Check "Allow GitHub Actions to create and approve pull requests" (optional)

## 📦 First Release

To trigger your first automated release:

1. Create a feature branch:
   ```bash
   git checkout -b feature/test-release
   ```

2. Make any change (or just update README):
   ```bash
   echo "# Test" >> README.md
   git add README.md
   git commit -m "test: trigger first automated release"
   git push origin feature/test-release
   ```

3. Create and merge a PR to `main`

4. Check the **Actions** tab to see the workflow running

5. Once complete, check the **Releases** section for your new release with APK

## 📱 Installing the APK

After each release:
1. Go to **Releases** in your GitHub repository
2. Download the latest `repforge-vX.X.X.apk` file
3. Transfer to your Android device
4. Enable "Install from unknown sources" in Android settings
5. Install the APK

## 🔐 Production Signing (Recommended)

Currently, the APK is signed with debug keys. For production releases:

1. Generate a release keystore:
   ```bash
   keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
   ```

2. Add keystore to GitHub Secrets:
   - Encode keystore: `base64 release-keystore.jks > keystore.txt`
   - Add to **Settings** → **Secrets** → **Actions**:
     - `KEYSTORE_BASE64`: Contents of `keystore.txt`
     - `KEYSTORE_PASSWORD`: Your keystore password
     - `KEY_ALIAS`: Your key alias (e.g., "release")
     - `KEY_PASSWORD`: Your key password

3. Update `android/app/build.gradle.kts` to use release signing

4. Update the workflow to decode and use the keystore

## 🛠️ Manual Version Bumping

To manually control version numbers:

### Bump Minor Version (e.g., 1.0.3 → 1.1.0)
Edit `pubspec.yaml` before merging:
```yaml
version: 1.1.0+5
```

### Bump Major Version (e.g., 1.1.0 → 2.0.0)
Edit `pubspec.yaml` before merging:
```yaml
version: 2.0.0+6
```

The workflow will still increment from whatever version you set.

## 📊 Monitoring Releases

- **Actions Tab**: View workflow runs and logs
- **Releases Tab**: See all published releases
- **Tags**: View all version tags in the repository

## 🐛 Troubleshooting

### Workflow fails with "Permission denied"
- Check that workflow permissions are set to "Read and write"
- Verify branch protection settings allow `github-actions[bot]` to push

### APK not attached to release
- Check the workflow logs in the Actions tab
- Verify the build step completed successfully
- Ensure the APK path in the workflow matches the actual build output

### Version not bumping
- Check that `scripts/bump_version.dart` has execute permissions
- Verify the script can parse your `pubspec.yaml` format
- Review workflow logs for script errors

## 📝 Files Created

- `.github/workflows/release.yml` - Main workflow configuration
- `scripts/bump_version.dart` - Version bumping script
- `docs/RELEASE_WORKFLOW.md` - This documentation

## 🔄 Workflow Diagram

```text
PR Merged to main
       ↓
Checkout code
       ↓
Setup Flutter & Java
       ↓
Bump version in pubspec.yaml
       ↓
Commit & push version change
       ↓
Create git tag (v1.0.3)
       ↓
Build release APK
       ↓
Create GitHub Release
       ↓
Upload APK to release
       ↓
✅ Done!
```
