# Tích hợp Continuous Recorder Bản Đầu

Tính năng này sẽ chuyển luồng xử lý từ "push-to-talk" (nhấn để ghi âm, nhấn lần nữa để dừng) sang "ghi âm liên tục" (continuous recording). Audio sẽ được ghi và đẩy liên tục lên WebSocket trong suốt thời gian diễn ra phiên hội thoại.

## User Review Required
> [!IMPORTANT]
> - Luồng sử dụng (UX) sẽ thay đổi: Người dùng sẽ nhấn nút **"Bắt đầu hội thoại"** một lần, sau đó ứng dụng sẽ **liên tục ghi âm** và dịch. Người dùng chỉ cần sử dụng nút đổi loa (Speaker Toggle) khi chuyển lượt nói, và nhấn nút **"Kết thúc"** khi muốn dừng toàn bộ phiên.
> - Xin cấp quyền Microphone sẽ được thực hiện ngay khi bắt đầu phiên hội thoại.

## Proposed Changes

### `frontend/lib/features/conversation/presentation/bloc/conversation_cubit.dart`
Quản lý vòng đời ghi âm tự động gắn liền với vòng đời của Session.
- **[MODIFY]** `startSession`: Cập nhật logic, khi gọi sẽ phát ra event bắt đầu session qua WebSocket.
- **[MODIFY]** `_handleEvent`: Khi nhận được event `ConversationSessionStarted`, tự động gọi `startListening()` để bắt đầu ghi âm ngay lập tức.
- **[MODIFY]** `endSession`: Tự động gọi `stopListening()` và giải phóng recorder trước khi gửi event endSession lên backend.
- **[MODIFY]** `disconnect` & `close`: Đảm bảo `AudioRecorderService` được `dispose` (hoặc stop) một cách an toàn. (Thực tế hiện tại đã có, sẽ review lại để đảm bảo triệt để).
- **[MODIFY]** Bỏ việc `stopListening` phát ra state `ConversationProcessing` (hoặc giữ lại tùy thuộc vào việc UI có muốn hiển thị loading hay không khi kết thúc phiên).

### `frontend/lib/features/conversation/presentation/pages/conversation_page.dart`
Cập nhật UI để phản ánh luồng ghi âm liên tục.
- **[MODIFY]** Thay đổi nút Mic thành nút **"Bắt đầu hội thoại"** hiển thị khi đã kết nối nhưng chưa có Session.
- **[MODIFY]** Khi đang trong Session (đang ghi âm liên tục), ẩn nút "Bắt đầu", chỉ hiện thị hiệu ứng *Đang nghe...* (Recording Indicator) và nút **Kết thúc**.
- **[MODIFY]** Nút Đổi người nói (Speaker Toggle) vẫn sẽ giữ nguyên để phục vụ cho việc gán label (speakerA/speakerB) cho luồng audio đang được stream lên backend.

### Quyền Microphone (Permissions)
- `AndroidManifest.xml` & `Info.plist` đã được cấu hình các quyền cần thiết cho audio record.
- Tính năng hỏi quyền đã được tích hợp sẵn trong `AudioRecorderService.hasPermission()`, sẽ được gọi tự động khi `startListening()`.

## Verification Plan
1. Khởi động ứng dụng Flutter (hoặc chạy test widget).
2. Vào màn hình Hội thoại.
3. Nhấn "Bắt đầu kết nối" -> Kết nối WebSocket thành công.
4. Nhấn "Bắt đầu hội thoại" -> Ứng dụng tự động hỏi quyền Microphone (lần đầu) -> Bắt đầu ghi âm và hiển thị trạng thái "Đang nghe liên tục".
5. Nhấn đổi người nói (A <-> B) -> Không bị ngắt quãng ghi âm.
6. Nhấn "Kết thúc" -> Dừng ghi âm -> Gọi đúng method `stopStreamRecording()`.
