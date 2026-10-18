# Part 10 — Play Store release checklist

## A. App identity
- Name: **Nibras Docs**
- Package: fixed `applicationId` in `android/app/build.gradle.kts`
- Icon + splash: Part 9

## B. Release signing
```bash
keytool -genkey -v -keystore nibras-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias nibras
```
Copy `android/key.properties.example` → `android/key.properties` (fill passwords/path).

```bash
flutter build appbundle --release
```
→ `build/app/outputs/bundle/release/app-release.aab`

Never commit `.jks` or `key.properties`.

## C. Play Console steps
1. Create app Nibras Docs
2. Store listing (title, short/full description, screenshots, 512 icon, feature graphic)
3. Privacy policy public URL + in-app screen
4. Content rating, target 13+
5. Data safety form
6. Subscriptions: `pro_monthly` ($2.75), `elite_monthly` ($5.75)
7. Payments profile + bank
8. Upload AAB → Internal testing → Production

## D. Store text (EN)
**Short:** Write books and documents offline. Export PDF and Word.

**Full:** Nibras Docs — mobile writing for books and notes. Offline-first, chapters, TOC, tables, images, PDF/Word/EPUB export, optional cloud sync. Free: 5 docs / 15 pages. Pro and Elite for longer books.

## E. Contact
nibrascode@gmail.com
