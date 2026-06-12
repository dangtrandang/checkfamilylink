# Magisk Module: Family Link Lock Cleanup

Đây là một Magisk Module hoàn chỉnh dành cho các thiết bị Android đã root, nhằm khắc phục triệt để lỗ hổng hiển thị cửa sổ nổi, bong bóng chat (bubble), và các tác vụ lách khóa (ví dụ: chạy app thông qua Xiaomi Game Turbo) khi Google Family Link thực hiện khóa thiết bị (khóa giờ ngủ, hết giới hạn thời gian hàng ngày, hoặc cha mẹ khóa thủ công).

---

## Tính năng nổi bật

- **Khởi động tự động**: Tự khởi động ngầm sau khi thiết bị boot hoàn tất dưới quyền root.
- **Vô hiệu hóa bong bóng chat vĩnh viễn**: Để tránh việc con lách luật đếm giờ 15 phút của Zalo bằng cách nhắn tin qua bong bóng chat SystemUI (Android không tính thời gian vào app khi dùng bong bóng), module sẽ khóa cứng tính năng bong bóng chat trên toàn hệ thống (`notification_bubbles = 0`). Điều này buộc con phải mở trực tiếp Zalo để nhắn tin, giúp Family Link đếm giờ chuẩn xác 100%.
- **Cơ chế tự sửa lỗi (Self-Healing Watcher)**: Kết hợp State Machine và debounce thời gian (> 10s). Nếu lỡ nhịp log mở khóa trước đó khiến trạng thái bị lệch, lần khóa tiếp theo vẫn kích hoạt dọn dẹp bình thường, không lo bị kẹt trạng thái.
- **Hệ thống khóa kép bảo mật cao (Double-Layer Lock)**:
  Khi thiết bị khóa, tất cả các ứng dụng người dùng cài thêm (trừ danh sách được phép) sẽ bị:
  1. Tắt hoàn toàn (`am force-stop`).
  2. Đóng băng ứng dụng (`pm suspend`): Làm xám icon ngoài màn hình chính và chặn đứng mọi nỗ lực khởi chạy ứng dụng từ Game Turbo hoặc cửa sổ nổi.
  3. Tường lửa cấp nhân (`iptables` / `ip6tables`): Cấm mọi kết nối internet đi ra từ mã định danh (UID) của ứng dụng đó trên tất cả profile người dùng (hỗ trợ đầy đủ cả tài khoản chính và Ứng dụng kép/Dual Apps).
- **Giữ kết nối mạng cho máy**: Điện thoại của con vẫn kết nối Wi-Fi/Mobile Data bình thường cho các dịch vụ hệ thống (như Google Play Services), giúp **cha mẹ vẫn có thể bấm Mở khóa từ xa** trên app điện thoại của mình. Chỉ các app bị khóa mới bị cắt mạng.
- **Trang quản trị Web UI trực quan**: Chạy một web server siêu nhẹ (sử dụng `busybox httpd` có sẵn của Magisk) tại cổng `8080` (tiêu hao dưới 2MB RAM và 0% CPU khi không sử dụng).
- **Lối tắt ngoài màn hình (PWA Shortcut)**: Chrome -> "Thêm vào màn hình chính" tạo ra một icon app tiện lợi ngoài launcher để quản lý whitelist chỉ với 1 chạm.

---

## Cấu trúc thư mục

```text
checkfamilylink/
├── module.prop         # Thông tin chi tiết của module (tên, phiên bản, tác giả...)
├── service.sh          # Script chạy ngầm chính: Khởi động Web Server và lắng nghe logcat
├── cleanup.sh          # Trình xử lý khóa: Đưa về Home, tắt app, đóng băng, cấm bong bóng và chặn mạng app
├── unlock.sh           # Trình xử lý mở khóa: Rã đông app và gỡ chặn mạng tường lửa
├── post-fs-data.sh     # Hook chạy sớm lúc boot (ghi log kiểm tra hệ thống)
├── uninstall.sh        # Khôi phục bong bóng chat (notification_bubbles = 1) và dọn dẹp cấu hình khi gỡ module
├── webroot/
│   ├── index.html      # Giao diện Web UI Dark Mode tinh tế để bật/tắt Whitelist
│   └── cgi-bin/
│       └── api.sh      # CGI API giao tiếp trực tiếp với hệ thống để đọc/ghi cấu hình
└── README.md           # Tài liệu hướng dẫn sử dụng tiếng Việt này
```

---

## Hướng dẫn sử dụng Giao diện quản trị (Web UI)

Mặc định khi khóa máy, **tất cả ứng dụng do người dùng cài thêm** (như Zalo, TikTok, Facebook, Game...) sẽ bị khóa và chặn mạng hoàn toàn. Để cho phép một app học tập hoặc liên lạc khẩn cấp hoạt động bình thường khi khóa máy:

1. **Truy cập trang quản trị**:
   Mở trình duyệt Chrome trên điện thoại của con và truy cập địa chỉ: `http://localhost:8080`
2. **Thêm icon App ngoài màn hình chính**:
   - Tại trang Web UI trên Chrome, nhấn vào **Menu 3 chấm** ở góc trên bên phải.
   - Chọn **"Thêm vào màn hình chính"** (Add to Home screen).
   - Chrome sẽ tạo một biểu tượng App tiện lợi ngoài màn hình chính. Bạn có thể mở trực tiếp từ đây để quản lý mà không cần gõ link nữa.
3. **Bật/Tắt ứng dụng được phép**:
   - Sử dụng thanh tìm kiếm để tìm nhanh ứng dụng.
   - Tích chọn bật (Switch) bên cạnh app để đưa app đó vào Whitelist (Cho phép chạy và có mạng bình thường khi khóa).
   - Tắt tích chọn để cấm app hoạt động khi khóa.

*Cấu hình Whitelist được lưu động tại file: `/data/adb/familylock_whitelist.txt`*

---

## Hướng dẫn kiểm tra Log hoạt động

Bạn có thể theo dõi xem module có hoạt động chính xác hay không bằng cách kết nối thiết bị với máy tính và chạy lệnh ADB:

```bash
adb shell "logcat | grep FamilyLockModule"
```

### Các log sự kiện chính:
- **Khi khởi động máy**:
  `FamilyLockModule: Module service started. Monitoring logcat...`
  `FamilyLockModule: Starting Web UI server on port 8080...`
  `FamilyLockModule: Disabling notification bubbles globally...`
- **Khi kích hoạt khóa máy (Lock Now / Bedtime / Hết giờ)**:
  `FamilyLockModule: MATCH FOUND: locking device`
  `FamilyLockModule: Transition to LOCKED state`
  `FamilyLockModule: FamilyLockModule: LOCK DETECTED`
  `FamilyLockModule: FamilyLockModule: CLEANUP START`
  `FamilyLockModule: Stopping and suspending: com.zing.zalo`
  `FamilyLockModule: FamilyLockModule: CLEANUP COMPLETE`
- **Khi mở khóa thiết bị**:
  `FamilyLockModule: MATCH FOUND: unlocking device`
  `FamilyLockModule: Transition to UNLOCKED state`
  `FamilyLockModule: FamilyLockModule: UNLOCK DETECTED`
  `FamilyLockModule: Unsuspending and restoring internet access for user applications...`

---

## Cài đặt

1. Nén toàn bộ thư mục `checkfamilylink` thành file ZIP (đảm bảo file `module.prop` nằm ở thư mục gốc của file ZIP):
   ```bash
   zip -r FamilyLinkLockCleanup.zip *
   ```
2. Sao chép file `FamilyLinkLockCleanup.zip` vào điện thoại.
3. Mở ứng dụng **Magisk** (hoặc KernelSU/APatch).
4. Vào mục **Modules** -> Chọn **Cài đặt từ bộ nhớ** -> Chọn file `FamilyLinkLockCleanup.zip`.
5. Đợi quá trình cài đặt hoàn tất và nhấn **Khởi động lại (Reboot)** thiết bị.
