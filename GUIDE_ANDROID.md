# راهنمای ساخت خودکار APK اندروید (GitHub Actions)

> این سند توضیح می‌دهد چطور بازی Godot به‌صورت خودکار به فایل `.apk` تبدیل و در گیت‌هاب در بخش **Releases** قرار می‌گیرد.

## واقعیت مهم
- **APK** = فایل نصب اندروید، از کد Godot ساخته می‌شود.
- **GitHub خودش APK نمی‌سازد**؛ فقط کد را نگه می‌دارد.
- با **GitHub Actions** می‌توانیم کاری کنیم که بعد از هر `push` روی `main`، گیت‌هاب خودکار APK بسازد و در **Releases** بگذارد.

## اجزای لازم (پیش‌نیاز)
- Godot 4.x (رایگان، MIT)
- Android SDK (رایگان)
- Android Debug Keystore (برای امضا)
- GitHub Actions (خودکارسازی)

## ساختار پروژه
```
Game/
├── project.godot
├── export_presets.cfg
├── .github/workflows/build-android.yml
├── scenes/  scripts/  assets/
```

## فایل export_presets.cfg (نمونه)
```ini
[preset.0]
name="Android"
platform="Android"
runnable=true
export_filter="all_resources"
architectures/armeabi-v7a=true
architectures/arm64-v8a=true
version/code=1
version/name="1.0.0"
package/unique_name="com.yourgame.country"
package/name="Country Simulator"
```

## فایل GitHub Actions (.github/workflows/build-android.yml)
```yaml
name: Build Android APK
on:
  push:
    branches: [ main ]
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Godot 4.7.1 stable
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.x86_64.zip
          unzip -q Godot_v4.7.1-stable_linux.x86_64.zip
          chmod +x Godot_v4.7.1-stable_linux.x86_64
          sudo mv Godot_v4.7.1-stable_linux.x86_64 /usr/local/bin/godot
          wget -q https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz
          unzip -q Godot_v4.7.1-stable_export_templates.tpz
          mkdir -p ~/.local/share/godot/export_templates/4.7.1.stable
          mv templates/* ~/.local/share/godot/export_templates/4.7.1.stable/
      - name: Setup Android SDK
        uses: android-actions/setup-android@v3
      - name: Export APK
        run: |
          godot --headless --path . --import
          godot --headless --path . --export-release "Android" build/country-sim.apk
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with: { name: apk, path: build/country-sim.apk }
      - name: Release
        uses: softprops/action-gh-release@v2
        with: { files: build/country-sim.apk }
```

## گام‌ها
1. کد Godot نوشته شود (من انجام می‌دهم و به گیت‌هاب می‌فرستم).
2. export_presets.cfg اضافه شود.
3. workflow ساخته شود.
4. بعد از هر push روی main → APK خودکار ساخته و در Releases گذاشته می‌شود.
5. دانلود و نصب روی گوشی.

## نصب روی گوشی
- دانلود `.apk` → فعال‌کردن «نصب از منابع ناشناس» → نصب.

## هزینه (مطابق قانون رایگان بودن)
- GitHub Actions برای ریپوی عمومی **رایگان** است.
- Godot و Android SDK **رایگان و متن‌باز** هستند. ✅
