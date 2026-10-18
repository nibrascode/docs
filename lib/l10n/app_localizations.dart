import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

enum AppLanguage { az, en, ru, ar }

extension AppLanguageExt on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.az:
        return 'az';
      case AppLanguage.en:
        return 'en';
      case AppLanguage.ru:
        return 'ru';
      case AppLanguage.ar:
        return 'ar';
    }
  }

  String get nativeName {
    switch (this) {
      case AppLanguage.az:
        return 'Azərbaycan';
      case AppLanguage.en:
        return 'English';
      case AppLanguage.ru:
        return 'Русский';
      case AppLanguage.ar:
        return 'العربية';
    }
  }

  String get flag {
    switch (this) {
      case AppLanguage.az:
        return '🇦🇿';
      case AppLanguage.en:
        return '🇬🇧';
      case AppLanguage.ru:
        return '🇷🇺';
      case AppLanguage.ar:
        return '🇸🇦';
    }
  }

  TextDirection get textDirection {
    if (this == AppLanguage.ar) return TextDirection.rtl;
    return TextDirection.ltr;
  }

  Locale get locale {
    return Locale(code);
  }
}

class AppLocalizations extends ChangeNotifier {
  static final AppLocalizations _instance = AppLocalizations._internal();
  factory AppLocalizations() => _instance;
  AppLocalizations._internal();

  AppLanguage _language = AppLanguage.en;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  TextDirection get textDirection => _language.textDirection;

  static const _prefKey = 'nibras_language';

  Future<void> loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code == null) return;
      for (final lang in AppLanguage.values) {
        if (lang.code == code) {
          _language = lang;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}
  }

  void setLanguage(AppLanguage lang) {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefKey, lang.code);
    });
  }

  static AppLocalizations of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_LocalizationsInherited>()!
        .localizations;
  }

  // ─── App General ───────────────────────────────────────────────────────────
  String get appName => _t(
    az: 'Nibras Docs',
    en: 'Nibras Docs',
    ru: 'Nibras Docs',
    ar: 'Nibras Docs',
  );

  // ─── Documents List ─────────────────────────────────────────────────────────
  String get searchHint => _t(
    az: 'Sənədlərimdə axtar...',
    en: 'Search my documents...',
    ru: 'Поиск в документах...',
    ar: 'ابحث في مستنداتي...',
  );
  String get newDocument => _t(
    az: 'Yeni sənəd yarat',
    en: 'Create new document',
    ru: 'Создать документ',
    ar: 'إنشاء مستند جديد',
  );
  String get newDocumentSubtitle => _t(
    az: 'Boş sənəd və ya şablonlardan istifadə et',
    en: 'Blank document or use templates',
    ru: 'Пустой документ или шаблоны',
    ar: 'مستند فارغ أو استخدم القوالب',
  );
  String get templates =>
      _t(az: 'Şablonlar', en: 'Templates', ru: 'Шаблоны', ar: 'القوالب');
  String get templatesSubtitle => _t(
    az: 'Kitab, məqalə, məktub, hesabat və s.',
    en: 'Book, article, letter, report, etc.',
    ru: 'Книга, статья, письмо, отчёт и др.',
    ar: 'كتاب، مقال، رسالة، تقرير وغيرها',
  );
  String get allDocuments => _t(
    az: 'Bütün sənədlər',
    en: 'All documents',
    ru: 'Все документы',
    ar: 'جميع المستندات',
  );
  String get recent =>
      _t(az: 'Sonuncu', en: 'Recent', ru: 'Недавние', ar: 'الأخيرة');
  String get favorites =>
      _t(az: 'Favorit', en: 'Favorites', ru: 'Избранное', ar: 'المفضلة');
  String get cloud => _t(az: 'Bulud', en: 'Cloud', ru: 'Облако', ar: 'السحابة');
  String get documentDeleted => _t(
    az: 'Sənəd silindi',
    en: 'Document deleted',
    ru: 'Документ удалён',
    ar: 'تم حذف المستند',
  );
  String get deleteFailed => _t(
    az: 'Silinmə uğursuz oldu',
    en: 'Delete failed',
    ru: 'Ошибка удаления',
    ar: 'فشل الحذف',
  );
  String get loadFailed => _t(
    az: 'Sənədlər yüklənmədi',
    en: 'Failed to load documents',
    ru: 'Не удалось загрузить документы',
    ar: 'فشل تحميل المستندات',
  );
  String get retry => _t(
    az: 'Yenidən cəhd et',
    en: 'Try again',
    ru: 'Повторить',
    ar: 'حاول مرة أخرى',
  );
  String get noDocuments => _t(
    az: 'Heç bir sənəd yoxdur',
    en: 'No documents yet',
    ru: 'Нет документов',
    ar: 'لا توجد مستندات',
  );
  String get noDocumentsSubtitle => _t(
    az: 'Yeni sənəd yaratmaq üçün + düyməsinə basın',
    en: 'Tap + to create a new document',
    ru: 'Нажмите + для создания документа',
    ar: 'اضغط + لإنشاء مستند جديد',
  );
  String get cloudSyncTitle => _t(
    az: 'Bulud sinxronizasiyası',
    en: 'Cloud sync',
    ru: 'Синхронизация',
    ar: 'مزامنة السحابة',
  );
  String get cloudSyncSubtitle => _t(
    az: 'Bütün sənədlər avtomatik sinxronlaşdırılır',
    en: 'All documents are automatically synced',
    ru: 'Все документы синхронизируются автоматически',
    ar: 'تتم مزامنة جميع المستندات تلقائياً',
  );
  String get words => _t(az: 'söz', en: 'words', ru: 'слов', ar: 'كلمة');

  // ─── Document Editor ─────────────────────────────────────────────────────────
  String get untitledDocument => _t(
    az: 'Yeni sənəd',
    en: 'New document',
    ru: 'Новый документ',
    ar: 'مستند جديد',
  );
  String get documentSaved => _t(
    az: 'Sənəd saxlanıldı',
    en: 'Document saved',
    ru: 'Документ сохранён',
    ar: 'تم حفظ المستند',
  );
  String get saveFailed => _t(
    az: 'Saxlama uğursuz oldu',
    en: 'Save failed',
    ru: 'Ошибка сохранения',
    ar: 'فشل الحفظ',
  );
  String get unsavedChanges => _t(
    az: 'Saxlanılmamış dəyişikliklər',
    en: 'Unsaved changes',
    ru: 'Несохранённые изменения',
    ar: 'تغييرات غير محفوظة',
  );
  String get saveBeforeExit => _t(
    az: 'Çıxmazdan əvvəl saxlamaq istəyirsiniz?',
    en: 'Save before exiting?',
    ru: 'Сохранить перед выходом?',
    ar: 'هل تريد الحفظ قبل الخروج؟',
  );
  String get cancel =>
      _t(az: 'Ləğv et', en: 'Cancel', ru: 'Отмена', ar: 'إلغاء');
  String get saveAndExit => _t(
    az: 'Saxla və çıx',
    en: 'Save & exit',
    ru: 'Сохранить и выйти',
    ar: 'حفظ والخروج',
  );
  String get save => _t(az: 'Saxla', en: 'Save', ru: 'Сохранить', ar: 'حفظ');
  String get saving => _t(
    az: 'Saxlanır...',
    en: 'Saving...',
    ru: 'Сохранение...',
    ar: 'جارٍ الحفظ...',
  );
  String get saved =>
      _t(az: 'Saxlanıldı', en: 'Saved', ru: 'Сохранено', ar: 'تم الحفظ');
  String get page => _t(az: 'Səhifə', en: 'Page', ru: 'Страница', ar: 'صفحة');
  String get titleHint =>
      _t(az: 'Başlıq...', en: 'Title...', ru: 'Заголовок...', ar: 'العنوان...');
  String get bodyHint => _t(
    az: 'Yazmağa başlayın...',
    en: 'Start writing...',
    ru: 'Начните писать...',
    ar: 'ابدأ الكتابة...',
  );
  String get wordCount => _t(az: 'söz', en: 'words', ru: 'слов', ar: 'كلمة');
  String get charCount =>
      _t(az: 'simvol', en: 'chars', ru: 'символов', ar: 'حرف');
  String get share =>
      _t(az: 'Paylaş', en: 'Share', ru: 'Поделиться', ar: 'مشاركة');
  String get more => _t(az: 'Daha çox', en: 'More', ru: 'Ещё', ar: 'المزيد');
  String get textStyle => _t(az: 'Mətn', en: 'Text', ru: 'Текст', ar: 'نص');
  String get color => _t(az: 'Rəng', en: 'Color', ru: 'Цвет', ar: 'لون');
  String get styles =>
      _t(az: 'Stillər', en: 'Styles', ru: 'Стили', ar: 'أنماط');
  String get insert =>
      _t(az: 'Daxil et', en: 'Insert', ru: 'Вставить', ar: 'إدراج');
  String get image =>
      _t(az: 'Şəkil', en: 'Image', ru: 'Изображение', ar: 'صورة');
  String get table => _t(az: 'Cədvəl', en: 'Table', ru: 'Таблица', ar: 'جدول');
  String get link =>
      _t(az: 'Daxili link', en: 'Link', ru: 'Ссылка', ar: 'رابط');
  String get symbol => _t(az: 'Simvol', en: 'Symbol', ru: 'Символ', ar: 'رمز');
  String get diagram =>
      _t(az: 'Diaqram', en: 'Diagram', ru: 'Диаграмма', ar: 'مخطط');
  String get pageBreak => _t(
    az: 'Səhifə sonu',
    en: 'Page break',
    ru: 'Разрыв страницы',
    ar: 'فاصل صفحة',
  );
  String get horizontalLine => _t(
    az: 'Üfüqi xətt',
    en: 'Horizontal line',
    ru: 'Горизонтальная линия',
    ar: 'خط أفقي',
  );
  String get fonts =>
      _t(az: 'Şriftlər', en: 'Fonts', ru: 'Шрифты', ar: 'الخطوط');
  String get size => _t(az: 'Ölçü', en: 'Size', ru: 'Размер', ar: 'الحجم');
  String get textColor =>
      _t(az: 'Mətn rəngi', en: 'Text color', ru: 'Цвет текста', ar: 'لون النص');
  String get background =>
      _t(az: 'Arxa fon', en: 'Background', ru: 'Фон', ar: 'الخلفية');

  // ─── Document Options ────────────────────────────────────────────────────────
  String get edit =>
      _t(az: 'Redaktə et', en: 'Edit', ru: 'Редактировать', ar: 'تعديل');
  String get addToFavorites => _t(
    az: 'Favoritə əlavə et',
    en: 'Add to favorites',
    ru: 'В избранное',
    ar: 'إضافة للمفضلة',
  );
  String get removeFromFavorites => _t(
    az: 'Favoritdən çıxar',
    en: 'Remove from favorites',
    ru: 'Убрать из избранного',
    ar: 'إزالة من المفضلة',
  );
  String get delete => _t(az: 'Sil', en: 'Delete', ru: 'Удалить', ar: 'حذف');
  String get cloudSyncActive => _t(
    az: 'Bulud sinxronizasiyası aktiv',
    en: 'Cloud sync active',
    ru: 'Синхронизация активна',
    ar: 'مزامنة السحابة نشطة',
  );
  String get cloudSyncRealtime => _t(
    az: 'Sənədləriniz real vaxtda sinxronizasiya olunur',
    en: 'Your documents sync in real time',
    ru: 'Ваши документы синхронизируются в реальном времени',
    ar: 'تتم مزامنة مستنداتك في الوقت الفعلي',
  );
  String get cloudSignedOut => _t(
    az: 'Bulud bağlı deyil',
    en: 'Cloud is off',
    ru: 'Облако отключено',
    ar: 'السحابة غير متصلة',
  );
  String get cloudSignedOutHint => _t(
    az: 'Giriş edin ki, sənədlər cihazlar arasında sinxron olsun. Offline işləməyə davam edə bilərsiniz.',
    en: 'Sign in to sync documents across devices. You can keep working offline.',
    ru: 'Войдите, чтобы синхронизировать документы. Можно продолжать офлайн.',
    ar: 'سجّل الدخول لمزامنة المستندات بين الأجهزة. يمكنك الاستمرار دون اتصال.',
  );
  String get signIn =>
      _t(az: 'Giriş', en: 'Sign in', ru: 'Войти', ar: 'تسجيل الدخول');
  String get documentsSaved => _t(
    az: 'sənəd saxlanılıb',
    en: 'documents saved',
    ru: 'документов сохранено',
    ar: 'مستندات محفوظة',
  );
  String get noDocumentsFound => _t(
    az: 'Sənəd tapılmadı',
    en: 'No documents found',
    ru: 'Документы не найдены',
    ar: 'لم يتم العثور على مستندات',
  );

  // ─── Navigation ──────────────────────────────────────────────────────────────
  String get navHome => _t(az: 'Ev', en: 'Home', ru: 'Главная', ar: 'الرئيسية');
  String get navDocuments =>
      _t(az: 'Sənədlər', en: 'Documents', ru: 'Документы', ar: 'المستندات');
  String get navTemplates =>
      _t(az: 'Şablonlar', en: 'Templates', ru: 'Шаблоны', ar: 'القوالب');
  String get navSettings =>
      _t(az: 'Parametrlər', en: 'Settings', ru: 'Настройки', ar: 'الإعدادات');

  // ─── Subscription ────────────────────────────────────────────────────────────
  String get subscriptionTitle =>
      _t(az: 'Qiymətlər', en: 'Pricing', ru: 'Тарифы', ar: 'الأسعار');
  String get subscriptionSubtitle => _t(
    az: 'Hər Planda Premium Alətlərdən Zövq Alın',
    en: 'Enjoy Premium Tools in Every Plan',
    ru: 'Наслаждайтесь премиум инструментами',
    ar: 'استمتع بالأدوات المميزة في كل خطة',
  );
  String get mostPopular => _t(
    az: 'Ən Populyar',
    en: 'Most Popular',
    ru: 'Самый популярный',
    ar: 'الأكثر شعبية',
  );
  String get startFree => _t(
    az: 'Pulsuz Başla',
    en: 'Start Free',
    ru: 'Начать бесплатно',
    ar: 'ابدأ مجاناً',
  );
  String get selectPro => _t(
    az: 'Pro Planını Seç',
    en: 'Choose Pro Plan',
    ru: 'Выбрать Pro план',
    ar: 'اختر خطة Pro',
  );
  String get selectElite => _t(
    az: 'Elite Planını Seç',
    en: 'Choose Elite Plan',
    ru: 'Выбрать Elite план',
    ar: 'اختر خطة Elite',
  );
  String get forever =>
      _t(az: 'həmişəlik', en: 'forever', ru: 'навсегда', ar: 'للأبد');
  String get perMonth => _t(az: '/ay', en: '/mo', ru: '/мес', ar: '/شهر');

  // ─── Language Settings ───────────────────────────────────────────────────────
  String get languageLabel =>
      _t(az: 'Dil', en: 'Language', ru: 'Язык', ar: 'اللغة');
  String get selectLanguage => _t(
    az: 'Dil seçin',
    en: 'Select language',
    ru: 'Выберите язык',
    ar: 'اختر اللغة',
  );
  String get languageChanged => _t(
    az: 'Dil dəyişdirildi',
    en: 'Language changed',
    ru: 'Язык изменён',
    ar: 'تم تغيير اللغة',
  );

  // ─── Helper (public for inline translations) ─────────────────────────────────
  String t({
    required String az,
    required String en,
    required String ru,
    required String ar,
  }) => _t(az: az, en: en, ru: ru, ar: ar);

  // ─── Helper ──────────────────────────────────────────────────────────────────
  String _t({
    required String az,
    required String en,
    required String ru,
    required String ar,
  }) {
    switch (_language) {
      case AppLanguage.az:
        return az;
      case AppLanguage.en:
        return en;
      case AppLanguage.ru:
        return ru;
      case AppLanguage.ar:
        return ar;
    }
  }
}

// ─── InheritedWidget ──────────────────────────────────────────────────────────
class _LocalizationsInherited extends InheritedWidget {
  final AppLocalizations localizations;

  const _LocalizationsInherited({
    required this.localizations,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LocalizationsInherited old) => true;
}

class LocalizationsProvider extends StatefulWidget {
  final Widget child;
  const LocalizationsProvider({required this.child, super.key});

  @override
  State<LocalizationsProvider> createState() => _LocalizationsProviderState();
}

class _LocalizationsProviderState extends State<LocalizationsProvider> {
  final AppLocalizations _localizations = AppLocalizations();

  @override
  void initState() {
    super.initState();
    _localizations.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    _localizations.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _LocalizationsInherited(
      localizations: _localizations,
      child: Directionality(
        textDirection: _localizations.textDirection,
        child: widget.child,
      ),
    );
  }
}
