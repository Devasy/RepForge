# RepForge launcher icon — Rounded Signal v7

The current icon uses rounded violet weights joined by a cyan pulse
on a dark `#07070A` background. Gentle gradients, a fine upper highlight and
shallow lower edges add restrained depth. The same rounded silhouette becomes
the Android themed icon. The app's interior theme is unchanged by this asset
update. The monochrome asset has no baked-in white background; Android chooses
its tint and background from the user's launcher/wallpaper theme. The proof
sheet shows a dark themed example, not a forced device color scheme.

## Current assets

- `repforge_signal_v7.svg`: editable, transparent vector source of truth.
- `repforge_signal_v7.png`: 1024px opaque legacy/store master.
- `repforge_signal_foreground_v7.png`: 1024px transparent adaptive foreground.
- `repforge_signal_v7_proof.png`: launcher-size, mask and monochrome review sheet.
- `android/app/src/main/res/drawable/ic_launcher_monochrome.xml`: matching native vector.
- `fastlane/metadata/android/en-US/images/icon.png`: 512px store icon.

From the repository root, run `node scripts/generate_signal_icon.cjs` with
`sharp` available through normal module resolution or `NODE_PATH`. The script
renders all five Android densities and both adaptive-icon XML variants from
the SVG. Padding is built into the foreground; additional adaptive inset is
zero. The opaque master enlarges the mark by 18% for visibility. Android's
launcher applies its own outer mask.

The launcher configuration in `pubspec.yaml` points to v7. If using
`flutter_launcher_icons` separately, rerun the canonical Node generator after
it to restore the matching Android 13 monochrome override.

This redesign was constructed directly as vector geometry; it did not use an
image-generation prompt. Earlier icon files in the original checkout are retained locally for
reference. The flat v5 and the
orange/light v6 vector sources are included; their PNGs can be regenerated. Pass `5` or `6` to the
generator to explicitly render an archived design; default generation uses v7.

See `docs/APP_CAPABILITIES_AND_ICON_2026-10-16.md` at the repository root for the
feature analysis, AI tool inventory, data-question examples and design rationale.
