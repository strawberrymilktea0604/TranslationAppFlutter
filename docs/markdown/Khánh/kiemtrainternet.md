Dựa theo các rules về Clean Architecture và State Management (BLoC/Cubit) của dự án, tôi đã hoàn thiện service lắng nghe trạng thái mạng toàn cục. 



Thay vì dùng `connectivity\_plus` (vốn chỉ kiểm tra xem thiết bị có kết nối tới mạng Wifi/4G hay không chứ không đảm bảo có internet), tôi sử dụng package \*\*`internet\_connection\_checker\_plus`\*\* (đã có sẵn trong `pubspec.yaml` của dự án). Package này thực hiện việc "ping" đến các DNS thật sự (như Google/Cloudflare) để đảm bảo mạng có ra được internet, điều này chuẩn xác hơn để làm bước đệm đồng bộ lên PostgreSQL sau này.



Dưới đây là các phần nội dung tôi đã thực hiện:



\### 1. Nâng cấp `NetworkInfo` để hỗ trợ Stream

File: `lib/core/network/network\_info.dart`

\- Thêm `Stream<bool> get onConnectedChange` vào Interface để liên tục cung cấp chuỗi trạng thái internet thay vì chỉ là Future kiểm tra một lần.

\- Cập nhật `NetworkInfoImpl` để map `onStatusChange` từ `InternetConnection` trả về boolean dễ dàng nhận biết Online/Offline.



\### 2. Tạo Global State bằng `NetworkCubit`

File: `lib/core/network/bloc/network\_cubit.dart`

\- Khởi tạo `NetworkCubit` đóng vai trò là một Bloc/Cubit theo dõi toàn cục trong ứng dụng.

\- Cubit này sẽ lắng nghe `onConnectedChange` của `NetworkInfo` và liên tục cập nhật/phát ra (emit) trạng thái `NetworkStatus.online` hoặc `NetworkStatus.offline`.



\### 3. Đăng ký Dependency Injection (`GetIt`)

File: `lib/injection\_container.dart`

\- Đăng ký `NetworkCubit` dưới dạng `LazySingleton` vào hệ thống Injection (`sl`).



\### 4. Bơm (Provide) `NetworkCubit` toàn cục vào Widget Tree

File: `lib/main.dart`

\- Thêm `BlocProvider<NetworkCubit>` vào `MultiBlocProvider` ngoài cùng ở cấp ứng dụng.

\- Kể từ giờ, bất kỳ đâu trong View/Page nào, bạn cũng có thể lắng nghe thời gian thực về việc thiết bị đang có internet hay bị mất kết nối bằng cách sử dụng `BlocBuilder<NetworkCubit, NetworkStatus>(...)` hoặc `context.read<NetworkCubit>()`.



> \[!TIP]

> Việc tôi chọn `InternetConnectionChecker` thay cho `Connectivity` giúp bạn hoàn toàn an tâm đối với các tính năng sau này. Khi hệ thống báo `NetworkStatus.online`, bạn có thể hoàn toàn tự tin chạy Background Job đồng bộ dữ liệu cục bộ từ \*\*Isar lên PostgreSQL\*\* bằng cách kiểm tra status từ `NetworkCubit`!



Tôi đã chạy kiểm tra lỗi bằng lệnh `dart analyze` và hệ thống không phát hiện lỗi nào, mã nguồn đã sẵn sàng để hoạt động. Bạn có muốn tôi thiết lập thêm giao diện (Snackbar/Toast) hiển thị thông báo mỗi khi người dùng rớt/có mạng trên toàn app không?

