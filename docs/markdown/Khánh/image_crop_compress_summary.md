# Tính năng Cắt ảnh (Crop) & Nén ảnh (Compress) — Tổng kết

## Pipeline mới: Pick → Crop → Compress → Upload → OCR + Translate

```mermaid
flowchart LR
    A["📷 Pick Image"] --> B["✂️ Crop UI"]
    B -->|"User confirms"| C["🗜️ Compress"]
    B -->|"User cancels"| C
    C -->|"> 1.5MB"| D["flutter_image_compress"]
    C -->|"≤ 1.5MB"| E["📤 Upload"]
    D --> E
    E --> F["🔍 OCR + Translate"]
```

## Files Modified / Created

| File | Action | Description |
|------|--------|-------------|
| [image_crop_service.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/core/image_picker/image_crop_service.dart) | ✅ Created | Abstract interface + `ImageCropServiceImpl` wrapping `image_cropper` |
| [image_picker_service.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/core/image_picker/image_picker_service.dart) | ✏️ Modified | Added `filePath` to `PickedImageData` (needed by crop service) |
| [ocr_state.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/ocr/presentation/bloc/ocr_state.dart) | ✏️ Modified | Added `OcrImagePicked` state for crop-ready phase |
| [ocr_cubit.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/ocr/presentation/bloc/ocr_cubit.dart) | ✏️ Modified | Integrated crop step between pick and compress |
| [ocr_page.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/ocr/presentation/pages/ocr_page.dart) | ✏️ Modified | Pass `themeData`, handle `OcrImagePicked` state |
| [injection_container.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/injection_container.dart) | ✏️ Modified | Register `ImageCropService` + inject into `OcrCubit` |
| [pubspec.yaml](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/pubspec.yaml) | ✏️ Modified | Added `image_cropper: ^8.0.2` |
| [AndroidManifest.xml](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/android/app/src/main/AndroidManifest.xml) | ✏️ Modified | Added `UCropActivity` for crop UI |

## Architecture Compliance

> [!TIP]
> All changes follow Clean Architecture — plugin dependencies are wrapped behind abstract interfaces in `core/`, keeping Cubits and UseCases framework-agnostic.

- **`ImageCropService`** (abstract) → `ImageCropServiceImpl` (wraps `image_cropper`)
- **`ImageCompressService`** (abstract) → `ImageCompressServiceImpl` (wraps `flutter_image_compress`)
- Both injected via **get_it** DI container into `OcrCubit`
- No direct plugin imports in Cubit or Domain layers

## Key Design Decisions

1. **Crop is optional** — if user cancels the crop UI, the original image proceeds through compression → upload
2. **Compression threshold**: images > 1.5 MB are compressed with `quality: 80` to stay under the 5 MB server limit (§7.2)
3. **Theme-aware crop UI** — the crop screen adapts to the app's current theme (colors, toolbar)
4. **UCrop on Android** — requires `UCropActivity` in `AndroidManifest.xml`
5. **`filePath`** added to `PickedImageData` because `image_cropper` operates on file paths, not byte arrays

## Analysis Result

```
flutter analyze → No issues found! ✅
```
