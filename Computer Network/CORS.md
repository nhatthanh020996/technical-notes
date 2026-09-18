Hãy tưởng tượng **CORS (Cross-Origin Resource Sharing)** giống như một hệ thống "Visa" hay "Giấy phép thông hành" mà trình duyệt web sử dụng để bảo vệ bạn.

Dưới đây là cách nó vận hành từ con số 0:

### 1. Khái niệm "Origin" (Nguồn) là gì?

Trước khi hiểu CORS, bạn phải biết "Origin" là cái gì. Một Origin được cấu thành từ 3 thành phần: **Giao thức (Protocol)** + **Tên miền (Domain)** + **Cổng (Port)**.

* `https://myapp.com:80` -> Một Origin.
* `http://myapp.com:80` -> Origin khác (khác Protocol).
* `https://api.themap.world` -> Origin khác (khác Domain).

### 2. Kẻ gác cổng: Same-Origin Policy (SOP)

Trình duyệt có một quy tắc bảo mật cực kỳ nghiêm ngặt tên là **Same-Origin Policy**.

* **Nhiệm vụ:** Không cho phép Website A đọc dữ liệu từ Website B.
* **Tại sao?** Nếu không có nó, một trang web độc hại bạn vô tình mở có thể tự ý gửi request đến Facebook hay Ngân hàng của bạn (nếu bạn đang đăng nhập) để lấy cắp thông tin.

**Nhưng trong thế giới hiện đại, chúng ta cần chia sẻ dữ liệu!** (Ví dụ: Frontend ở `myapp.com` cần gọi API ở `api.themap.world`). Đó là lúc **CORS** xuất hiện để "nới lỏng" quy tắc SOP một cách an toàn.

---

### 3. Cơ chế hoạt động của CORS

CORS không phải là thứ bạn cài đặt trong code JavaScript. Nó là cuộc đối thoại giữa **Trình duyệt** và **Server**.

#### Kịch bản A: Simple Request (Yêu cầu đơn giản)

Áp dụng cho các phương thức "hiền lành" như `GET`, `HEAD`, `POST` (với một số loại content-type cơ bản).

1. **Trình duyệt:** Gửi request kèm theo header `Origin: https://myapp.com`.
2. **Server:** Trả về dữ liệu kèm header `Access-Control-Allow-Origin: https://myapp.com`.
3. **Trình duyệt:** "À, server này cho phép trang web của mình truy cập." -> Nó đưa dữ liệu cho code JavaScript xử lý.

#### Kịch bản B: Preflight Request (Yêu cầu kiểm tra trước) - Đây là lỗi bạn gặp!

Áp dụng khi bạn dùng các phương thức "nguy hiểm" hơn như `PUT`, `DELETE`, hoặc gửi thêm header lạ (như `Authorization`, `X-Request-ID`).

1. **Trình duyệt (Gửi OPTIONS):** Nó không gửi request thật ngay. Nó gửi một bản tin "nháp" (gọi là **Preflight Request**) bằng phương thức `OPTIONS` để hỏi: "Này Server, tôi sắp gửi một request DELETE từ trang `myapp.com` có kèm header `Authorization`, ông có cho phép không?".
2. **Server (Trả lời):** Nếu server đồng ý, nó trả về các header:
* `Access-Control-Allow-Origin: https://myapp.com`
* `Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS`
* `Access-Control-Allow-Headers: Authorization`


3. **Trình duyệt (Gửi Request thật):** Sau khi nhận được cái gật đầu từ Server, lúc này trình duyệt mới gửi request thực sự mà bạn viết trong code.

---

### 4. Tại sao bạn hay bị lỗi CORS?

Lỗi CORS xảy ra khi một trong hai bên "nói chuyện" không khớp:

* **Phía Server:** Không được cấu hình để trả về các header `Access-Control-Allow-...`.
* **Phía Server (Lỗi 401/500):** Khi server bị lỗi hoặc yêu cầu đăng nhập, nó thường quên trả về header CORS. Trình duyệt thấy thiếu header này nên nó chặn luôn, khiến bạn không đọc được nội dung lỗi thực sự bên trong.

### Tóm tắt bằng hình tượng:

* **Trình duyệt:** Là một vệ sĩ tận tâm nhưng máy móc.
* **SOP:** Quy tắc "Người lạ không được vào nhà".
* **CORS:** Danh sách "Khách mời" được chủ nhà (Server) dán ở cửa.
* **Preflight (OPTIONS):** Khách đứng ngoài cổng gọi điện hỏi: "Tôi vào được không?" trước khi thực sự bước vào.