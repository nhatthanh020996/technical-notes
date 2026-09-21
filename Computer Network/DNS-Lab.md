# Lab: Chứng Minh DNS Resolution Trên Máy Thật

Tài liệu này là phần **thực hành kiểm chứng** cho bài lý thuyết [DNS: Từ Domain Name Đến IP Address](DNS.md).

Toàn bộ lệnh dưới đây chủ yếu **quan sát** (query DNS, đọc cache), không phá hoại hệ thống — an toàn để chạy trên máy Ubuntu cá nhân. Một vài lệnh cần `sudo` (bắt gói bằng `tcpdump`, xóa cache resolver) và sẽ tự phục hồi ngay sau khi chạy lại.

### Mục lục

1. [Chuẩn bị: xác định resolver đang dùng](#chuẩn-bị-xác-định-resolver-đang-dùng)
2. [Kịch bản 1 — Xem toàn bộ luồng resolution: root → TLD → authoritative](#kịch-bản-1--xem-toàn-bộ-luồng-resolution-root--tld--authoritative)
3. [Kịch bản 2 — Bắt trực tiếp DNS query/response bằng tcpdump](#kịch-bản-2--bắt-trực-tiếp-dns-queryresponse-bằng-tcpdump)
4. [Kịch bản 3 — Chứng minh CNAME chain được resolver tự động theo đuổi](#kịch-bản-3--chứng-minh-cname-chain-được-resolver-tự-động-theo-đuổi)
5. [Kịch bản 4 — Chứng minh caching và TTL countdown thật](#kịch-bản-4--chứng-minh-caching-và-ttl-countdown-thật)
6. [Kịch bản 5 — Đo độ trễ: cache miss vs cache hit](#kịch-bản-5--đo-độ-trễ-cache-miss-vs-cache-hit)
7. [Kịch bản 6 (tùy chọn) — Xem cache thật của resolver nội bộ](#kịch-bản-6-tùy-chọn--xem-cache-thật-của-resolver-nội-bộ)
8. [Ghi chú về nguồn kiến thức](#ghi-chú-về-nguồn-kiến-thức)

## Chuẩn bị: xác định resolver đang dùng

```bash
resolvectl status | head -10
cat /etc/resolv.conf
```

Trên máy dùng để viết lab này, output cho thấy:

```
Global
         Protocols: -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
  resolv.conf mode: stub
Current DNS Server: 8.8.8.8
       DNS Servers: 8.8.8.8 1.1.1.1
```

Và `/etc/resolv.conf` (do `systemd-resolved` quản lý) trỏ về `nameserver 127.0.0.53` — đây là **stub resolver cục bộ**, không phải recursive resolver thật. Toàn bộ ứng dụng trên máy gửi query đến `127.0.0.53`, `systemd-resolved` mới là bên **thật sự forward** query lên `8.8.8.8` (upstream recursive resolver). Đây chính là ví dụ thực tế của lớp "OS-level cache" đã nói trong mục 3.5 của [DNS.md](DNS.md).

Nếu máy bạn không dùng `systemd-resolved` (ví dụ dùng NetworkManager thuần hoặc resolver khác), `nameserver` trong `/etc/resolv.conf` sẽ là IP resolver thật — vẫn áp dụng được các kịch bản dưới, chỉ khác ở việc không có tầng stub `127.0.0.53` trung gian.

## Kịch bản 1 — Xem toàn bộ luồng resolution: root → TLD → authoritative

**Đối chiếu với:** mục "3.2. Luồng resolution đầy đủ" trong [DNS.md](DNS.md).

```bash
dig +trace example.com A
```

**Kết quả thật quan sát được** (rút gọn, giữ lại phần quan trọng nhất mỗi tầng):

```
;; Received ... from ... (a.root-servers.net / l.root-servers.net...)
com.    172800  IN  NS  k.gtld-servers.net.
com.    172800  IN  NS  l.gtld-servers.net.
com.    172800  IN  NS  m.gtld-servers.net.
;; Received 1171 bytes from 199.7.83.42#53(l.root-servers.net) in 69 ms

example.com.  172800  IN  NS  hera.ns.cloudflare.com.
example.com.  172800  IN  NS  elliott.ns.cloudflare.com.
;; Received 506 bytes from 192.42.93.30#53(g.gtld-servers.net) in 48 ms

example.com.  300  IN  A  104.20.23.154
example.com.  300  IN  A  172.66.147.243
;; Received 179 bytes from 172.64.35.228#53(elliott.ns.cloudflare.com) in 47 ms
```

**Đối chiếu với lý thuyết:**

| Quan sát thực tế | Khớp với phần nào trong DNS.md |
| --- | --- |
| Bước 1: hỏi root server, nhận về danh sách NS của `.com` (không có IP cuối) | **Referral** — root không trả IP, chỉ chỉ đường đến TLD server, đúng mục "3.2" |
| Bước 2: hỏi TLD server (`g.gtld-servers.net`), nhận về NS của `example.com` (Cloudflare) | Referral tiếp — TLD không biết IP cuối, chỉ biết ai là authoritative |
| Bước 3: hỏi authoritative (`elliott.ns.cloudflare.com`), nhận về `A` record thật | Đây là bước resolver dừng lại — đã có câu trả lời cuối cùng |
| `dig +trace` tự thực hiện **cả 3 bước tuần tự**, không nhờ ai đệ quy giúp | Đây chính là **iterative query** — `dig +trace` đang đóng vai trò recursive resolver, tự lặp qua từng bước |

> **Lưu ý:** IP thật của `example.com` có thể khác khi bạn tự chạy lệnh này (Cloudflare dùng anycast, và IP có thể đổi theo thời gian) — không nhất thiết phải khớp `104.20.23.154` ở trên, quan trọng là cấu trúc 3 tầng (root → TLD → authoritative) phải xuất hiện.

## Kịch bản 2 — Bắt trực tiếp DNS query/response bằng tcpdump

**Đối chiếu với:** mục "3.3. Cấu trúc một DNS message thật" trong [DNS.md](DNS.md).

**Bước 1 — Mở 2 terminal.**

Terminal A (bắt gói UDP port 53, chạy trước và giữ chạy):
```bash
sudo tcpdump -i any -n port 53 -v
```

Terminal B (xóa cache resolver để đảm bảo query thật sự đi ra ngoài, rồi resolve một domain):
```bash
resolvectl flush-caches
dig openai.com A
```

**Kết quả kỳ vọng ở Terminal A** (dạng rút gọn):
```
IP 127.0.0.1.xxxxx > 127.0.0.53.53: ... A? openai.com. (...)
IP 127.0.0.53.53 > 127.0.0.1.xxxxx: ... A openai.com. A ... (...)
```

Nếu chạy `tcpdump` trên interface thật (ví dụ interface Wi-Fi, không phải `any`/loopback) trong lúc `systemd-resolved` forward query lên upstream, sẽ thấy thêm:
```
IP <IP-máy-bạn>.xxxxx > 8.8.8.8.53: ... A? openai.com. (...)
IP 8.8.8.8.53 > <IP-máy-bạn>.xxxxx: ... A openai.com. A ... (...)
```

**Đối chiếu:**

| Quan sát thực tế | Khớp với phần nào trong DNS.md |
| --- | --- |
| `A? openai.com.` | Trường **Question** trong DNS message — QTYPE = A, QCLASS = IN |
| Response chứa `A ...` kèm địa chỉ IP | Trường **Answer** — record trả lời trực tiếp |
| Toàn bộ giao tiếp qua **port 53**, giao thức UDP | Đúng như "DNS message... UDP, port 53" mô tả ở đầu mục 3.3 |
| Có 2 lớp query riêng biệt: `127.0.0.1 → 127.0.0.53` rồi `<máy bạn> → 8.8.8.8` | Đúng lớp "OS-level cache / stub resolver" trước khi ra recursive resolver thật, mô tả ở mục 3.5 |

## Kịch bản 3 — Chứng minh CNAME chain được resolver tự động theo đuổi

**Đối chiếu với:** phần "Lưu ý về CNAME" trong mục 3.4 của [DNS.md](DNS.md).

```bash
dig www.github.com +noall +answer
```

**Kết quả thật quan sát được:**
```
www.github.com.   3566  IN  CNAME  github.com.
github.com.       60    IN  A      20.205.243.166
```

**Đối chiếu:** Chỉ với **một lệnh dig duy nhất**, resolver đã tự động: (1) resolve `www.github.com` → thấy đó là `CNAME` trỏ đến `github.com`, (2) tiếp tục resolve `github.com` → ra `A` record thật, rồi trả về **cả hai** record trong cùng response. Client không cần tự lặp lại — đây chính là hành vi "resolver không dừng lại ở CNAME, tự tiếp tục resolve" đã nói trong DNS.md.

Chú ý TTL của 2 record khác nhau (`3566` cho CNAME, `60` cho A) — mỗi record trong chain có TTL độc lập, không dùng chung.

## Kịch bản 4 — Chứng minh caching và TTL countdown thật

**Đối chiếu với:** mục "3.5. Caching và TTL" trong [DNS.md](DNS.md).

```bash
resolvectl flush-caches
dig example.com A +noall +answer
sleep 3
dig example.com A +noall +answer
```

**Kết quả thật quan sát được** (chạy cách nhau 3 giây):
```
example.com.   291  IN  A  104.20.23.154
example.com.   291  IN  A  172.66.147.243

example.com.   288  IN  A  172.66.147.243
example.com.   288  IN  A  104.20.23.154
```

**Đối chiếu:** TTL giảm từ `291` xuống `288` — đúng khoảng 3 giây đã trôi qua giữa 2 lần query. Điều này chứng minh: sau lần query đầu, `systemd-resolved` đã **cache** record này và tự đếm ngược TTL cục bộ — lần query thứ hai **không** gửi lại ra ngoài, chỉ trả từ cache với TTL còn lại (kiểm chứng thêm ở Kịch bản 5 bằng thời gian phản hồi). Đây đúng là cơ chế "resolver được phép giữ kết quả trong thời gian TTL" mô tả trong DNS.md.

## Kịch bản 5 — Đo độ trễ: cache miss vs cache hit

**Đối chiếu với:** phần "Vấn đề mới DNS gây ra — Độ trễ truy vấn" trong mục 2 của [DNS.md](DNS.md).

```bash
resolvectl flush-caches
dig openai.com +noall +stats | grep "Query time"
dig openai.com +noall +stats | grep "Query time"
```

**Kết quả thật quan sát được:**
```
;; Query time: 49 msec
;; Query time: 0 msec
```

**Đối chiếu:** Lần đầu (cache miss) resolver phải thực sự đi hỏi upstream — tốn `49 msec` round-trip network. Lần hai (cache hit) trả kết quả tức thì (`0 msec`) vì record vẫn còn trong TTL, không cần hỏi lại. Đây là minh chứng trực tiếp cho câu "mỗi lần resolve domain mới tốn thêm round-trip *trước khi* TCP handshake kịp bắt đầu" đã nói trong phần Why của DNS.md — và cũng lý giải tại sao caching giúp giảm độ trễ đáng kể cho các lần truy cập sau.

## Kịch bản 6 (tùy chọn) — Xem cache thật của resolver nội bộ

Nếu máy dùng `systemd-resolved` (kiểm tra ở phần Chuẩn bị), có thể xem thống kê cache trực tiếp:

```bash
resolvectl statistics
```

**Kết quả thật quan sát được (ví dụ trên một máy đã chạy lâu):**
```
Cache
  Current Cache Size: 117
          Cache Hits: 17807
        Cache Misses: 106577
```

**Đối chiếu:** `Cache Hits` chính là số lần trả kết quả từ cache nội bộ (như Kịch bản 5, lần 2), `Cache Misses` là số lần phải thực sự hỏi ra upstream (như Kịch bản 5, lần 1). Tỷ lệ hit/miss cao hay thấp phụ thuộc trực tiếp vào TTL của các domain thường được truy cập — domain có TTL cao (hàng giờ) sẽ tích lũy cache hit nhiều hơn domain có TTL thấp (vài chục giây, thường gặp ở hệ thống có failover/load balancing động).

## Ghi chú về nguồn kiến thức

Nội dung lý thuyết trong DNS.md dựa trên kiến thức nền tổng hợp, tham chiếu gần nhất với:
- **RFC 882/883** (1983) — thiết kế DNS gốc, thay thế `HOSTS.TXT`.
- **RFC 1034/1035** (1987) — chuẩn hóa DNS còn dùng đến hiện tại (concepts, cấu trúc message).
- **RFC 4033-4035** — DNSSEC.
- **RFC 8484** — DoH (DNS over HTTPS); **RFC 7858** — DoT (DNS over TLS).

Các lệnh trong lab này là cách đối chiếu trực tiếp, độc lập với nguồn — nếu kết quả `dig`/`tcpdump`/`resolvectl` không khớp với mô tả lý thuyết (ví dụ IP của `example.com` đổi do anycast, hoặc TTL khác do thời điểm chạy khác nhau), ưu tiên tin vào kết quả quan sát thực tế trên máy, chỉ cấu trúc tổng thể (3 tầng resolution, CNAME chain, TTL countdown) mới là phần cố định cần khớp.
