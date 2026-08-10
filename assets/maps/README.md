# موتور نقشه اورجینال بازی

نقشه بازی دیگر یک تصویر یا SVG ثابت نیست. فایل `data/world_polygons.json` شامل چندضلعی‌های ساده‌شده ۱۹۵ کشور است و `GeographyManager` و `world_map.gd` آن‌ها را مستقیماً رسم، رنگ‌گذاری و Hit-test می‌کنند.

هندسه پایه از **Natural Earth 1:50m Admin-0 Countries**، داده عمومی (Public Domain)، گرفته شده و با `tools/build_world_map.py` به فرمت اختصاصی بازی تبدیل شده است:

- منبع: https://github.com/nvkelso/natural-earth-vector
- شرایط استفاده: https://www.naturalearthdata.com/about/terms-of-use/
- خروجی اختصاصی: چندضلعی، حفره، ISO3، ساده‌سازی چندمقیاسی و Web Mercator زمان اجرا

سبک بصری، رنگ لایه‌ها، موتور انتخاب کشور، زوم منطقه‌ای، مسیرها، گلوگاه‌ها و رندر کاملاً متعلق به پروژه است. هیچ CDN، Tile Server یا API نقشه در زمان اجرا لازم نیست.
