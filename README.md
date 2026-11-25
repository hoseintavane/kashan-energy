# انرژی کاشان - نسخه ۲ (Flutter، اندروید ۷+)

## ساخت APK
مثل قبل: محتوای پوشه را در GitHub بگذارید و Actions > Build APK را اجرا کنید.

## یک‌بار تنظیم امضای ثابت (برای اینکه به‌روزرسانی اطلاعات را پاک نکند)
```
keytool -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
base64 -w0 debug.keystore
```
خروجی را در GitHub > Settings > Secrets > Actions با نام `DEBUG_KEYSTORE_B64` ذخیره کنید و فایل keystore را جای امن نگه دارید.
نسخه‌ی ۲ با امضای نسخه‌ی قبلی (که هر بار یک کلید موقت داشت) سازگار نیست؛ برای نصب باید نسخه‌ی قدیمی حذف شود (داده‌ی قدیمی فقط نمونه بود).

## ورود
- کاربر: ثبت‌نام از داخل برنامه.
- مدیر: تب «مدیریت»؛ فقط رمز (هش PBKDF2 داخل کد، نه متن ساده).

## داده
هیچ داده‌ی نمونه‌ای نیست. تمام آمار از قرائت‌های کنتوری که کاربر ثبت می‌کند محاسبه می‌شود و بدون داده، پیام «داده‌ای ثبت نشده» نمایش داده می‌شود.
