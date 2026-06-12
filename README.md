# Magisk Module: Family Link Lock Cleanup

Đây là một Magisk Module hoàn chỉnh dành cho các thiết bị Android đã root (đặc biệt tương thích tốt với MIUI/HyperOS), nhằm ngăn chặn trẻ lách luật đếm giờ sử dụng ứng dụng của Google Family Link bằng các thủ thuật hiển thị cửa sổ nổi, bong bóng chat (bubble) hoặc các lớp vẽ đè màn hình (overlay).

---

## Tính năng nổi bật

- **Khởi động tự động**: Tự khởi động ngầm sau khi thiết bị boot hoàn tất dưới quyền root.
- **Trang quản trị Web UI bảo mật**: Chạy một web server siêu nhẹ (sử dụng `busybox httpd` có sẵn của Magisk) tại cổng `8080`. 
  - Yêu cầu mật khẩu truy cập: **`meocon0301`** để bảo mật tránh trẻ tự ý chỉnh sửa.
  - Hỗ trợ tạo lối tắt ngoài màn hình (PWA Shortcut) trên Chrome bằng cách chọn "Thêm vào màn hình chính" (Add to Home screen) để quản lý chỉ với 1 chạm.
- **Quản lý quyền vẽ đè (Overlay Permission Manager)**:
  - Tự động quét và liệt kê **chỉ những ứng dụng bên thứ 3** có yêu cầu quyền vẽ trên ứng dụng khác (`SYSTEM_ALERT_WINDOW`).
  - Hiển thị trạng thái hoạt động trực tiếp của từng ứng dụng với nhãn trực quan: `🟢 Active` (Được phép vẽ) / `🔴 Blocked` (Đã chặn vẽ).
  - Tích hợp công tắc (Toggle Switch) cho phép cha mẹ bật/tắt quyền vẽ đè của từng app ngay trên Web UI.
- **Giám sát thời gian thực (Real-time Enforcer)**: 
  - Module chạy một tiến trình ngầm kiểm tra mỗi **5 giây**. 
  - Nếu trẻ cố tình truy cập vào Cài đặt để bật lại quyền vẽ hoặc đồng ý cấp lại quyền vẽ khi app yêu cầu, tiến trình ngầm sẽ ngay lập tức phát hiện, tự động **thu hồi lại quyền về trạng thái khóa (`ignore`) và lập tức tắt ứng dụng đó (`force-stop`)** để đóng ngay bong bóng chat đang hiển thị.
  - Khi cha mẹ cho phép ứng dụng qua Web UI, quyền vẽ đè sẽ được tự động khôi phục về mặc định ngay lập tức.
- **Gỡ cài đặt sạch sẽ**: Khi gỡ module qua app Magisk, script `uninstall.sh` sẽ tự động khôi phục toàn bộ cấu hình AppOps về mặc định ban đầu và dọn sạch các file tạm trên máy.

---

## Cấu trúc thư mục

```text
checkfamilylink/
├── module.prop         # Thông tin chi tiết của module (tên, phiên bản, tác giả...)
├── service.sh          # Script chạy ngầm chính: Khởi động Web Server và chạy vòng lặp enforcer 5s
├── post-fs-data.sh     # Hook chạy sớm lúc boot (ghi log kiểm tra hệ thống)
├── uninstall.sh        # Khôi phục quyền vẽ đè và dọn dẹp cấu hình khi gỡ module
├── cleanup.sh          # (Đã lược bỏ logic cũ) Script stub để tương thích ngược
├── unlock.sh           # (Đã lược bỏ logic cũ) Script stub để tương thích ngược
├── webroot/
│   ├── index.html      # Giao diện Web UI Dark Mode tinh tế để nhập pass và bật/tắt chặn vẽ đè
│   └── cgi-bin/
│       └── api.sh      # CGI API nhận request để quét danh sách app và thực hiện bật/tắt AppOps
└── README.md           # Tài liệu hướng dẫn sử dụng tiếng Việt này
```

---

## Hướng dẫn sử dụng Giao diện quản trị (Web UI)

Để cho phép hoặc cấm một ứng dụng (ví dụ: Zalo) sử dụng bong bóng chat / cửa sổ nổi:

1. **Truy cập trang quản trị**:
   Mở trình duyệt Chrome trên điện thoại của trẻ và truy cập địa chỉ: `http://localhost:8080`
2. **Xác thực mật khẩu**:
   Nhập mật khẩu truy cập: **`meocon0301`**
3. **Quản lý ứng dụng**:
   - Web UI sẽ hiển thị danh sách các app yêu cầu quyền vẽ đè.
   - Gạt công tắc sang **Bật** (xanh) để đưa app đó vào Whitelist (Cho phép app sử dụng bong bóng chat/cửa sổ nổi bình thường).
   - Gạt công tắc sang **Tắt** (xám) để cấm app sử dụng bong bóng chat/cửa sổ nổi. Tiến trình ngầm sẽ tự động khóa và tắt app nếu trẻ cố tình bật lại.

*Cấu hình Whitelist được lưu tại file: `/data/adb/familylock_whitelist.txt`*

---

## Hướng dẫn cập nhật file nhanh (Không cần Flash lại module)

Khi bạn muốn cập nhật giao diện `index.html` hoặc API `api.sh` mà không muốn mất thời gian đóng gói ZIP và cài đặt lại từ đầu:

1. Copy file từ máy tính vào thư mục tạm của điện thoại qua ADB:
   ```bash
   adb push webroot/index.html /data/local/tmp/index_new.html
   adb push webroot/cgi-bin/api.sh /data/local/tmp/api_new.sh
   ```
2. Chạy lệnh copy đè vào thư mục module Magisk bằng quyền root:
   ```bash
   adb shell "/sbin/su -c 'cp /data/local/tmp/index_new.html /data/adb/modules/familylink-cleanup/webroot/index.html && cp /data/local/tmp/api_new.sh /data/adb/modules/familylink-cleanup/webroot/cgi-bin/api.sh && chmod 755 /data/adb/modules/familylink-cleanup/webroot/cgi-bin/api.sh'"
   ```
3. Mở Chrome trên điện thoại và **tải lại trang (Reload)**. Thay đổi sẽ có hiệu lực ngay lập tức.

---

## Hướng dẫn cài đặt thủ công lần đầu

1. Nén toàn bộ thư mục `checkfamilylink` thành file ZIP (đảm bảo file `module.prop` nằm ở thư mục gốc của file ZIP):
   ```bash
   zip -r FamilyLinkLockCleanup.zip *
   ```
2. Sao chép file `FamilyLinkLockCleanup.zip` vào điện thoại.
3. Mở ứng dụng **Magisk** (hoặc KernelSU/APatch).
4. Vào mục **Modules** -> Chọn **Cài đặt từ bộ nhớ** -> Chọn file `FamilyLinkLockCleanup.zip`.
5. Đợi quá trình cài đặt hoàn tất và nhấn **Khởi động lại (Reboot)** thiết bị.
