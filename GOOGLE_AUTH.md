# Google Sign-In + Supabase + RevenueCat setup (Nibras Docs)

App: Android package `com.nibras.docs`. Supabase project **Nibrascode** (`qvwqqpxrvnrnwvyckwlo`).

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
  "SUPABASE_URL": "https://qvwqqpxrvnrnwvyckwlo.supabase.co",
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
