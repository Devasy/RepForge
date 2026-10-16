/* RepForge: render the editable SVG to launcher and store assets.
 * Usage: node scripts/generate_signal_icon.cjs [5|6|7] (default: 7)
 * Requires sharp (normal Node module resolution, or NODE_PATH).
 * No Flutter SDK, network, or image-generation API is needed.
 */
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const assets = path.join(root, 'workout-logger/assets/icon');
const res = path.join(root, 'workout-logger/android/app/src/main/res');
const version = process.argv[2] || '7';
if (!['5', '6', '7'].includes(version)) throw new Error('Expected icon version 5, 6 or 7.');
const background = version === '6' ? '#F5F7F8' : '#07070A';
const basename = `repforge_signal_v${version}`;
const svgHeader = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">';

async function main() {
  const source = await fs.readFile(path.join(assets, `${basename}.svg`), 'utf8');
  const paths = source.match(/<path\b[^>]*\/>/g);
  if (!paths || paths.length < 2) throw new Error('Expected canonical SVG paths.');
  const definitions = source.match(/<defs>[\s\S]*?<\/defs>/)?.[0] || '';
  const monoPaths = version === '5' ? paths : paths.filter(p => p.includes('data-monochrome="true"'));
  if (monoPaths.length !== 2) throw new Error('Expected two monochrome silhouette paths.');
  const foreground = Buffer.from(source);
  const master = Buffer.from(`${svgHeader}${definitions}<rect width="1024" height="1024" fill="${background}"/><g transform="translate(512 512) scale(1.18) translate(-512 -512)">${paths.join('')}</g></svg>`);
  await sharp(master).png().toFile(path.join(assets, `${basename}.png`));
  await sharp(foreground).png().toFile(path.join(assets, `repforge_signal_foreground_v${version}.png`));
  const densities = [['mdpi', 1], ['hdpi', 1.5], ['xhdpi', 2], ['xxhdpi', 3], ['xxxhdpi', 4]];
  for (const [density, scale] of densities) {
    const legacyDir = path.join(res, `mipmap-${density}`);
    const adaptiveDir = path.join(res, `drawable-${density}`);
    await fs.mkdir(legacyDir, {recursive: true});
    await fs.mkdir(adaptiveDir, {recursive: true});
    await sharp(master).resize(48 * scale).png().toFile(path.join(legacyDir, 'ic_launcher.png'));
    await sharp(foreground).resize(108 * scale).png().toFile(path.join(adaptiveDir, 'ic_launcher_foreground.png'));
  }
  const nativePaths = monoPaths.map(p => p
    .replace('<path ', '    <path ')
    .replace(/data-monochrome="true"\s*/, '')
    .replace(/\bfill="none"/, 'android:fillColor="#00000000"')
    .replace(/\bfill="(?!none)[^"]+"/, 'android:fillColor="#FFFFFFFF"')
    .replace(/\bstroke="[^"]+"/, 'android:strokeColor="#FFFFFFFF"')
    .replace(/stroke-width=/, 'android:strokeWidth=')
    .replace(/stroke-linecap=/, 'android:strokeLineCap=')
    .replace(/stroke-linejoin=/, 'android:strokeLineJoin=')
    .replace(/\bd=/, 'android:pathData='));
  await fs.writeFile(path.join(res, 'drawable/ic_launcher_monochrome.xml'), `<?xml version="1.0" encoding="utf-8"?>\n<!-- Generated from assets/icon/${basename}.svg. -->\n<vector xmlns:android="http://schemas.android.com/apk/res/android"\n    android:width="108dp" android:height="108dp"\n    android:viewportWidth="1024" android:viewportHeight="1024">\n${nativePaths.join('\n')}\n</vector>\n`);
  for (const version of [26, 33]) {
    const dir = path.join(res, `mipmap-anydpi-v${version}`);
    await fs.mkdir(dir, {recursive: true});
    const monochrome = version >= 33 ? '\n    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />' : '';
    await fs.writeFile(path.join(dir, 'ic_launcher.xml'), `<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:drawable="@color/ic_launcher_background" />\n    <foreground android:drawable="@drawable/ic_launcher_foreground" />${monochrome}\n</adaptive-icon>\n`);
  }
  await fs.writeFile(path.join(res, 'values/colors.xml'), `<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">${background}</color>\n</resources>\n`);
  await sharp(master).resize(512).png().toFile(path.join(root, 'fastlane/metadata/android/en-US/images/icon.png'));
  // Review actual adaptive padding under launcher masks and at real pixel sizes.
  const placed = (x, y, size, id, mask, themed = false) => {
    const shape = mask === 'circle'
      ? `<circle cx="${x + size / 2}" cy="${y + size / 2}" r="${size / 2}"/>`
      : `<rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${size * 0.24}"/>`;
    const themedInk = version === '7' ? '#D8C9F0' : '#E7ECF0';
    const themedBackground = version === '7' ? '#17121F' : '#344047';
    const geometry = themed ? monoPaths.join('').replace(/(?:url\(#[^)]+\)|#7C3AED|#00C2D4)/g, themedInk) : paths.join('');
    return `<defs><clipPath id="${id}">${shape}</clipPath></defs><g clip-path="url(#${id})"><rect x="${x}" y="${y}" width="${size}" height="${size}" fill="${themed ? themedBackground : background}"/><g transform="translate(${x} ${y}) scale(${size / 1024})">${geometry}</g></g>`;
  };
  const text = (x, y, label, size = 16, fill = '#BFC0CB') => `<text x="${x}" y="${y}" font-family="Segoe UI, sans-serif" font-size="${size}" fill="${fill}">${label}</text>`;
  let proof = `<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="670" viewBox="0 0 1120 670"><rect width="1120" height="670" fill="#17171E"/>`;
  proof += definitions;
  proof += text(40, 52, `RepForge / Signal v${version}`, 28, '#F4F4F8');
  proof += text(40, 84, version === '7' ? 'Violet and cyan. Rounded forms, subtle depth, dark canvas.' : version === '6' ? 'Forge-orange and graphite. Rounded forms with restrained depth.' : 'Minimal strength, connected health and data.');
  proof += `<image x="40" y="125" width="360" height="360" href="data:image/png;base64,${(await fs.readFile(path.join(assets, `${basename}.png`))).toString('base64')}"/>`;
  proof += text(40, 519, 'Legacy / store master');
  proof += placed(450, 145, 180, 'circle', 'circle') + text(450, 355, 'Adaptive circle');
  proof += placed(670, 145, 180, 'squircle', 'squircle') + text(670, 355, 'Rounded square');
  proof += placed(890, 145, 180, 'themed', 'circle', true) + text(890, 355, 'Themed / dark preview');
  proof += text(450, 431, 'Actual launcher sizes', 20, '#F4F4F8');
  for (const [i, size] of [24, 36, 48, 64, 96].entries()) {
    const x = 450 + i * 126;
    proof += placed(x, 465, size, `size${size}`, 'squircle') + text(x, 594, `${size}px`);
  }
  proof += text(40, 637, version === '6' ? 'Warm orange / graphite / light canvas #F5F7F8 / matching rounded monochrome silhouette' : 'Dark canvas #07070A / monochrome colors follow the Android launcher theme', 14) + '</svg>';
  await sharp(Buffer.from(proof)).png().toFile(path.join(assets, `${basename}_proof.png`));
  console.log(`Generated v${version} masters, five legacy densities, five adaptive densities, themed vector, Android XML and store icon.`);
}
main().catch(error => {console.error(error); process.exitCode = 1;});
