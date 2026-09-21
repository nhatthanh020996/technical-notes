Hãy tưởng tượng **CSRF (Cross-Site Request Forgery)** giống như một vụ "giả mạo chữ ký" trên một tấm séc đã có sẵn dấu vân tay (Cookie) của bạn. Hacker không cần biết mật khẩu của bạn, chúng chỉ cần lừa trình duyệt của bạn tự ký giúp chúng.

Dưới đây là cách nó vận hành từ con số 0.

### Mục lục

1. [CSRF là gì?](#1-csrf-là-gì)
2. [Kịch bản tấn công thực tế](#2-kịch-bản-tấn-công-thực-tế)
3. [Vũ khí phòng thủ: CSRF Token](#3-vũ-khí-phòng-thủ-csrf-token)
4. [Vũ khí phòng thủ: Cookie `SameSite`](#4-vũ-khí-phòng-thủ-cookie-samesite)
5. [Không phải request nào cũng cần CSRF Token](#5-không-phải-request-nào-cũng-cần-csrf-token)
6. [CSRF khác gì XSS?](#6-csrf-khác-gì-xss)
7. [Vì sao Python lấy được CSRF Token còn hacker trên trình duyệt thì không?](#7-vì-sao-python-script-lấy-được-csrf-token-dễ-dàng-còn-hacker-trên-trình-duyệt-thì-không)

### 1. CSRF là gì?

**CSRF (Giả mạo yêu cầu từ trang web khác)** là một loại tấn công đánh lừa trình duyệt của bạn gửi đi một yêu cầu (request) độc hại đến một website mà bạn **đã đăng nhập**.

**Cơ chế "ngây thơ" của trình duyệt:** Khi bạn đăng nhập vào một web (ví dụ: `nganhang.com`), trình duyệt sẽ lưu Cookie phiên làm việc. Điều nguy hiểm là: bất cứ khi nào có một request gửi đến `nganhang.com`, trình duyệt sẽ **tự động đính kèm** cái Cookie đó vào, bất kể request đó xuất phát từ đâu.

Hacker lợi dụng chính sự "tự động" này, không phải lỗ hổng kỹ thuật nào cao siêu.

---

### 2. Kịch bản tấn công thực tế

1. **Bước 1:** Bạn đang đăng nhập vào tài khoản Ngân hàng (`nganhang.com`) ở tab 1.
2. **Bước 2:** Bạn vô tình bấm vào một link "xem ảnh hot" ở tab 2, dẫn đến trang `evil-hacker.com`.
3. **Bước 3:** Trang của hacker có một đoạn code ngầm tự động gửi request đến ngân hàng.
4. **Bước 4:** Trình duyệt thấy request gửi đến `nganhang.com`, nó tự động "ném" luôn Cookie đăng nhập của bạn vào đó.
5. **Bước 5:** Server ngân hàng thấy Cookie hợp lệ → tin tưởng đây là bạn → **mất tiền**.

Hacker có 2 cách phổ biến để "nhúng" lệnh POST ngầm:

**Cách A: Form ẩn (phổ biến nhất)**

```html
<form id="attack-form" action="https://nganhang.com/api/chuyen-tien" method="POST">
  <input type="hidden" name="stk_nhan" value="123456789_Cua_Hacker">
  <input type="hidden" name="so_tien" value="100000000">
</form>
<script>
  // Tự động submit ngay khi bạn vừa vào trang của hacker
  document.getElementById('attack-form').submit();
</script>
```

**Cách B: JavaScript ngầm (Fetch/AJAX)**

```js
fetch("https://nganhang.com/api/chuyen-tien", {
  method: "POST",
  body: "stk_nhan=hacker&so_tien=100tr",
  headers: { "Content-Type": "application/x-www-form-urlencoded" }
});
```

Cả hai cách đều không cần bạn nhấn nút nào — trang chạy xong là request đã bay đi kèm Cookie của bạn.

**Các kịch bản tồi tệ khác ngoài chuyển tiền:**

* **Đổi mật khẩu:** Hacker âm thầm gửi request đổi mật khẩu tài khoản của bạn.
* **Xóa dữ liệu:** Tự động xóa bài viết, xóa tài khoản, hủy đơn hàng.
* **Phát tán mã độc:** Dùng tài khoản của bạn để đăng nội dung rác hoặc lừa đảo.

---

### 3. Vũ khí phòng thủ: CSRF Token

Mã CSRF Token được tạo ra để phá vỡ sự "ngây thơ" của trình duyệt.

* Nó là một chuỗi ký tự **duy nhất, ngẫu nhiên, bí mật** mà server tạo ra riêng cho phiên làm việc của bạn.
* Nó được nhúng vào trong Form (thường là một `<input type="hidden" name="_csrf">`).
* **Quy tắc của Server:** "Ta chỉ thực hiện yêu cầu POST nếu ngươi gửi kèm đúng cái mã bảo mật mà ta vừa đưa cho ngươi."

**Tại sao hacker không lấy trộm luôn cái mã đó?**

Hacker có thể lừa trình duyệt *gửi* request, nhưng do **Same-Origin Policy (SOP)**, website của hacker không thể *đọc* được nội dung HTML trên trang ngân hàng để lấy cái mã `_csrf` đó.

Cụ thể khi hacker cố dùng JavaScript để "chôm" token bằng một request GET:

1. `hacker.com` gửi GET đến `nganhang.com` để lấy trang chứa token.
2. `nganhang.com` trả về file HTML có chứa mã CSRF.
3. Trình duyệt nhận file đó, nhìn Header thấy không có `hacker.com` trong danh sách cho phép (không có `Access-Control-Allow-Origin` phù hợp).
4. **Kết quả:** Trình duyệt báo lỗi CORS và **không cho phép** JavaScript của hacker đọc nội dung file HTML. Hacker đứng nhìn cái file có mã CSRF ngay trước mắt mà không thể "chạm" vào được.

Vì hacker không biết mã đó là gì, mọi request giả mạo gửi đi đều bị server từ chối vì thiếu "chữ ký" bí mật.

> Đây cũng là lý do CORS và CSRF luôn được nhắc chung: CORS là bức tường ngăn hacker *đọc* dữ liệu chéo domain, còn CSRF Token là "chữ ký" dựa vào chính bức tường đó để hoạt động.

**Nếu ngân hàng lỡ set `Access-Control-Allow-Origin: "*"` thì sao?**

Trình duyệt có luật sắt: **không thể vừa mở cửa cho tất cả (`*`) vừa cho phép gửi kèm Cookie (`credentials`)**. Nếu request có Cookie mà server trả về `*`, trình duyệt sẽ chặn đứng không cho hacker đọc kết quả.

"Pháo đài" chỉ sụp đổ thật khi lập trình viên mắc lỗi cấu hình nghiêm trọng hơn: viết code tự động phản chiếu đúng domain gọi tới (kể cả domain hacker) vào `Access-Control-Allow-Origin`, cộng với `Access-Control-Allow-Credentials: true`. Lúc đó hacker mới đọc được token và tấn công thành công. Đây được xếp vào lỗi **Security Misconfiguration** trong OWASP Top 10.

---

### 4. Vũ khí phòng thủ: Cookie `SameSite`

Bên cạnh CSRF Token, trình duyệt hiện đại có thêm một lớp chặn ngay tại nguồn: thuộc tính `SameSite` của Cookie.

Mặc định (không có `SameSite`), trình duyệt "hào phóng": có Cookie cho `bank.com` thì gửi kèm **mọi** request đến `bank.com`, dù request đó xuất phát từ đâu. `SameSite` thay đổi luật chơi: "Kiểm tra xem người dùng đang đứng ở đâu trước khi đính kèm Cookie."

**`SameSite=Lax`** — mức trung gian phổ biến nhất: chỉ gửi Cookie nếu request là "an toàn" và mang tính điều hướng cấp cao nhất (top-level navigation).

| Hành động | Có phải Cross-Site? | Method | Cookie có được gửi? |
|---|---|---|---|
| Click một link tới site | Có | GET | Có (đang điều hướng) |
| `<iframe>` ẩn load site | Có | GET | Không |
| `<img>` load site | Có | GET | Không |
| `<form>` submit tới site | Có | POST | **Không** |

Với `SameSite=Lax`, cuộc tấn công "form ẩn" ở mục 2 sẽ thất bại: trình duyệt thấy request POST đến từ `hacker.com` (cross-site) nên **không đính kèm Session Cookie**. Server ngân hàng nhận request mà không có thông tin đăng nhập → coi như người dùng ẩn danh → từ chối.

**Tại sao không dùng `SameSite=Strict` cho chắc?**

`Strict` không gửi Cookie trong *bất kỳ* request cross-site nào, kể cả khi bạn click một link bình thường từ email vào ngân hàng — bạn sẽ bị "đăng xuất" ngay cả khi vừa đăng nhập xong, gây trải nghiệm tệ. `Lax` cân bằng: vẫn giữ đăng nhập khi điều hướng bằng GET, nhưng cắt "danh tính" khi có ai đó submit form hoặc chạy script POST từ bên ngoài.

**Lỗ hổng nhỏ còn lại của `Lax`:** nếu website của bạn cho phép một hành động thay đổi dữ liệu (như xóa tài khoản) thông qua **GET** — điều tối kỵ trong thiết kế REST — hacker vẫn có thể lừa bạn click một link kích hoạt hành động đó. Vì vậy quy tắc bất di bất dịch: **không bao giờ để GET làm thay đổi dữ liệu trên server.**

---

### 5. Không phải request nào cũng cần CSRF Token

Nếu cái gì cũng phải kèm mã này thì web sẽ chạy chậm và lập trình viên "phát điên". Quy tắc vàng: **chỉ những request làm thay đổi dữ liệu mới cần CSRF.**

| Phương thức | Mục đích | Cần CSRF? |
|---|---|---|
| GET | Xem dữ liệu, tải trang | Không |
| POST | Gửi dữ liệu mới, đặt hàng | Có |
| PUT / PATCH | Chỉnh sửa thông tin | Có |
| DELETE | Xóa dữ liệu | Có |
| API (dùng JWT trong Header) | App mobile, SPA | Không (dùng cơ chế khác) |

**Tại sao GET không cần?** Vì dù hacker lừa được bạn gửi GET đến ngân hàng, request đó cũng chỉ khiến trình duyệt *hiển thị* dữ liệu lên màn hình của chính bạn — hacker không "nhìn trộm" được màn hình đó nên chẳng thu lợi gì.

**Khi nào chủ động tắt CSRF ngay cả với POST?**

* **API dùng Token-based (JWT/Bearer)** — cách các SPA (React/Vue) và Mobile App hay dùng: client tự lưu token (thường ở `localStorage`) và chủ động đính kèm vào header `Authorization: Bearer <token>`. Trình duyệt **không tự động** gửi header này đi như cách nó tự gửi Cookie, nên hacker không có cách nào ép trình duyệt đính kèm — không có token, request thất bại.
* **API cho Mobile/Desktop App** — không chạy trong môi trường trình duyệt, không có khái niệm "cross-site" kiểu trình duyệt, nên không bị CSRF.
* **Webhooks / Server-to-server** — như GitHub hay Stripe gọi vào server của bạn. Không có trình duyệt người dùng ở giữa nên mã CSRF vô nghĩa; các hệ thống này xác thực bằng shared secret hoặc API key.

Bảng quyết định nhanh:

| Loại API | Xác thực bằng | Cần CSRF? |
|---|---|---|
| Web truyền thống (multi-page) | Cookie / Session | Có |
| Web hiện đại (SPA) | JWT trong Header | Không |
| Mobile App | API Key / JWT | Không |
| Webhooks | Shared Secret / API Key | Không |

Trong các framework Python: Django bật `CsrfViewMiddleware` cho mọi view theo mặc định — muốn tắt cho API dùng JWT thì cần decorator `@csrf_exempt`. Flask/FastAPI thì ngược lại, không bật sẵn CSRF — chỉ nên thêm khi làm web kiểu truyền thống (render HTML từ server, dùng Session Cookie).

---

### 6. CSRF khác gì XSS?

Hai lỗ hổng này hay bị nhầm vì cùng liên quan đến trình duyệt và Cookie, nhưng bản chất ngược nhau:

* **CSRF:** Hacker **không** đọc/chạy được gì trên trang đích, chỉ lừa trình duyệt *gửi* một request giả mạo kèm Cookie thật của bạn.
* **XSS (Cross-Site Scripting):** Hacker chèn được mã độc (JavaScript) chạy **ngay trên** chính website bạn tin tưởng, dưới danh nghĩa trang đó — nguy hiểm hơn vì có toàn quyền như trang thật, kể cả đọc `document.cookie`.

Vì vậy hai lớp phòng thủ bổ trợ nhau:

* **`HttpOnly` (Cookie flag):** chặn JavaScript đọc Cookie → chống XSS đánh cắp Session Token. Nhưng `HttpOnly` **không** chống được CSRF, vì trình duyệt vẫn tự động *gửi* Cookie đi trong request (chỉ là JS không *đọc* được nó).
* **`SameSite=Lax` (Cookie flag):** chặn trình duyệt tự gửi Cookie trong request cross-site không an toàn → chống CSRF. Nhưng không chống được XSS, vì nếu hacker đã chạy được script trên chính trang của bạn thì Cookie vẫn được gửi bình thường như mọi request cùng gốc.

Cấu hình Cookie đăng nhập "chuẩn" kết hợp cả 3 flag:

```
Set-Cookie: session_id=abc123xyz; HttpOnly; Secure; SameSite=Lax
```

* `HttpOnly` — chống XSS lấy trộm token.
* `Secure` — chỉ gửi qua HTTPS, chống nghe lén.
* `SameSite=Lax` — chống CSRF.

---

### 7. Vì sao Python (script) lấy được CSRF Token dễ dàng còn hacker trên trình duyệt thì không?

Đây là điểm hay bị hiểu lầm: nếu bạn viết code Python để tự động điền form (gọi GET lấy token rồi POST), bạn hoàn toàn lấy được token — không hề bị lỗi CORS. Nhưng hacker đứng trên trình duyệt lại bó tay. Sự khác biệt nằm ở **ai đang thực thi request**.

| Đặc điểm | Script trên trình duyệt của hacker | Script Python của bạn |
|---|---|---|
| Môi trường | Trình duyệt (Chrome, Firefox...) | Python interpreter |
| Quy tắc bảo mật | Bị SOP và CORS kiểm soát chặt | Không bị trình duyệt kiểm soát |
| Khả năng đọc response | Không (bị chặn đọc chéo domain) | Có (toàn quyền đọc mọi byte trả về) |

Thư viện `requests` của Python không phải trình duyệt, nó không quan tâm SOP hay CORS — cứ gửi request và đọc thoải mái mọi dữ liệu trả về. Hacker thì bị nhốt trong "nhà tù" bảo mật mà chính trình duyệt xây cho mọi trang web, nên không có cách nào tự động hóa việc đánh cắp token từ xa. Đó cũng là lý do CSRF Token cực kỳ hiệu quả *trên môi trường web*, nhưng không phải là một cơ chế chống bot hay chống script nói chung.

---

### Tóm tắt bằng hình tượng

* **Cookie:** Là "dấu vân tay" của bạn mà trình duyệt tự động đóng vào mọi request gửi tới trang bạn đã đăng nhập.
* **CSRF:** Hacker giả mạo một tấm séc rồi lừa trình duyệt tự đóng dấu vân tay của bạn vào đó.
* **CSRF Token:** Chữ ký bí mật đi kèm, mà hacker không thể nhìn thấy hoặc sao chép nhờ Same-Origin Policy.
* **SameSite=Lax:** Bảo vệ vệ ở vòng ngoài, dặn trình duyệt "đừng tự đóng dấu vân tay nếu tấm séc đến từ một ngôi nhà lạ".
* **HttpOnly:** Một lớp khiên khác, không liên quan tới CSRF, mà để giấu "con dấu" khỏi tay kẻ nội gián (XSS) đã lẻn được vào nhà.
