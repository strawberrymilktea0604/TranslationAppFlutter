# Fix Vocabulary UI — Save Dialog & Sync Status Icons

## Tóm tắt thay đổi

Hai nhóm thay đổi chính trên tầng Presentation của feature `vocabulary`:

1. **Dialog lưu từ vựng** — Tách "tạo danh mục mới" ra nút riêng; nút "Lưu" chỉ được bật khi đã chọn danh mục.
2. **Icon trạng thái offline/synced** — Hiển thị icon `cloud_off` (offline) / `cloud_done` (đã đồng bộ) trên các card: Lịch sử dịch, Danh mục từ vựng, và Từ vựng đã lưu.

---

## Proposed Changes

### Feature: vocabulary — Widget dialog

#### [MODIFY] [save_vocabulary_dialog.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/vocabulary/presentation/widgets/save_vocabulary_dialog.dart)

Hiện tại dialog có TextField inline để tạo danh mục mới, và nút Lưu luôn bật.

**Thay đổi:**
- Xóa TextField inline "Tạo danh mục mới" khỏi content.
- Thêm `TextButton` hoặc `OutlinedButton` **"+ Tạo danh mục"** riêng bên cạnh danh sách chip — khi nhấn sẽ mở một AlertDialog phụ để nhập tên rồi gọi `cubitCategory.createCategory(name)`, sau đó reload danh sách chip.
- Nút **"Lưu"** (`FilledButton`) được disable (`onPressed: null`) khi `selectedCategoryId == null && selectedCategoryName == 'Chưa phân loại'` (tức là chưa chọn chip nào).

Logic enable/disable dùng `StatefulBuilder` đã có sẵn — chỉ cần truyền `onPressed: isCategorySelected ? () { ... } : null`.

---

### Feature: vocabulary — saved_vocab_tab.dart

#### [MODIFY] [saved_vocab_tab.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/vocabulary/presentation/pages/saved_vocab_tab.dart)

**Thay đổi trong `_CategoryCard`:**
- Thêm icon `cloud_off_outlined` (màu mờ) khi `category.isSynced == false`.
- Thêm icon `cloud_done` (màu primary) khi `category.isSynced == true`.
- Icon đặt trong `Row` tiêu đề hoặc trailing nhỏ phía bên phải tên danh mục.

**Thay đổi trong `_CategoryDetailScreen` (list từ vựng):**
- Trong `ListTile` của mỗi từ vựng, thêm icon trạng thái `isSynced`:
  - `cloud_off_outlined` khi chưa sync
  - `cloud_done` khi đã sync

---

### Feature: vocabulary — vocabulary_page.dart (HistoryCard)

#### [MODIFY] [vocabulary_page.dart](file:///c:/Users/minhk/Downloads/TranslationAppFlutter/frontend/lib/features/vocabulary/presentation/pages/vocabulary_page.dart)

Hiện tại `_HistoryCard` đã có icon `cloud_off_outlined` khi `!entry.isSynced`. Cần bổ sung thêm icon `cloud_done` khi `entry.isSynced == true` để trạng thái luôn hiển thị rõ ràng (không chỉ hiển thị khi offline).

---

## Verification Plan

### Manual Check
- Mở dialog lưu từ vựng: nút "Lưu" phải bị disable khi chưa chọn chip.
- Nhấn "+ Tạo danh mục": dialog phụ xuất hiện, nhập tên → danh sách chip refresh, nút "Lưu" được enable khi chip mới được auto-select.
- Kiểm tra icon trạng thái trên card Danh mục và từ vựng trong danh mục.
- Kiểm tra icon trạng thái đã sync trên card Lịch sử dịch.

### Build
```
flutter analyze
flutter build apk --debug
```
