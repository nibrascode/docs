import '../../l10n/app_localizations.dart';

/// In-app privacy policy and terms, in every UI language. Keep in step with
/// what the app really does: offline-first, documents on the device, an
/// optional account (email) for sign-in, no ads, no analytics, no payments
/// while Premium is "coming soon".
class LegalSection {
  final String title;
  final String body;
  const LegalSection(this.title, this.body);
}

class LegalDoc {
  final String screenTitle;
  final String intro;
  final List<LegalSection> sections;
  final String updated;
  const LegalDoc(this.screenTitle, this.intro, this.sections, this.updated);
}

class LegalTexts {
  static const contact = 'nibrascode@gmail.com';

  static LegalDoc privacy(AppLanguage l) => _privacy[l]!;
  static LegalDoc terms(AppLanguage l) => _terms[l]!;

  static const Map<AppLanguage, LegalDoc> _privacy = {
    AppLanguage.en: LegalDoc(
      'Privacy policy',
      'Your writing is yours. This policy explains what Nibras Docs stores and why.',
      [
        LegalSection('1. Documents stay on your device',
            'Documents, images you insert and settings are saved in the app\'s private storage on your device. They are not uploaded anywhere.'),
        LegalSection('2. Optional account',
            'You can use the app without an account. If you create one, your email address and a password hash are stored by Supabase to sign you in.'),
        LegalSection('3. Photos and camera',
            'Images are chosen with the Android photo picker, so the app only receives the pictures you select. The camera is used only when you choose to take a photo. The app does not read your photo library.'),
        LegalSection('4. Exports and sharing',
            'PDF, Word, EPUB and text files are created on your device and shared only where you send them through the Android share sheet.'),
        LegalSection('5. No ads, no tracking',
            'Nibras Docs shows no ads and contains no analytics or advertising SDKs. All features are currently free; there are no payments.'),
        LegalSection('6. Children',
            'The app is not directed at children under 13 and does not knowingly collect their data.'),
        LegalSection('7. Deleting your data',
            'Uninstalling the app removes its documents from the device. To delete an account, email us and we will remove it within 30 days.'),
        LegalSection('8. Changes and contact',
            'We will update this page if the app changes how it handles data. Questions: nibrascode@gmail.com'),
      ],
      'Last updated: October 2026',
    ),
    AppLanguage.az: LegalDoc(
      'Məxfilik siyasəti',
      'Yazdıqlarınız sizindir. Bu siyasət Nibras Docs-un nəyi və nə üçün saxladığını izah edir.',
      [
        LegalSection('1. Sənədlər cihazınızda qalır',
            'Sənədlər, əlavə etdiyiniz şəkillər və ayarlar cihazınızda tətbiqin şəxsi yaddaşında saxlanılır. Heç yerə yüklənmir.'),
        LegalSection('2. İstəyə bağlı hesab',
            'Tətbiqdən hesabsız istifadə edə bilərsiniz. Hesab yaratsanız, daxil olmaq üçün e-poçt ünvanınız və şifrənin heşi Supabase-də saxlanılır.'),
        LegalSection('3. Şəkillər və kamera',
            'Şəkillər Android foto seçicisi ilə seçilir, tətbiq yalnız seçdiyiniz şəkilləri alır. Kamera yalnız siz şəkil çəkmək istəyəndə işləyir. Tətbiq qalereyanızı oxumur.'),
        LegalSection('4. İxrac və paylaşma',
            'PDF, Word, EPUB və mətn faylları cihazınızda yaranır və yalnız Android paylaşma pəncərəsi ilə göndərdiyiniz yerə gedir.'),
        LegalSection('5. Reklam və izləmə yoxdur',
            'Nibras Docs reklam göstərmir, analitika və ya reklam SDK-sı yoxdur. Hazırda bütün funksiyalar pulsuzdur, heç bir ödəniş yoxdur.'),
        LegalSection('6. Uşaqlar',
            'Tətbiq 13 yaşdan kiçik uşaqlar üçün nəzərdə tutulmayıb və onların məlumatlarını bilərəkdən toplamır.'),
        LegalSection('7. Məlumatların silinməsi',
            'Tətbiqi silmək onun sənədlərini cihazdan silir. Hesabı silmək üçün bizə yazın, 30 gün ərzində silinəcək.'),
        LegalSection('8. Dəyişikliklər və əlaqə',
            'Tətbiq məlumatlarla işləmə qaydasını dəyişsə, bu səhifəni yeniləyəcəyik. Suallar: nibrascode@gmail.com'),
      ],
      'Son yenilənmə: Oktyabr 2026',
    ),
    AppLanguage.ru: LegalDoc(
      'Политика конфиденциальности',
      'Ваши тексты принадлежат вам. Здесь описано, что хранит Nibras Docs и зачем.',
      [
        LegalSection('1. Документы остаются на устройстве',
            'Документы, вставленные изображения и настройки хранятся в закрытом хранилище приложения на вашем устройстве и никуда не загружаются.'),
        LegalSection('2. Необязательный аккаунт',
            'Приложением можно пользоваться без аккаунта. Если вы его создадите, адрес эл. почты и хеш пароля хранятся в Supabase для входа.'),
        LegalSection('3. Фото и камера',
            'Изображения выбираются через системный фотовыбор Android, поэтому приложение получает только выбранные вами снимки. Камера включается, только когда вы решите сделать фото. Приложение не читает вашу галерею.'),
        LegalSection('4. Экспорт и отправка',
            'Файлы PDF, Word, EPUB и TXT создаются на устройстве и отправляются только туда, куда вы их отправите через меню «Поделиться».'),
        LegalSection('5. Без рекламы и слежки',
            'В Nibras Docs нет рекламы, аналитики и рекламных SDK. Сейчас все функции бесплатны, платежей нет.'),
        LegalSection('6. Дети',
            'Приложение не предназначено для детей младше 13 лет и сознательно не собирает их данные.'),
        LegalSection('7. Удаление данных',
            'При удалении приложения его документы удаляются с устройства. Чтобы удалить аккаунт, напишите нам — мы удалим его в течение 30 дней.'),
        LegalSection('8. Изменения и контакты',
            'Мы обновим эту страницу, если приложение изменит работу с данными. Вопросы: nibrascode@gmail.com'),
      ],
      'Обновлено: октябрь 2026',
    ),
    AppLanguage.ar: LegalDoc(
      'سياسة الخصوصية',
      'ما تكتبه ملك لك. توضح هذه السياسة ما يحفظه Nibras Docs ولماذا.',
      [
        LegalSection('1. المستندات تبقى على جهازك',
            'تُحفظ المستندات والصور التي تدرجها والإعدادات في التخزين الخاص بالتطبيق على جهازك، ولا تُرفع إلى أي مكان.'),
        LegalSection('2. حساب اختياري',
            'يمكنك استخدام التطبيق بدون حساب. إذا أنشأت حساباً، يُحفظ بريدك الإلكتروني وتجزئة كلمة المرور لدى Supabase لتسجيل الدخول.'),
        LegalSection('3. الصور والكاميرا',
            'تُختار الصور عبر منتقي الصور في Android، فلا يتلقى التطبيق إلا الصور التي تختارها. تُستخدم الكاميرا فقط عندما تختار التقاط صورة. لا يقرأ التطبيق معرض صورك.'),
        LegalSection('4. التصدير والمشاركة',
            'تُنشأ ملفات PDF وWord وEPUB والنصوص على جهازك، ولا تُرسل إلا إلى حيث ترسلها عبر قائمة المشاركة في Android.'),
        LegalSection('5. لا إعلانات ولا تتبع',
            'لا يعرض Nibras Docs إعلانات ولا يحتوي على أدوات تحليل أو إعلانات. جميع الميزات مجانية حالياً ولا توجد مدفوعات.'),
        LegalSection('6. الأطفال',
            'التطبيق غير موجه للأطفال دون 13 عاماً ولا يجمع بياناتهم عن علم.'),
        LegalSection('7. حذف البيانات',
            'حذف التطبيق يزيل مستنداته من الجهاز. لحذف الحساب راسلنا وسنحذفه خلال 30 يوماً.'),
        LegalSection('8. التغييرات والتواصل',
            'سنحدّث هذه الصفحة إذا تغيّرت طريقة تعامل التطبيق مع البيانات. للأسئلة: nibrascode@gmail.com'),
      ],
      'آخر تحديث: أكتوبر 2026',
    ),
  };

  static const Map<AppLanguage, LegalDoc> _terms = {
    AppLanguage.en: LegalDoc(
      'Terms of service',
      'Please read these terms before using Nibras Docs.',
      [
        LegalSection('1. Acceptance', 'By using Nibras Docs you agree to these terms. If you do not agree, do not use the app.'),
        LegalSection('2. The service', 'Nibras Docs is a writing app for books and documents with PDF, Word, EPUB and text export. All features are currently free.'),
        LegalSection('3. Your content', 'Everything you write belongs to you. You are responsible for what you create and share, including respecting other people\'s copyright.'),
        LegalSection('4. Acceptable use', 'Do not use the app to create or spread illegal content, malware or spam, or to infringe the rights of others.'),
        LegalSection('5. Backups', 'Documents are stored on your device. Keep your own backups (Settings → Back up all documents); we cannot recover files lost with a device.'),
        LegalSection('6. Premium', 'Paid features may be offered later as in-app purchases. Their price and terms will be shown before you pay.'),
        LegalSection('7. No warranty', 'The app is provided "as is". To the extent the law allows, we are not liable for lost data or indirect damages.'),
        LegalSection('8. Changes and contact', 'We may update these terms; the current version is always in the app. Questions: nibrascode@gmail.com'),
      ],
      'Last updated: October 2026',
    ),
    AppLanguage.az: LegalDoc(
      'İstifadə şərtləri',
      'Nibras Docs-dan istifadə etməzdən əvvəl bu şərtləri oxuyun.',
      [
        LegalSection('1. Qəbul', 'Nibras Docs-dan istifadə etməklə bu şərtləri qəbul edirsiniz. Razı deyilsinizsə, tətbiqdən istifadə etməyin.'),
        LegalSection('2. Xidmət', 'Nibras Docs kitab və sənəd yazmaq üçün tətbiqdir, PDF, Word, EPUB və mətn ixracı var. Hazırda bütün funksiyalar pulsuzdur.'),
        LegalSection('3. Məzmununuz', 'Yazdığınız hər şey sizindir. Yaratdığınız və paylaşdığınız məzmuna, o cümlədən başqalarının müəllif hüquqlarına hörmətə siz cavabdehsiniz.'),
        LegalSection('4. Qadağalar', 'Tətbiqdən qanunsuz məzmun, zərərli proqram və ya spam yaratmaq, yaymaq və ya başqalarının hüquqlarını pozmaq üçün istifadə etməyin.'),
        LegalSection('5. Ehtiyat nüsxə', 'Sənədlər cihazınızda saxlanılır. Öz ehtiyat nüsxənizi çıxarın (Parametrlər → Ehtiyat nüsxə çıxar); cihazla itən faylları bərpa edə bilmərik.'),
        LegalSection('6. Premium', 'Ödənişli funksiyalar sonra tətbiqdaxili alış kimi təklif oluna bilər. Qiymət və şərtlər ödənişdən əvvəl göstəriləcək.'),
        LegalSection('7. Zəmanət yoxdur', 'Tətbiq «olduğu kimi» təqdim olunur. Qanunun icazə verdiyi qədər, məlumat itkisi və ya dolayı zərər üçün məsuliyyət daşımırıq.'),
        LegalSection('8. Dəyişikliklər və əlaqə', 'Bu şərtlər yenilənə bilər; son versiya həmişə tətbiqdədir. Suallar: nibrascode@gmail.com'),
      ],
      'Son yenilənmə: Oktyabr 2026',
    ),
    AppLanguage.ru: LegalDoc(
      'Условия использования',
      'Пожалуйста, прочитайте эти условия перед использованием Nibras Docs.',
      [
        LegalSection('1. Согласие', 'Используя Nibras Docs, вы принимаете эти условия. Если вы не согласны, не используйте приложение.'),
        LegalSection('2. Сервис', 'Nibras Docs — приложение для написания книг и документов с экспортом в PDF, Word, EPUB и TXT. Сейчас все функции бесплатны.'),
        LegalSection('3. Ваш контент', 'Всё, что вы пишете, принадлежит вам. Вы отвечаете за создаваемый и распространяемый контент, включая соблюдение чужих авторских прав.'),
        LegalSection('4. Запрещено', 'Не используйте приложение для создания или распространения незаконного контента, вредоносных программ, спама или нарушения прав других.'),
        LegalSection('5. Резервные копии', 'Документы хранятся на устройстве. Делайте резервные копии (Настройки → Резервная копия); файлы, утерянные вместе с устройством, мы восстановить не можем.'),
        LegalSection('6. Премиум', 'Платные функции могут появиться позже как покупки в приложении. Цена и условия будут показаны до оплаты.'),
        LegalSection('7. Без гарантий', 'Приложение предоставляется «как есть». В пределах, допустимых законом, мы не отвечаем за потерю данных и косвенный ущерб.'),
        LegalSection('8. Изменения и контакты', 'Мы можем обновлять условия; актуальная версия всегда в приложении. Вопросы: nibrascode@gmail.com'),
      ],
      'Обновлено: октябрь 2026',
    ),
    AppLanguage.ar: LegalDoc(
      'شروط الاستخدام',
      'يرجى قراءة هذه الشروط قبل استخدام Nibras Docs.',
      [
        LegalSection('1. القبول', 'باستخدامك Nibras Docs فإنك توافق على هذه الشروط. إن لم توافق فلا تستخدم التطبيق.'),
        LegalSection('2. الخدمة', 'Nibras Docs تطبيق لكتابة الكتب والمستندات مع تصدير PDF وWord وEPUB والنص. جميع الميزات مجانية حالياً.'),
        LegalSection('3. محتواك', 'كل ما تكتبه ملك لك. أنت مسؤول عما تنشئه وتشاركه، بما في ذلك احترام حقوق النشر للآخرين.'),
        LegalSection('4. الاستخدام المقبول', 'لا تستخدم التطبيق لإنشاء أو نشر محتوى غير قانوني أو برمجيات ضارة أو رسائل مزعجة، أو للتعدي على حقوق الآخرين.'),
        LegalSection('5. النسخ الاحتياطي', 'تُحفظ المستندات على جهازك. احتفظ بنسخ احتياطية (الإعدادات ← نسخ احتياطي)؛ لا يمكننا استعادة ملفات فُقدت مع الجهاز.'),
        LegalSection('6. بريميوم', 'قد تُتاح ميزات مدفوعة لاحقاً كمشتريات داخل التطبيق، وسيُعرض السعر والشروط قبل الدفع.'),
        LegalSection('7. بدون ضمان', 'يُقدَّم التطبيق «كما هو». وفي حدود ما يسمح به القانون، لسنا مسؤولين عن فقدان البيانات أو الأضرار غير المباشرة.'),
        LegalSection('8. التغييرات والتواصل', 'قد نحدّث هذه الشروط؛ والنسخة الحالية متاحة دائماً في التطبيق. للأسئلة: nibrascode@gmail.com'),
      ],
      'آخر تحديث: أكتوبر 2026',
    ),
  };
}
