# NutriMind — иконка N с листьями

Выбран второй вариант с лёгким сатиновым объёмом. Для установки макет подготовлен
как квадрат без светлой рамки и заранее скруглённых углов. Системную маску применяет
iOS или Android. Использован встроенный imagegen, без внешнего CLI/API.

- `flutter_app/assets/branding/nutrimind-icon-source.png`: исходник рабочего изображения.
- `flutter_app/assets/branding/nutrimind-icon.png`: непрозрачный RGB-мастер 1024×1024.
- `flutter_app/assets/branding/nutrimind-mark.png`: 128×128 для шапки, отображение 32×32.
- iOS: размеры из `AppIcon.appiconset/Contents.json`; все PNG RGB без alpha.
- Android: legacy mipmap 48/72/96/144/192 и adaptive icon для API 26+.

Финальный запрос к imagegen, с выбранным вариантом Б в качестве edit target:

> Production asset preparation, precise image edit. The reference is the APPROVED NutriMind icon. Preserve the EXACT green botanical N, its silhouette, leaf slits, color, delicate satin highlight and shallow relief shadow. Do not redesign or embellish. Deliver ONLY the icon artwork as a square FULL-BLEED native app-icon master: remove all ivory surrounding presentation background, remove external tile cast shadow, remove pre-rounded tile corners. Extend the original deep forest-green tile color to ALL FOUR square canvas corners and every edge. No border, no margins outside the artwork, no rounded-square mask: iOS and Android apply their own masks. Center the approved N with optical padding, its full bounding box about 62% of canvas width and height. Preserve original internal forest-green background atmosphere, subtle and almost flat. This is a flat front-on square image file filling the whole canvas, not an icon mockup on a surface. No text, no watermark, no transparency.

Размеры экспортированы через macOS `sips -z HEIGHT WIDTH SOURCE --out DESTINATION`.
Оригинальное изображение для распознавания блюд к этим ресурсам отношения не имеет.
