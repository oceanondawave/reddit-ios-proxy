# RedditProxy (iOS) 🌐

Tweak standalone `.dylib` dành cho ứng dụng **Reddit iOS** (`com.reddit.Reddit`), giúp tự động định tuyến toàn bộ lưu lượng mạng của Reddit qua Proxy để vượt tường lửa nhà mạng tại Việt Nam (VNPT, Viettel, FPT,...) mà **không cần bật VPN toàn hệ thống**.

---

## 🌟 Điểm nổi bật & Tính năng

- **Cô lập tiến trình (Per-App Only)**: Chỉ có lưu lượng của ứng dụng Reddit đi qua Proxy. Các ứng dụng khác (ngân hàng, Safari, YouTube, Zalo,...) hoàn toàn không bị ảnh hưởng, giữ nguyên 100% tốc độ gốc và tính bảo mật.
- **Tắt mặc định khi cài đặt (Zero Hang on Launch)**: Tweak mặc định ở trạng thái `OFF` khi vừa cài đặt, đảm bảo không bao giờ bị đứng mạng hay xoay vô tận khi khởi động.
- **Nút bật/tắt & Cấu hình trực quan**: Tích hợp sẵn menu điều khiển trực tiếp trên giao diện Reddit mà không cần sửa file JSON thủ công.
- **Thư viện Proxy tốc độ cao gắn thẻ quốc gia**:
  - 🇸🇬 `[SG] Singapore Fast SOCKS5`
  - 🇰🇷 `[KR] South Korea Fast HTTP`
  - 🇮🇩 `[ID] Indonesia / SG HTTP`
  - 🇺🇸 `[US] Google Cloud Anycast`
  - ⚡ `[LOCAL] Clash / Shadowrocket (127.0.0.1:7890)`
  - ⚡ `[LOCAL] Sing-box / V2Ray (127.0.0.1:10808)`
  - ⚡ `[LOCAL] SOCKS5 Loopback (127.0.0.1:1080)`
- **Kiểm tra IP & Quốc gia (Geo-Location Check)**: Nút `🌍 Check My IP & Country Location` cho biết chính xác IP Public, mã quốc gia và cụm máy chủ Cloudflare mà Reddit nhìn thấy.
- **Chống cache bảng tin (Real-time Feed)**: Tự động ép `NSURLRequestReloadIgnoringLocalCacheData` để Reddit luôn tải bài viết mới nhất thay vì bài cũ từ cache của proxy.
- **Thao tác kích hoạt nhanh**:
  - Nhấn giữ thanh tiêu đề trên cùng (**Top Navigation Bar**) trong 0.8s.
  - Hoặc lắc nhẹ điện thoại (**Shake Gesture**).

---

## 🚀 Hướng dẫn cài đặt

### Cách 1: Sử dụng TrollFools (Khuyên dùng)
1. Tải file `RedditProxy.dylib` từ tab [Releases](https://github.com/oceanondawave/reddit-ios-proxy/releases).
2. Mở **TrollFools** trên iPhone.
3. Chọn ứng dụng **Reddit** -> Chọn **Inject** -> Chọn file `RedditProxy.dylib`.

### Cách 2: Chèn thủ công qua Filza
1. Mở **Filza File Manager** trên iPhone.
2. Điều hướng tới thư mục ứng dụng Reddit:  
   `Apps Manager` ➜ `Reddit` ➜ `RedditApp.app` ➜ `Frameworks/`
3. Sao chép `RedditProxy.dylib` vào thư mục này.
4. Đóng hoàn toàn Reddit và mở lại.

---

## 🛠️ Biên dịch từ mã nguồn (Build from Source)

Yêu cầu máy Mac đã cài đặt **Xcode Command Line Tools** và iOS SDK (tại `~/theos/sdks/` hoặc Xcode SDK).

```bash
git clone https://github.com/oceanondawave/reddit-ios-proxy.git
cd reddit-ios-proxy/reddit-proxy-tweak
./build.sh
```

File sau khi build thành công: `reddit-proxy-tweak/RedditProxy.dylib` (kiến trúc `arm64`, tương thích iOS 15.0 trở lên).

---

## ⚙️ Cơ chế hoạt động (Technical Details)

1. **CFNetwork & NSURLSession Hooking**:
   - Sử dụng [fishhook](https://github.com/facebook/fishhook) để rebind hàm C `CFNetworkCopySystemProxySettings`.
   - Method swizzling `NSURLSessionConfiguration` (`connectionProxyDictionary`, `defaultSessionConfiguration`, `ephemeralSessionConfiguration`).
   - Method swizzling `NSURLSession` (`sessionWithConfiguration:`).
2. **Gesture & UI Integration**:
   - Swizzle `-[UINavigationBar layoutSubviews]` để gắn `UILongPressGestureRecognizer` vào thanh điều hướng.
   - Swizzle `-[UIWindow sendEvent:]` để nhận diện sự kiện lắc máy (`UIEventSubtypeMotionShake`) kèm bộ lọc debounce 1.5s chống kích hoạt trùng lặp.

---

## 👤 Tác giả

**[@oceanondawave](https://github.com/oceanondawave)**

---

## 📄 License

Dự án phát hành dưới giấy phép [MIT](LICENSE).
