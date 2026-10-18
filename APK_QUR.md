# Nibras Docs — APK necə yığılır

Bu qovluq **native Android Flutter** layihəsidir. Veb tətbiq deyil.
Sənədlər telefonda saxlanır (SharedPreferences). İnternet yalnız istəyə bağlı bulud üçün lazımdır.

## Ən asan yol: GitHub Actions

1. https://github.com/mmuxax-bot/docspro
2. **Actions** → **Build Android APK**
3. Yaşıl run → **Artifacts** → `nibras-docs-apk`
4. `app-release.apk` telefona quraşdırın

Kod `main`-ə düşəndə APK avtomatik yığılır. Əl ilə: **Run workflow**.

## Kompüterdə (Flutter SDK)

Tələblər: Flutter 3.35+ (Dart 3.9), Android SDK, Java 17.

```
git clone https://github.com/mmuxax-bot/docspro.git
cd docspro
flutter pub get
flutter build apk --release
```

Fayl: `build/app/outputs/flutter-apk/app-release.apk`

Play Store üçün App Bundle:

```
flutter build appbundle --release
```

## Nə düzəldildi (bu versiya)
- Sənəd hər açılışda başlığı təkrarlamır
- Yerli və bulud eyni tam mətni saxlayır
- Çıxış dialoqu: Ləğv et = qal, Saxlama = çıx, Saxla və çıx = saxla
- Gradle `signingConfigs` düzgün yerdədir (`key.properties` yoxdursa debug imza)
- GitHub Actions APK workflow

## Qeyd
İlk yığım debug açarı ilə imzalanır (`key.properties` yoxdursa).
Play Store üçün `android/key.properties.example` faylını `key.properties` kimi kopyalayıb keystore yolunu yazın.
Ətraflı: `STORE_RELEASE.md`
