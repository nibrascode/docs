# Nibras Docs

Android üçün oflayn sənəd redaktoru. Kitab, məktub, hesabat yazın, PDF/Word ixrac edin.

## GitHub ilə APK (xətasız yığım)

Repo: [nibrascode/docs](https://github.com/nibrascode/docs)

Hər `main` push-da GitHub Actions **release APK** yığır.

1. [Actions](https://github.com/nibrascode/docs/actions) səhifəsini açın
2. **Build Android APK** workflow-una girin
3. Yaşıl (success) run-u açın
4. Aşağıda **Artifacts** → `nibras-docs-apk` yükləyin
5. Zip-i açın, `app-release.apk` telefona quraşdırın

Əl ilə yenidən yığmaq: **Actions → Build Android APK → Run workflow**

Kompüterdə özünüz: [APK_QUR.md](APK_QUR.md)

## Nə işləyir
- Ev siyahısı, yeni sənəd, şablonlar (roman, novella, qısa hekayə, uşaq kitabı, yazıçı dəftəri, memuar, şeir…)
- Qalın / kursiv / altxətt, rəng, şəkil, link
- **Əsl cədvəl (Word kimi):** ölçü toru, xanaya birbaşa yaz, Tab/Enter, sətir/sütun əlavə-sil, sütun eni, Excel/Sheets-dən yapışdır (TSV), üfüqi sürüşdürmə, başlıq sətri
- Kitab cədvəlləri: personaj, məkan, xronologiya, səhnə, fəsil planı, tədqiqat, lüğət, biblioqrafiya
- Titul, copyright, ithaf, epiqraf, ön söz, proloq, fəsil, hissə, səhnə, epilog, təşəkkür, müəllif haqqında
- Fəsil paneli: bütün fəsili yuxarı/aşağı daşı, köçür, sil, nömrələ (Fəsil 1, 2, 3…), kursor yerindən böl
- Mündəricat, tap/əvəz et, dipqeyd, oxu rejimi, fokus yazı, ad indeksi, paylaş
- Söz hədəfi + bu seansın sayı (aşağı paneldə)
- İxracda «Yalnız əlyazma»: plan cədvəlləri və outline çıxarılır
- Səhifə ölçüsü, kənarlar, avto-saxla
- PDF, DOCX, TXT, EPUB ixrac
- AZ / EN / RU / AR
- Hesabsız işləyir (bulud istəyə bağlıdır)

## Premium
Planlar: Free (gündə 3 sənəd, 20 səhifə), Pro (limitsiz yazı), Ultra (hər şey + premium üz qabıqları). Ödəniş RevenueCat ilə; quraşdırma: GOOGLE_AUTH.md.
