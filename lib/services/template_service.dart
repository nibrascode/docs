class DocTemplate {
  final String id;
  final String title;
  final String description;
  final String content;
  final String emoji;

  const DocTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.emoji,
  });
}

class TemplateService {
  static const List<DocTemplate> all = [
    DocTemplate(
      id: 'blank',
      title: 'Boş sənəd',
      description: 'Sıfırdan başla',
      emoji: '📝',
      content: '',
    ),
    DocTemplate(
      id: 'novel',
      title: 'Roman / povest',
      description: 'Titul, ithaf, mündəricat, fəsillər',
      emoji: '📚',
      content: '''# Kitabın adı

*Müəllifin adı*

--- Page Break ---

# Copyright

© 2026 [Müəllif]. All rights reserved.

--- Page Break ---

# Dedication

Bu kitabı … həsr edirəm.

--- Page Break ---

> “Epiqraf.”
>
> — Müəllif, *Əsər*

--- Page Break ---

[TOC]
# Table of Contents

1. Prologue
2. Chapter 1 — Başlanğıc
3. Chapter 2 — Yüksəliş
4. Chapter 3 — Qovuşma
5. Chapter 4 — Son
6. Epilogue
[/TOC]

--- Page Break ---

# Prologue

Hadisədən əvvəl. Qısa saxla.

--- Page Break ---

# Chapter 1 — Başlanğıc

İlk cümlə oxucunu hadisənin içinə atmalıdır. Personajı, yeri və istəyi göstər.

* * *

Səhnə dəyişir.

# Chapter 2 — Yüksəliş

Münaqişəni artır. Hər fəsil bir sual və ya seçimlə bitsin.

# Chapter 3 — Qovuşma

Dönüş nöqtəsi. Personajın ödəyəcəyi qiymət aydın olsun.

# Chapter 4 — Son

Hekayəni bağla. Son şəkil oxucunun yaddaşında qalsın.

--- Page Break ---

# Epilogue

Hekayədən sonra.

--- Page Break ---

# Acknowledgements

Bu kitabı mümkün edənlərə.

--- Page Break ---

# About the Author

[Müəllif] …
''',
    ),
    DocTemplate(
      id: 'nonfiction',
      title: 'Qeyri-bədii kitab',
      description: 'Giriş, fəsillər, cədvəl, mənbə',
      emoji: '📖',
      content: '''# Kitabın adı

*Müəllifin adı*

--- Page Break ---

# Preface

Niyə bu kitabı yazırsan və oxucu nə öyrənəcək.

--- Page Break ---

[TOC]
# Table of Contents

1. Introduction
2. Chapter 1
3. Chapter 2
4. Conclusion
[/TOC]

--- Page Break ---

# Introduction

Mövzunu və əsas iddianı bir paraqrafda de.

# Chapter 1 — Problem

Faktlar. Nümunələr.

[TABLE]
| Mənbə | İl | Nəticə |
| --- | --- | --- |
|  |  |  |
|  |  |  |
[CAP] Cədvəl 1. Əsas mənbələr
[/TABLE]

# Chapter 2 — Həll

Təklifini addımlarla yaz.

# Conclusion

Oxucunun aparacağı 3 hərəkət.

# Notes

[^1]: Mənbə / izah.
''',
    ),
    DocTemplate(
      id: 'memoir',
      title: 'Memuar',
      description: 'Xatirə və səhnələr',
      emoji: '🪶',
      content: '''# Memuarın adı

*Müəllifin adı*

--- Page Break ---

# Chapter 1 — Uşaqlıq

Bir konkret səhnədən başla: qoxu, səs, yer.

* * *

# Chapter 2 — Dönüş

Həyatın dəyişdiyi gün.

# Chapter 3 — İndi

Bu xatirənin bu gün sənə nə dediyi.
''',
    ),
    DocTemplate(
      id: 'poetry',
      title: 'Şeir toplusu',
      description: 'Bölmələr və şeirlər',
      emoji: '🌙',
      content: '''# Toplunun adı

*Şair*

--- Page Break ---

# I. Birinci bölmə

## Şeir 1

Sətir
Sətir

--- Page Break ---

## Şeir 2

Sətir
Sətir
''',
    ),
    DocTemplate(
      id: 'short_story',
      title: 'Qısa hekayə',
      description: 'Açılış, dönüş, son — bir oturuma',
      emoji: '🕯️',
      content: '''# Hekayənin adı

*Müəllifin adı*

İlk cümlə oxucunu hadisənin içinə atmalıdır. Kim, harada, nə istəyir.

Personajın qiyməti bu səhifədə görünməlidir.

* * *

Orta. Seçim. Geri dönüş yoxdur.

* * *

Son şəkil. Bir cümlə yadda qalsın.
''',
    ),
    DocTemplate(
      id: 'children',
      title: 'Uşaq kitabı',
      description: 'Qısa cümlələr, təkrar ritm, 8–12 səhifə',
      emoji: '🎈',
      content: '''# Nağılın adı

*Müəllifin adı*

--- Page Break ---

# 1. Səhər

Qısa cümlələr. Bir ideya. Təkrarlanan ritm.

--- Page Break ---

# 2. Problem

Nə pozuldu? Uşaq qəhrəman özü həll etməlidir.

--- Page Break ---

# 3. Cəhd

Birinci cəhd alınmır. İkinci cəhddə dost / hiylə.

--- Page Break ---

# 4. Evə dönüş

Eyni yer, amma qəhrəman dəyişib. Son sətir səsli oxunanda yaxşı səslənsin.
''',
    ),
    DocTemplate(
      id: 'novella',
      title: 'Novella',
      description: 'Qısa roman: 3 fəsil, tək xətt',
      emoji: '📕',
      content: '''# Novella adı

*Müəllifin adı*

--- Page Break ---

# Copyright

© 2026 [Müəllif]. All rights reserved.

--- Page Break ---

# Fəsil 1 — Çağırış

Tək xətt. Tək POV. İlk 800 sözdə istək və maneə.

# Fəsil 2 — Qiymət

Hər səhnə əvvəlkindən baha başa gəlsin.

# Fəsil 3 — Qərar

Son seçim geriyə yol buraxmasın.

--- Page Break ---

# Epilogue

Bir səhifə. Hekayədən sonra.
''',
    ),
    DocTemplate(
      id: 'bible',
      title: 'Yazıçı dəftəri',
      description: 'Personaj, məkan, xronologiya, səhnə',
      emoji: '🗂️',
      content: '''# Yazıçı dəftəri — [Kitab]

Bu səhifələr kitaba daxil olmur; plan üçündür. Əsas mətni ayrı sənəddə yaz.

# Personajlar

[TABLE]
| Ad | Rol | İstək | Qüsur | Qeyd |
| --- | --- | --- | --- | --- |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
[CAP] Personajlar
[/TABLE]

# Məkanlar

[TABLE]
| Məkan | Tip | Əhval | Kimlər | Qeyd |
| --- | --- | --- | --- | --- |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
[CAP] Məkanlar
[/TABLE]

# Xronologiya

[TABLE]
| Tarix / sıra | Hadisə | Kim | Nəticə |
| --- | --- | --- | --- |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
|  |  |  |  |
[CAP] Xronologiya
[/TABLE]

# Səhnə siyahısı

[TABLE]
| Fəsil | Səhnə | POV | Məqsəd | Konflikt | Nəticə |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 |  |  |  |  |
| 1 | 2 |  |  |  |  |
| 2 | 1 |  |  |  |  |
[CAP] Səhnə siyahısı
[/TABLE]

# Akt planı

## Act I — Başlanğıc
- 

## Act II — Yüksəliş
- 

## Act III — Qovuşma
- 
''',
    ),
    DocTemplate(
      id: 'article',
      title: 'Məqalə',
      description: 'Başlıq, giriş, mətn, nəticə',
      emoji: '📰',
      content:
          '# Məqalənin başlığı\n\n## Giriş\n\nOxucunu tutan qısa giriş.\n\n## Əsas hissə\n\nFikirləri paraqraflarla inkişaf etdir.\n\n## Nəticə\n\nƏsas məqamları yekunlaşdır.',
    ),
    DocTemplate(
      id: 'letter',
      title: 'Məktub',
      description: 'Rəsmi məktub quruluşu',
      emoji: '✉️',
      content:
          '[Adınız]\n[Ünvan]\n[Şəhər]\n[Tarix]\n\n[Alıcı]\n[Ünvan]\n\nHörmətli [Ad],\n\n...\n\nHörmətlə,\n[Adınız]',
    ),
    DocTemplate(
      id: 'report',
      title: 'Hesabat',
      description: 'Strukturlaşdırılmış hesabat',
      emoji: '📊',
      content:
          '# Hesabatın adı\n\n## 1. Xülasə\n\nQısa nəticə.\n\n## 2. Giriş\n\nMəqsəd.\n\n## 3. Tapıntılar\n\n[TABLE]\n| Maddə | Status | Qeyd |\n| --- | --- | --- |\n|  |  |  |\n|  |  |  |\n[/TABLE]\n\n## 4. Tövsiyələr\n\nNövbəti addımlar.\n\n## 5. Nəticə\n',
    ),
    DocTemplate(
      id: 'notes',
      title: 'Görüş qeydləri',
      description: 'Gündəlik və tapşırıqlar',
      emoji: '📋',
      content:
          '# Görüş — [Tarix]\n\n**İştirakçılar:**\n- \n\n**Gündəlik:**\n1. \n2. \n\n**Qərarlar:**\n\n**Tapşırıqlar:**\n- [ ] İş — Məsul — Tarix\n',
    ),
  ];
}
