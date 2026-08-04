# سايس الخيل — مشروع Android الجديد

هذا هو المشروع المستقل الجديد لتطبيق **سايس الخيل** وصفحة تنزيله. أُنشئ في:

`C:\Users\Test2\OneDrive\Pictures\HorseManager\android`

المشروع المرجعي `mbail` استُخدم لفهم تنظيم مشروع Android وصفحة التسليم فقط. لا يحتوي هذا المشروع على أي كود أو قاعدة بيانات أو مفتاح توقيع من المشروع المرجعي.

## محتويات المشروع

- `lib/`: جميع وحدات سايس الخيل الوظيفية.
- `android/`: مشروع Android/Gradle الأصلي.
- `assets/`: الأيقونات والصور والخط والصوت المستخدم داخل التطبيق.
- `releases/Sayes-Alkhayl-v2.1.1-universal.apk`: ملف Android العالمي المنشور للتحميل، بهوية ثابتة `com.abuammar.sayesalkhayl.mobile2026` وتوقيع Release رسمي.
- `index.html` و`style.css` و`script.js`: صفحة التنزيل الدعائية الجديدة.
- `web_assets/`: صور صفحة الويب فقط.
- `test/` و`integration_test/`: اختبارات الوظائف والترابط.

## الوظائف المنقولة

- ملفات الخيول والصور والصحة والعلاج والإيواء والغرف والتحذية واليومية والتمارين والمواعيد والمصروفات والخط الزمني.
- المشتركون وVIP وسجل الاشتراكات والتجديد والدفعات والخيل والعقود والسجل المالي.
- الحجوزات اليومية والخدمات والأسعار والإيصالات.
- الوارد والمصروف والديون ودفعات الإيواء والعلاج والسجل المالي المركزي.
- التنبيهات داخل التطبيق وخارجه وملء الشاشة وجرس التنبيهات وصوت `jrs.mp3`.
- التقارير العامة وملف العضو وملف الخيل مع الصور وPDF والطباعة والمشاركة.
- العقود والتوقيع الإلكتروني والشعار والختم.
- النسخ الاحتياطي والاستعادة مع فحص سلامة SQLite.
- إعدادات هوية النادي والأسعار والخدمات والعقد والتنبيهات.

## البناء المحلي

يجب استخدام مفتاح JKS نفسه لجميع التحديثات. المفتاح وكلمات المرور محفوظة خارج
المستودع، ويدعم Gradle أيضًا نموذج `android/key.properties.example` عند تجهيز
بيئة إصدار أخرى.

يبني الأمر التالي المشروع من مجلد مؤقت بحروف ASCII، ثم ينفذ بالتسلسل:
`flutter clean` و`flutter pub get` و`flutter analyze` و`flutter test` وأخيرًا
`flutter build apk --release` دون `--split-per-abi` لإنتاج ملف واحد يدعم
ARM32 وARM64 وx86_64:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_android_apk.ps1 `
  -OutputName "Sayes-Alkhayl-v2.1.1-universal.apk"
```

الناتج:

`releases\Sayes-Alkhayl-v2.1.1-universal.apk`

يحدّث السكربت `releases/SHA256SUMS.txt` ويشغّل الفاحص الشامل تلقائيًا. ويمكن
إعادة تشغيل الفحص مستقلًا:

```powershell
powershell -ExecutionPolicy Bypass -File .\releases\verify-apk.ps1
```

يفحص الفاحص البصمة والحزمة والإصدار ومعماريات Flutter القابلة للتشغيل وتوقيع v2 وشهادة
التحديث وRelease/Debug والنسخ الاحتياطي والاتصال المشفر وأذونات التنبيه
وملء الشاشة وzipalign وحجم الملف.

مجرد ظهور `x86` في ناتج `aapt` لا يثبت دعم الجهاز ما لم توجد له مكتبتا
`libapp.so` و`libflutter.so`. إصدار Flutter الحالي لا يبني Release لـx86 ذي
32 بت؛ لذلك يتحقق السكربت من ARM32 وARM64 وx86_64 الفعلية بدل إعلان دعم غير
قابل للتشغيل.

## اختبار وبناء صفحة الويب

```powershell
npm install
npm run test:web
npm run build
```

يشغّل البناء اختبارات التوزيع العشرة ثم ينتج `dist/`. يرفض البناء وجود أي APK
داخل ناتج الموقع.

## صفحة التنزيل

ينشر سير GitHub Pages الملفات التالية فقط:

- `index.html`
- `style.css`
- `script.js`
- `web_assets/`

لا يدخل ملف APK الكبير في بناء الموقع. تستخدم جميع أزرار Android رابط GitHub
Raw المباشر للملف المرفوع فعليًا إلى فرع `main`:

```text
https://github.com/yasser-dev2024/saishours2026/raw/refs/heads/main/releases/Sayes-Alkhayl-v2.1.1-universal.apk
```

عند إصدار تحديث يجب زيادة `versionName` و`versionCode` معًا، واستخدام JKS
نفسه، وإعادة البناء والفحص، ثم رفع APK و`SHA256SUMS.txt` وتحديث رابط Raw
واختبارات الويب قبل النشر.

الرابط العام:

https://yasser-dev2024.github.io/saishours2026/
