# DNS: Từ Domain Name Đến IP Address

Các bài trước ([ARP.md](ARP.md), [NAT.md](NAT.md), [Internet-Topology.md](Internet-Topology.md)) đều bắt đầu từ một tiền đề: ta **đã biết** destination IP (`192.168.1.14`, `93.184.216.34`...). Nhưng trong thực tế, khi mở trình duyệt và gõ `google.com`, không ai gõ IP cả. Bài này lấp khoảng trống đó: **domain name được dịch thành IP như thế nào, trước khi packet đầu tiên kịp hình thành ở Network Layer.**

### Mục lục

1. [What — DNS là gì](#1-what--dns-là-gì)
2. [Why — Vấn đề gì tồn tại trước DNS, và DNS mang lại vấn đề gì mới](#2-why--vấn-đề-gì-tồn-tại-trước-dns-và-dns-mang-lại-vấn-đề-gì-mới)
3. [How — Nguyên lý hoạt động của DNS resolution](#3-how--nguyên-lý-hoạt-động-của-dns-resolution)
4. [Where — Khi nào dùng cơ chế nào, trade-off](#4-where--khi-nào-dùng-cơ-chế-nào-trade-off)
5. [Liên hệ với các bài trước](#liên-hệ-với-các-bài-trước)

## 1. What — DNS là gì

**DNS (Domain Name System)** là một hệ thống **phân giải tên miền** (domain name) thành **IP address**, được tổ chức dưới dạng **cơ sở dữ liệu phân tán, phân cấp (distributed hierarchical database)** — không có một server trung tâm nào giữ toàn bộ dữ liệu.

Về bản chất, DNS chỉ làm một việc: nhận vào một **query** dạng `"IP của google.com là gì?"`, trả về một **response** dạng `"142.250.183.14"`. Nhưng câu trả lời đó không nằm sẵn ở một nơi — nó được ráp lại từ nhiều **DNS server** khác nhau, mỗi server chỉ biết một phần nhỏ của toàn bộ namespace.

**Namespace của DNS có cấu trúc cây (giống hệ thống thư mục), đọc từ phải sang trái:**

```
                          . (root)
                         /  |  \
                      com  org  net ...      ← Top-Level Domain (TLD)
                     /
              google.com                      ← Second-Level Domain
             /
    www.google.com                            ← Subdomain / FQDN (Fully Qualified Domain Name)
```

Mỗi domain có một dấu `.` ẩn ở cuối biểu thị root (`www.google.com.`), thường bị trình duyệt tự ẩn đi khi hiển thị.

## 2. Why — Vấn đề gì tồn tại trước DNS, và DNS mang lại vấn đề gì mới

### Painpoint trước khi có DNS

Vào cuối thập niên 1970 – đầu 1980, ARPANET (tiền thân Internet) chỉ có vài trăm host. Việc map "tên máy → IP" được duy trì bằng **một file văn bản duy nhất tên `HOSTS.TXT`**, do Stanford Research Institute (SRI-NIC) quản lý tập trung. Cơ chế:

- Mọi máy trên ARPANET định kỳ **tải file này qua FTP** từ SRI-NIC, lưu local (đây chính là tiền thân của file `/etc/hosts` ngày nay).
- Muốn thêm/sửa một hostname mới → gửi yêu cầu (qua email) đến quản trị viên tại SRI-NIC → họ sửa tay vào `HOSTS.TXT` → mọi máy khác phải tải lại bản mới để thấy thay đổi.

Vấn đề nảy sinh khi mạng lớn dần (Internet đầu 1980 tăng tốc theo cấp hàm mũ, không còn là vài trăm host):

| Vấn đề | Mô tả cụ thể |
| --- | --- |
| **Single point of failure** | SRI-NIC quá tải hoặc gặp lỗi → toàn bộ Internet không cập nhật được hostname mới. |
| **Không scale nổi** | Mỗi máy phải tải lại **toàn bộ** file mỗi khi có một hostname bất kỳ thay đổi ở bất kỳ đâu trên mạng — băng thông và dung lượng file tăng tuyến tính theo số host toàn cầu. |
| **Trễ cập nhật (staleness)** | Giữa lúc SRI-NIC sửa file và lúc mọi máy tải lại, có một khoảng "vùng xám" nơi các máy thấy dữ liệu khác nhau. |
| **Trùng tên (name collision)** | Vì namespace phẳng (flat namespace) — không phân cấp — hai tổ chức không thể tự do đặt cùng một tên máy mà không xin phép trung tâm trước. |

**Ví dụ cụ thể:** Nếu năm 1983 có 1.000 host, và tốc độ tăng trưởng dự đoán gấp đôi mỗi năm, việc bắt mọi máy tải lại một file tăng dần kích thước qua FTP mỗi khi có thay đổi là không khả thi — đây chính là động lực trực tiếp dẫn đến **RFC 882/883 (1983)**, sau này chuẩn hóa thành **RFC 1034/1035 (1987)** — đặt nền cho DNS: một hệ thống **phân cấp** và **phân tán (distributed)**, nơi mỗi tổ chức tự quản lý phần namespace của mình (`.com`, `.org`...) mà không cần xin phép một trung tâm duy nhất cho mỗi thay đổi.

### DNS giải quyết vấn đề cũ bằng cách nào (tóm tắt, chi tiết ở phần How)

- Thay 1 file phẳng bằng **cây phân cấp** → mỗi cấp (root, TLD, domain) chỉ cần biết **con trực tiếp** của mình, không cần biết toàn bộ cây.
- Thay "tải lại toàn bộ" bằng **query theo yêu cầu (on-demand)** + **caching có TTL** → không cần đồng bộ toàn cục ngay lập tức, chấp nhận độ trễ cập nhật có kiểm soát (bounded staleness).

### Vấn đề mới DNS gây ra

| Vấn đề mới | Chi tiết |
| --- | --- |
| **DNS cache poisoning / spoofing** | Vì DNS response ban đầu (trước DNSSEC) không có cơ chế xác thực nguồn gốc, attacker có thể giả mạo response để trỏ domain hợp lệ đến IP độc hại. Ví dụ: Kaminsky Attack (2008) khai thác việc UDP query dùng transaction ID chỉ 16-bit, dễ đoán/brute-force để "chen" response giả trước khi response thật về tới. |
| **Độ trễ truy vấn** | Mỗi lần resolve một domain mới (chưa có trong cache) tốn thêm round-trip network — có thể vài chục đến vài trăm ms trước khi packet đầu tiên của kết nối thật (TCP handshake) kịp bắt đầu. |
| **Privacy leak** | Plain DNS query (qua UDP port 53) đi dưới dạng **cleartext** — ISP hoặc bất kỳ ai can thiệp trên đường truyền đều đọc được domain nào đang được resolve, dù nội dung traffic sau đó có mã hóa (HTTPS) hay không. Đây là động lực ra đời **DoH (DNS over HTTPS)** và **DoT (DNS over TLS)**. |
| **Staleness có kiểm soát nhưng vẫn tồn tại** | TTL cache nghĩa là khi một domain đổi IP (ví dụ failover sang server mới), một số client vẫn thấy IP cũ cho đến khi TTL hết hạn — đây là lý do khi "chuyển server", DevOps thường hạ TTL xuống thấp *trước* thời điểm migrate. |

### Giải pháp khác có tốt hơn không?

Không có giải pháp thay thế toàn phần DNS ở quy mô Internet — bản thân DNS đã được thiết kế lại nhiều lần để vá các vấn đề trên chứ không bị thay thế:

- **DNSSEC** (RFC 4033-4035) — thêm chữ ký số (digital signature) vào response, giải quyết cache poisoning bằng cách cho phép resolver **xác thực nguồn gốc và tính toàn vẹn** của response, dùng chain-of-trust từ root xuống.
- **DoH/DoT** — mã hóa kênh truyền query, giải quyết privacy leak.
- **mDNS (Multicast DNS)** — giải pháp cục bộ cho local network không cần server (dùng trong Bonjour/Avahi để tìm máy in, Chromecast...), không thay thế DNS toàn cục mà bổ sung cho phạm vi LAN, không cần internet.

## 3. How — Nguyên lý hoạt động của DNS resolution

### 3.1. Các thành phần tham gia

| Thành phần | Vai trò |
| --- | --- |
| **Stub resolver** | Thành phần nhỏ trong OS/application (glibc, `getaddrinfo()`) — gửi query, không tự đi hỏi ai, chỉ hỏi 1 resolver được cấu hình sẵn (thường là DNS server trong `/etc/resolv.conf`). |
| **Recursive resolver** | Server "làm hộ" toàn bộ việc tra cứu — nhận query từ stub resolver, tự đi hỏi root → TLD → authoritative, rồi trả về **một** kết quả cuối cùng. Ví dụ: `8.8.8.8` (Google), `1.1.1.1` (Cloudflare), hoặc resolver do ISP cung cấp. |
| **Root server** | 13 địa chỉ IP logic (`a.root-servers.net` đến `m.root-servers.net`, thực chất mỗi địa chỉ được phục vụ bởi hàng trăm máy vật lý qua kỹ thuật anycast) — biết địa chỉ của toàn bộ TLD server. |
| **TLD server** | Biết địa chỉ của authoritative server cho từng domain nằm dưới nó (ví dụ server quản lý `.com` biết ai là authoritative cho `google.com`). |
| **Authoritative name server** | Server nắm **dữ liệu gốc, chính xác nhất** cho một domain cụ thể — trả lời trực tiếp IP thật, không cần hỏi ai khác nữa. |

### 3.2. Luồng resolution đầy đủ (ví dụ cụ thể: resolve `www.example.com`)

Giả sử máy client có IP `192.168.1.10`, được cấu hình recursive resolver là `8.8.8.8`, và đây là lần đầu resolve domain này (cache trống hoàn toàn ở mọi cấp).

```
Client (192.168.1.10)
   |  Query: "www.example.com A record?"
   v
Stub resolver (trong OS)
   |  Query đến resolver cấu hình sẵn
   v
Recursive Resolver (8.8.8.8)
   |
   |-- (1) Query root server: "www.example.com?"
   |        Root trả lời: "Tôi không biết, nhưng hỏi TLD server của .com tại địa chỉ X"
   |        (Đây gọi là "referral" — root không trả IP cuối, chỉ chỉ đường)
   |
   |-- (2) Query TLD server (.com) tại địa chỉ X: "www.example.com?"
   |        TLD trả lời: "Tôi không biết, nhưng authoritative server của example.com ở địa chỉ Y"
   |
   |-- (3) Query Authoritative server tại địa chỉ Y: "www.example.com?"
   |        Authoritative trả lời: "A record = 93.184.216.34, TTL = 3600"
   |
   v
Recursive Resolver nhận IP cuối, lưu vào cache (thời hạn = TTL), trả về cho Stub resolver
   |
   v
Client nhận được 93.184.216.34, bắt đầu TCP handshake đến IP này
```

**Chi tiết quan trọng — đây là truy vấn "đệ quy" (recursive) từ góc nhìn client, nhưng bên trong là "iterative" từ góc nhìn recursive resolver:**

- Client → Recursive resolver: gọi là **recursive query** — client giao toàn quyền, chỉ đợi **một** câu trả lời cuối cùng (IP thật), không tự đi hỏi tiếp.
- Recursive resolver → Root/TLD/Authoritative: gọi là **iterative query** — mỗi bước resolver tự nhận **referral** (gợi ý "hỏi ai tiếp") rồi tự đi hỏi tiếp bước sau, cho đến khi nhận IP thật.

Đây là điểm hay bị nhầm: không phải root/TLD "đệ quy" giúp resolver — chúng chỉ trả referral, resolver phải tự lặp (iterate) qua từng bước.

### 3.3. Cấu trúc một DNS message thật (UDP, port 53)

DNS message gồm 1 header + 4 section, dù là query hay response đều theo cùng cấu trúc:

```
DNS Message:
+------------------+
| Header           |  ID, Flags (QR, Opcode, RCODE...), số lượng record mỗi section
+------------------+
| Question         |  Tên domain cần hỏi + loại record (QTYPE) + class (QCLASS, luôn là IN = Internet)
+------------------+
| Answer           |  Record trả lời trực tiếp (nếu có)
+------------------+
| Authority        |  Referral — trỏ đến server nào biết câu trả lời (khi chưa có Answer)
+------------------+
| Additional       |  Thông tin bổ sung, ví dụ IP của server được nhắc ở Authority (glue record)
+------------------+
```

Ví dụ Header có trường **ID (16-bit)** — dùng để khớp response với đúng query đã gửi (vì UDP không có state như TCP). Đây chính là trường bị khai thác trong Kaminsky Attack đã nói ở phần Why: 16-bit chỉ có 65536 giá trị, brute-force khả thi nếu không kết hợp thêm randomization port nguồn.

### 3.4. Các loại record phổ biến

| Record | Ý nghĩa | Ví dụ |
| --- | --- | --- |
| `A` | Domain → IPv4 | `example.com A 93.184.216.34` |
| `AAAA` | Domain → IPv6 | `example.com AAAA 2606:2800:220:1:248:1893:25c8:1946` |
| `CNAME` | Alias — domain này chính là domain khác | `www.example.com CNAME example.com` |
| `MX` | Server nhận email cho domain | `example.com MX 10 mail.example.com` |
| `NS` | Authoritative name server cho domain | `example.com NS ns1.example.com` |
| `TXT` | Dữ liệu văn bản tự do | Dùng cho xác minh domain (SPF, DKIM, Google Search Console...) |
| `PTR` | IP → Domain (reverse lookup), nằm trong zone đặc biệt `in-addr.arpa` | `34.216.184.93.in-addr.arpa PTR example.com` |
| `SOA` | Thông tin quản trị zone (primary NS, serial number, TTL mặc định) | Nằm ở gốc mỗi zone |

**Lưu ý về `CNAME`:** khi resolver gặp `CNAME`, nó không dừng lại — nó tiếp tục resolve domain đích của CNAME đó cho đến khi ra được `A`/`AAAA` record thật. Ví dụ `www.example.com CNAME example.com`, rồi `example.com A 93.184.216.34` — client chỉ nhận IP cuối, không thấy bước trung gian trừ khi tra bằng công cụ debug (`dig`).

### 3.5. Caching và TTL

Mỗi record có một **TTL (Time To Live, đơn vị giây)** do authoritative server quy định — khoảng thời gian resolver được phép **giữ (cache) kết quả** trước khi phải hỏi lại.

- **Recursive resolver cache**: cache dùng chung cho mọi client hỏi qua nó — TTL hết hạn thì entry bị xóa, query tiếp theo phải đi lại từ đầu (hoặc từ TLD, nếu Root/TLD referral vẫn còn hạn cache riêng của chúng).
- **OS-level cache** (ví dụ `systemd-resolved` trên Ubuntu): cache một lớp nữa ngay trên máy client, trước khi kịp gửi ra recursive resolver.
- **Browser cache**: một lớp cache thứ ba, thời gian sống thường ngắn hơn TTL DNS gốc (một số browser tự áp giới hạn riêng, ví dụ Chrome giới hạn tối đa 1 phút bất kể TTL DNS thật là bao nhiêu, để giảm rủi ro DNS rebinding).

**Ví dụ cụ thể về hệ quả TTL khi thay đổi hạ tầng:** Nếu `example.com` có TTL = `3600` (1 giờ) và admin đổi IP server lúc `10:00`, một resolver đã cache IP cũ lúc `9:30` sẽ tiếp tục trả IP cũ cho đến `10:30` — đúng 1 giờ sau lần cache gần nhất, **không phải** 1 giờ sau khi admin đổi IP. Đây là lý do best practice khi migrate server: hạ TTL xuống thấp (ví dụ `60`) từ **trước** thời điểm dự kiến đổi IP, đợi TTL cũ hết hạn hoàn toàn trên toàn mạng, rồi mới đổi IP thật — để giảm thời gian client thấy IP cũ.

## 4. Where — Khi nào dùng cơ chế nào, trade-off

| Tình huống | Cơ chế nên dùng | Vì sao |
| --- | --- | --- |
| Ứng dụng thông thường (web, mobile) resolve domain public | Recursive resolver do OS/ISP cấu hình sẵn, hoặc resolver public (`1.1.1.1`, `8.8.8.8`) | Không cần tự đi iterative — chi phí vận hành do resolver gánh. |
| Cần domain riêng trong LAN, không cần lộ ra internet | **mDNS** (Avahi/Bonjour) hoặc DNS server nội bộ tự host | Không cần đăng ký domain public, hoạt động cả khi mất internet. |
| Cần chống DNS spoofing/cache poisoning ở mức cao (ví dụ hệ thống tài chính, chính phủ) | **DNSSEC** | Đánh đổi: cần toàn bộ chain (root → TLD → domain) đều ký số, độ trễ resolve tăng nhẹ do phải verify signature. |
| Cần giữ riêng tư nội dung domain đang truy vấn (tránh ISP/mạng công cộng theo dõi) | **DoH** hoặc **DoT** | Đánh đổi: khó cho tổ chức áp dụng parental control/firewall theo domain ở tầng network truyền thống, vì traffic DNS giờ trông giống HTTPS thường (đặc biệt DoH dùng chung port 443). |
| Cần độ trễ thấp nhất, chấp nhận rủi ro thấp về bảo mật/riêng tư | Plain DNS (UDP port 53), TTL cao | Đơn giản, tương thích ngược tốt nhất, nhưng cleartext và không chống spoofing. |
| Hạ tầng cần failover nhanh (multi-region, disaster recovery) | TTL thấp (dưới 60-300s) kết hợp health check + DNS record tự động đổi | Đánh đổi: TTL thấp làm tăng tải query (ít cache hit hơn), một số resolver/OS vẫn "cứng đầu" giữ cache lâu hơn TTL quy định (không phải mọi resolver tuân thủ TTL nghiêm ngặt 100%). |
| Load balancing đơn giản không cần logic phức tạp | **DNS round-robin** (nhiều `A` record cho cùng 1 domain) | Đơn giản, không cần thiết bị load balancer riêng, nhưng không biết health của backend — vẫn có thể trả về IP của server đã chết cho đến khi record được cập nhật. |

**Phần cần tìm hiểu thêm nếu muốn đào sâu hơn nữa** (ngoài phạm vi bài này):
- **Anycast routing** — cách 13 root server "logic" thực chất chạy trên hàng trăm địa điểm vật lý toàn cầu, cùng chia sẻ 1 IP, và BGP quyết định client nào đi tới node nào gần nhất (liên quan trực tiếp đến [Internet-Topology.md](Internet-Topology.md)).
- **DNSSEC chain-of-trust chi tiết** (RRSIG, DNSKEY, DS record) — cơ chế ký số và verify từng cấp.
- **EDNS0 và DNS Cookie** — mở rộng giao thức DNS gốc để hỗ trợ message lớn hơn 512 byte (giới hạn UDP truyền thống) và chống một số dạng spoofing mới hơn Kaminsky Attack.

## Liên hệ với các bài trước

- [ARP.md](ARP.md) giải thích cách packet di chuyển trong 1 local network **khi đã biết** destination IP.
- [NAT.md](NAT.md) giải thích packet thoát ra internet như thế nào, cũng **giả định đã biết** destination IP/port.
- [Internet-Topology.md](Internet-Topology.md) giải thích packet, sau khi đã có IP đích, đi qua cấu trúc router toàn cầu (Tier 1/2/3) như thế nào.
- Bài này lấp đúng khoảng trống nằm **trước tất cả các bước trên**: domain name → IP address, xảy ra hoàn toàn ở tầng ứng dụng (DNS dùng UDP/TCP port 53), trước khi packet đầu tiên của kết nối thật kịp hình thành ở Network Layer.
