# Google Play release: TunnelCore VPN

## App identity

- Display name: `TunnelCore VPN`.
- Google Play package ID (`applicationId`): `com.vnextdev.tunnelcorevpn`.
- Android Kotlin/Java `namespace`: `org.amnezia.vpn` (intentionally unchanged: it is **not** the Play package ID).
- The app remains free to install; access to TunnelCore VPN can depend on subscription entitlement.

The package ID is reserved in the VNext Development Google Play Console. **Do not change it after the first upload** or the app will be treated as a different app.

The previous `com.tunnelcore.vpn` ID is not an upgrade path to the Play listing. APKs installed with that ID are separate Android apps; they cannot be updated in place by the new Play package. Plan migration/support messaging for existing sideloaded APK users.

Two source values must stay synchronized:

1. `client/android/build.gradle.kts`: `defaultConfig.applicationId` (actual Android package).
2. `client/cmake/branding/android.cmake`: `CLIENT_ANDROID_PACKAGE` (the store/package lookup identifier shown by the C++ client).

GitHub Actions checks these values in Android PR CI and in the Play release workflow. Do **not** rename `org.amnezia.vpn` Kotlin/Java packages as part of this app ID change; that requires a separate migration.

## Build an Android App Bundle for Google Play

Run the **Android Play Release** workflow (`.github/workflows/android-play-release.yml`) from the intended commit/branch. It builds the `play` flavor with `--play --aab --sign` and uploads a `TunnelCoreVPN-Android-Play-AAB` artifact.

The workflow requires these GitHub Actions secrets to be configured securely:

- `ANDROID_RELEASE_KEYSTORE_BASE64`
- `ANDROID_RELEASE_KEYSTORE_PASSWORD`
- `ANDROID_RELEASE_KEY_ALIAS`

Use the **upload key** intended for Google Play App Signing, keep the keystore backed up, and never commit keys or passwords. The workflow checks that both ARM64 and x86_64 native libraries are present. APK artifacts produced by standard PR CI are for testing, not for uploading as the Play App Bundle.

## Before requesting public release

- Confirm Google Play organization/representative verification is completed.
- Upload the signed Play AAB to **Internal testing** first and install it from Google Play.
- Verify sign-in, VPN permission/connectivity, subscription entitlement, and upgrade/reinstall behavior.
- Complete the VPN Service declaration and app content forms (Data safety, privacy policy, content rating, target audience, screenshots, store listing).
- Check the **Play** flavor's subscription/purchase flow against current Google Play payments rules. The Android client currently uses a consumption-only flow and must not route users to an external payment website or bot from within the Play app where that would violate Google Play policy.
- Verify app signing certificate fingerprints if any backend/auth integrations bind their identity to the signing certificate.

## Release notes for the next Google Play build (after PR #31)

User-facing notes for the Android release containing the October 28, 2026 changes.
Translations cover all **13 languages in `LanguageSettings::AvailableLanguageEnum`**
(including English). Each translation is also available as a separate plain-text
file under `docs/google-play-release-notes/` for convenient copying.

**Important:** the application's Qt language list and the locales enabled in
Google Play Console are not necessarily identical. Use the corresponding Play
Console locale if available; do not assume every `xx-YY` code can be entered
unchanged. The separate files are not uploaded to Google Play automatically.
Upload and test the new AAB before publishing these release notes.

### en-US — English

`docs/google-play-release-notes/en-US.txt`

Improved interface layout on Android 15 and 16, including system bars and display cutouts.
Improved remote navigation and focus highlighting on Android TV.
Fixed interface issues and improved stability.

### ru-RU — Русский

`docs/google-play-release-notes/ru-RU.txt`

Улучшено отображение интерфейса на Android 15 и 16, включая системные панели и вырезы экрана.
На Android TV улучшены навигация с пульта и подсветка выбранных элементов.
Исправлены ошибки интерфейса и повышена стабильность работы.

### zh-CN — 简体中文

`docs/google-play-release-notes/zh-CN.txt`

优化了 Android 15 和 16 上的界面显示，包括系统栏和屏幕缺口区域。
改进了 Android TV 遥控器导航和选中项高亮显示。
修复了界面问题并提升了应用稳定性。

### uk-UA — Українська

`docs/google-play-release-notes/uk-UA.txt`

Покращено відображення інтерфейсу на Android 15 і 16, зокрема біля системних панелей та вирізів екрана.
Покращено навігацію пультом і підсвічування вибраних елементів на Android TV.
Виправлено помилки інтерфейсу та підвищено стабільність роботи.

### fa-IR — فارسی

`docs/google-play-release-notes/fa-IR.txt`

نمایش رابط کاربری در اندروید ۱۵ و ۱۶، از جمله در اطراف نوارهای سیستم و بریدگی‌های صفحه‌نمایش، بهبود یافته است.
پیمایش با کنترل از راه دور و برجسته‌سازی گزینه‌های انتخاب‌شده در Android TV بهبود یافته است.
اشکالات رابط کاربری برطرف شده و پایداری برنامه افزایش یافته است.

### ar-EG — العربية

`docs/google-play-release-notes/ar-EG.txt`

تحسين عرض الواجهة على Android 15 و16، بما في ذلك المناطق المحيطة بأشرطة النظام وفتحات الشاشة.
تحسين التنقل باستخدام جهاز التحكم عن بُعد وإبراز العنصر المحدد على Android TV.
إصلاح مشكلات الواجهة وتحسين استقرار التطبيق.

### my-MM — မြန်မာဘာသာ

`docs/google-play-release-notes/my-MM.txt`

Android 15 နှင့် 16 တွင် စနစ်ဘားများ၊ မျက်နှာပြင်အပေါက်များအနီးရှိ ပြသမှုကို ပိုကောင်းအောင် ပြုပြင်ထားသည်။
Android TV တွင် အဝေးထိန်းခလုတ်ဖြင့် သွားလာမှုနှင့် ရွေးထားသောအရာကို ပြသမှုကို မြှင့်တင်ထားသည်။
အင်တာဖေ့စ်အမှားများကို ပြုပြင်ပြီး တည်ငြိမ်မှုကို မြှင့်တင်ထားသည်။

### ur-PK — اردو

`docs/google-play-release-notes/ur-PK.txt`

Android 15 اور 16 پر انٹرفیس کی نمائش بہتر بنائی گئی ہے، بشمول سسٹم بارز اور اسکرین کے کٹ آؤٹس کے آس پاس کے حصے۔
Android TV پر ریموٹ سے نیویگیشن اور منتخب عناصر کی نمایاں نشاندہی بہتر کی گئی ہے۔
انٹرفیس کی خرابیاں دور کی گئی ہیں اور ایپ کے استحکام کو بہتر بنایا گیا ہے۔

### hi-IN — हिन्दी

`docs/google-play-release-notes/hi-IN.txt`

Android 15 और 16 पर इंटरफ़ेस का प्रदर्शन बेहतर किया गया है, जिसमें सिस्टम बार और स्क्रीन कटआउट के आसपास का क्षेत्र भी शामिल है।
Android TV पर रिमोट से नेविगेशन और चुने गए विकल्पों की हाइलाइटिंग बेहतर की गई है।
इंटरफ़ेस की समस्याएँ ठीक की गई हैं और स्थिरता बढ़ाई गई है।

### es-ES — Español

`docs/google-play-release-notes/es-ES.txt`

Se ha mejorado la visualización de la interfaz en Android 15 y 16, incluidas las barras del sistema y los recortes de pantalla.
Se ha mejorado la navegación con el mando y el resaltado de los elementos seleccionados en Android TV.
Se han corregido errores de la interfaz y mejorado la estabilidad.

### ko-KR — 한국어

`docs/google-play-release-notes/ko-KR.txt`

Android 15 및 16에서 시스템 표시줄과 화면 컷아웃 주변의 UI 표시를 개선했습니다.
Android TV에서 리모컨 탐색과 선택 항목 강조 표시를 개선했습니다.
인터페이스 오류를 수정하고 안정성을 높였습니다.

### fr-FR — Français

`docs/google-play-release-notes/fr-FR.txt`

Amélioration de l’affichage de l’interface sur Android 15 et 16, notamment autour des barres système et des découpes de l’écran.
Navigation à la télécommande et mise en évidence des éléments sélectionnés améliorées sur Android TV.
Correction de problèmes d’interface et amélioration de la stabilité.

### tr-TR — Türkçe

`docs/google-play-release-notes/tr-TR.txt`

Android 15 ve 16'da sistem çubukları ve ekran çentikleri çevresindeki arayüz görünümü iyileştirildi.
Android TV'de kumandayla gezinme ve seçili öğelerin vurgulanması iyileştirildi.
Arayüz hataları giderildi ve uygulamanın kararlılığı artırıldı.

