# Google Sign-In + Supabase + RevenueCat setup (Nibras Docs)

App: Android package `com.nibras.docs`. Supabase project **Nibras Docs** (`nocruxpgwldlrsuraavv`) — dedicated, not the site DB.

Flow: native Google account picker (`google_sign_in` 7.x, Credential Manager) → Google **idToken**
→ `supabase.auth.signInWithIdToken(provider: google)` → two-way cloud sync (`CloudSync.run`)
→ RevenueCat `logIn(<supabase user id>)`.

## 1. Google Cloud Console (APIs & Services → Credentials)
1. OAuth consent screen: External, app name "Nibras Docs", support email, privacy URL
   `https://nibrascode.com/privacy`. Scopes: `email`, `profile`, `openid`.
2. **Web application** OAuth client → copy **Client ID** and **Client secret**.
   (Android apps use the *Web* client id as `serverClientId` to get an idToken.)
3. **Android** OAuth client(s), package `com.nibras.docs`, one per SHA-1:
   - debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
   - upload/release keystore SHA-1
   - **Play App Signing** SHA-1 (Play Console → Setup → App integrity). Without this, Google
     sign-in fails for Play-installed builds.

## 2. Supabase Dashboard → Authentication → Sign In / Providers → Google
- Enable Google. Client IDs: paste the **Web client id** (you may add the Android client ids
  comma-separated too). Client secret: the Web client secret.
- "Skip nonce check" is not needed (the app sends no nonce).

## 3. App config (`assets/env.json`, gitignored — see `env.example.json`)
```json
{
  "SUPABASE_URL": "https://nocruxpgwldlrsuraavv.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_...",
  "GOOGLE_WEB_CLIENT_ID": "xxxx.apps.googleusercontent.com",
  "REVENUECAT_GOOGLE_API_KEY": "goog_..."
}
```
Same keys work as `--dart-define=KEY=value`. If `GOOGLE_WEB_CLIENT_ID` is empty the app shows
"Google sign-in is not configured yet" and email login / offline mode still work.

## 4. RevenueCat (project Nibras Docs)
- Entitlements `pro`, `ultra`; offering `default`; packages
  `$rc_custom_{pro,ultra}_{monthly,annual}`.
- Create matching subscriptions in Play Console: `nibras_docs_pro_monthly` (base plan `monthly`),
  `nibras_docs_pro_yearly` (`yearly`), `nibras_docs_ultra_monthly`, `nibras_docs_ultra_yearly`.
- Add a Play **service account** JSON to RevenueCat (not done yet) — required to validate purchases.
- Billing turns on automatically only when the SDK key is present and init succeeds.

## Plans
- Free: 3 new documents/day, 20 pages per document.
- Pro: unlimited writing; premium (Nibras art) covers locked.
- Ultra: everything.

## SHA-1 fingerprints (box keys, 2026-10-25)

Package: `com.nibras.docs`

| Build | SHA-1 |
|-------|-------|
| Release upload keystore (`/home/box/keys/nibras-docs-release.jks`) | `60:1C:68:C2:3F:E8:8D:62:EF:F9:76:FF:A3:2F:31:E3:E7:4F:49:23` |
| Debug (`~/.android/debug.keystore`) | `5C:FD:E0:99:CB:BE:72:D4:38:AE:77:43:C3:87:AB:15:05:FF:2C:B4` |

Also add Play App Signing certificate SHA-1 from Play Console → App integrity when available.


## Configured clients (2026-10-25, project nibras-odf)

| Client | ID |
|--------|-----|
| Nibras Docs Web (Supabase) | `1034836945083-t9kqksafilavqnt0mdk9lgceb1dc2ecm.apps.googleusercontent.com` |
| Nibras Docs Android Release | `1034836945083-m5o065sul3lurcaaqh40dc08d78qpnm0.apps.googleusercontent.com` |
| Nibras Docs Android Debug | `1034836945083-909obp8c1sasdsdqcu1tenqv5t5p000p.apps.googleusercontent.com` |

Web client secret is only on the box at `/home/box/keys/nibras-docs-google-oauth.env` (not in git).
Use the Web client ID as `GOOGLE_WEB_CLIENT_ID` / `serverClientId`.

| Play App Signing (Play Console) | `45:F2:A3:54:B0:26:99:7A:12:16:79:25:FA:9D:E3:82:4C:73:58:4A` |
