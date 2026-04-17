# Hướng dẫn chạy Flutter với các môi trường (Dev, Staging, Prod)

Dự án này được phân tách môi trường bằng các file entry (đầu vào) khác nhau: `main_dev.dart`, `main_staging.dart`, và `main_prod.dart`. Tương ứng với mỗi bản build, ứng dụng sẽ nap các cấu hình và môi trường phù hợp (như base URL, debug log, v.v.).

Dưới đây là các lệnh cần thiết để chạy và build cho từng môi trường:

---

## 1. Lệnh chạy Debug (Khi đang Code)

Để chạy app mà vẫn giữ được tính năng Hot-Reload trực tiếp trên thiết bị/máy ảo, bạn sử dụng lệnh `flutter run` kèm theo cờ `-t` (target) để trỏ đến file môi trường tương ứng:

### 🐛 Development (Dev)
*Sử dụng trong khi phát triển, gọi đến server dev hoặc mock APIs, hiển thị đầy đủ log.*
```bash
flutter run --flavor dev -t lib/main_dev.dart
```

### 🧪 Staging (Stage)
*Môi trường dùng cho QA/Tester hoặc khách hàng trải nghiệm trước khi phát hành (có cùng tính chất với Prod).*
```bash
flutter run --flavor staging -t lib/main_staging.dart
```

### 🚀 Production (Prod)
*Môi trường thực tế, trỏ tới server thật được sử dụng bởi end-users. (Log debug thường bị tắt ở môi trường này).*
```bash
flutter run --flavor prod -t lib/main_prod.dart
```

---

## 2. Lệnh Build Ứng dụng (Tạo APK / AAB / IPA)

Khi cần xuất file ứng dụng (.apk, .ipa) để cài trực tiếp hoặc upload lên Store:

### 🤖 Build cho nền tảng Android

**Build APK (thường dùng để test cài thủ công và chia sẻ file):**
- Dev:
  ```bash
  flutter build apk --flavor dev -t lib/main_dev.dart --debug
  ```
- Staging:
  ```bash
  flutter build apk --flavor staging -t lib/main_staging.dart --release
  ```
- Prod (Release):
  ```bash
  flutter build apk --flavor prod -t lib/main_prod.dart --release
  ```

**Build AppBundle (AAB) (Dùng để upload lên Google Play Store):**
```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart --release
```

### 🍎 Build cho nền tảng iOS (Cần chạy trên MacOS)

**Build IPA gốc (Đẩy lên TestFlight hoặc App Store):**
```bash
flutter build ipa --flavor prod -t lib/main_prod.dart --release
```

---

## 3. Chạy qua VS Code (Cấu hình Launch)

Nếu bạn không muốn phải tự gõ các lệnh trên trong Terminal, bạn có thể thiết lập sẵn để chạy bằng nút F5 trực tiếp trong VS Code.

Cách làm: Tạo hoặc chỉnh sửa file ở đường dẫn `.vscode/launch.json` với cấu hình sau:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "⭐ Flutter: Run Dev",
            "request": "launch",
            "type": "dart",
            "program": "lib/main_dev.dart",
            "args": ["--flavor", "dev"]
        },
        {
            "name": "🧪 Flutter: Run Staging",
            "request": "launch",
            "type": "dart",
            "program": "lib/main_staging.dart",
            "args": ["--flavor", "staging"]
        },
        {
            "name": "🚀 Flutter: Run Prod",
            "request": "launch",
            "type": "dart",
            "program": "lib/main_prod.dart",
            "args": ["--flavor", "prod"]
        }
    ]
}
```
**Cách sử dụng**: Mở menu **Run & Debug** (phím tắt `Ctrl + Shift + D` hoặc `Cmd + Shift + D`), sau đó kéo chọn môi trường ở ô thả xuống trên cùng, và nhấn nút tam giác màu xanh (▶) để chạy trực tiếp.
