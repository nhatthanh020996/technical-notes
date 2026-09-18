# NAT: Khi Destination Nằm Ngoài Internet

## Bài toán đặt ra

Ở bài [ARP: Từ Packet Đến Ethernet Frame](ARP.md), ta đã giải thích cách một packet đi từ LaptopA (`192.168.1.10`) đến LaptopB (`192.168.1.14`) — cả hai đều nằm trong cùng một local network.

Bây giờ, giả sử LaptopA muốn kết nối đến một server ngoài internet, ví dụ `93.184.216.34:443` (HTTPS). Destination IP này **không nằm trong subnet** `192.168.1.0/24`, nên theo phần so sánh subnet mask đã nói ở bài trước, packet sẽ phải được gửi qua **default gateway** — tức là router (`192.168.1.1`).

> **Câu hỏi:** `192.168.1.10` là một địa chỉ private IP, không route được trên internet. Vậy khi packet ra khỏi router, Source IP của nó là gì? Và khi response quay về, làm sao router biết phải trả lời cho đúng `192.168.1.10`?

Đây chính là vai trò của **NAT (Network Address Translation)**, cụ thể là **NAPT / PAT (Port Address Translation)** — cơ chế mà hầu hết router gia đình và doanh nghiệp nhỏ đang dùng.

## PAT là gì?

**PAT (Port Address Translation)** là một biến thể của NAT, trong đó router đổi **cả IP lẫn port** để nhiều máy trong LAN có thể dùng chung **một** địa chỉ IP public duy nhất khi ra internet. PAT còn được gọi là **NAT overload**.

- **NAT cơ bản (Basic NAT / 1-to-1 NAT):** chỉ đổi IP, ánh xạ **1 private IP ↔ 1 public IP**. Đòi hỏi router phải có nhiều public IP — mỗi máy trong LAN cần một public IP riêng, không tiết kiệm được gì.
- **PAT:** đổi **cả IP lẫn port**, cho phép **nhiều private IP dùng chung một public IP**, phân biệt các kết nối dựa vào port thay vì IP. Vì có tới 65536 port khả dụng trên một IP, một router PAT có thể phục vụ hàng chục nghìn kết nối đồng thời chỉ với một IP public duy nhất.

Đây là lý do PAT là cơ chế phổ biến nhất ở router gia đình/doanh nghiệp nhỏ hiện nay — dù về bản chất kỹ thuật chính xác là PAT, người ta vẫn thường gọi tắt là "NAT". Toàn bộ ví dụ trong tài liệu này (Bước 1–3 bên dưới) chính là mô tả chi tiết cách PAT hoạt động.

## Toàn cảnh luồng đi

```
   LAN (private)                    Router (NAT)                  Internet (public)
 192.168.1.10:54321  ---outbound-->  203.0.113.5:40001  ---------> 93.184.216.34:443
 192.168.1.10:54321  <--inbound----  203.0.113.5:40001  <--------- 93.184.216.34:443
                       (tra NAT table
                        để dịch ngược)
```

- Chiều đi (outbound): router dịch **Source** — private → public.
- Chiều về (inbound): router dịch **Destination** — public → private, dựa vào NAT table đã ghi ở chiều đi.
- Destination (server ngoài internet) không đổi ở cả hai chiều — nó không hề biết máy thật sự phía sau NAT là ai.

## Vì sao cần NAT

- Private IP (dải `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`) chỉ có ý nghĩa trong local network, không được route trên internet công cộng.
- Router chỉ có **một (hoặc một vài) IP public** do ISP cấp, trong khi có thể có hàng chục thiết bị private IP phía sau nó cùng cần truy cập internet.
- NAT giải quyết bài toán: cho phép nhiều private IP **dùng chung** một public IP để giao tiếp ra ngoài, đồng thời vẫn định tuyến được response quay về đúng máy.

## Bước 1 — Gói tin đi ra (Outbound)

Khi packet từ `192.168.1.10` đến router để đi ra ngoài internet, router sẽ:

1. Thay **Source IP** private (`192.168.1.10`) bằng **IP public** của chính router (ví dụ `203.0.113.5`).
2. Thay **Source Port** gốc bằng một port khác do router tự chọn (để tránh trùng với các kết nối khác đang dùng chung public IP).
3. Ghi lại một **entry trong NAT table** để nhớ ánh xạ này.

| Trường | Trước NAT | Sau NAT |
| --- | --- | --- |
| Source IP | `192.168.1.10` | `203.0.113.5` |
| Source Port | `54321` | `40001` |
| Destination IP | `93.184.216.34` | `93.184.216.34` |
| Destination Port | `443` | `443` |

NAT table của router lúc này có thêm entry:

| Private IP:Port | Public IP:Port | Destination IP:Port |
| --- | --- | --- |
| `192.168.1.10:54321` | `203.0.113.5:40001` | `93.184.216.34:443` |

> Vì router đổi cả Source IP lẫn Source Port, kỹ thuật này được gọi chính xác là **PAT (Port Address Translation)** — một dạng của NAT, đôi khi gọi là NAT overload vì nhiều private IP:port cùng ánh xạ vào một public IP với các port khác nhau.

### NAT/PAT sửa đổi ở layer nào?

Việc "thay Source IP private bằng public IP" xảy ra ở **Network Layer (Layer 3)** — router mở **IP header** của packet, ghi đè trường Source IP, rồi đóng gói lại. Đây thuần túy là sửa đổi ở Layer 3, không liên quan gì đến Ethernet frame hay MAC address.

Vì router còn đổi cả **Source Port** (để hỗ trợ nhiều máy dùng chung một public IP), mà port nằm trong **TCP/UDP header — Transport Layer (Layer 4)**, nên nói chính xác:

> **NAT/PAT sửa đổi cả Layer 3 (IP header: Source/Destination IP) lẫn Layer 4 (TCP/UDP header: Source/Destination Port)**.

Cần phân biệt với việc **Source MAC / Destination MAC** (Layer 2) cũng bị đổi tại mỗi hop khi packet đi qua router — nhưng đó là hành vi routing bình thường (MAC luôn đổi giữa hai đầu của mỗi link), **không phải** là một phần của NAT. NAT không động đến Ethernet frame.

Một router **routing thông thường** chỉ cần đọc đến **Layer 3** (IP header) là đủ để biết forward gói đi đâu — nó không cần quan tâm Layer 4. Nhưng một router làm **NAT/PAT** bắt buộc phải bóc thêm đến **Layer 4** để đọc/ghi TCP hoặc UDP header (đổi port), vì chỉ dựa vào IP thôi thì không đủ phân biệt nhiều máy dùng chung một public IP.

**Layer 4 cũng chính là giới hạn của NAT** — nó dừng lại ở đó, không đọc (và không nên đọc) vào **payload ứng dụng (Layer 7)**. Đây là lý do một số giao thức cũ nhúng địa chỉ IP/port ngay trong payload để báo phía kia mở kết nối riêng (ví dụ FTP active mode: client gửi lệnh `PORT` chứa IP:port của chính nó nằm trong nội dung lệnh, không nằm trong header) thường gặp lỗi khi đi qua NAT: NAT chỉ sửa được Source/Destination IP:Port ở header Layer 3/4, không thấy và không sửa được địa chỉ IP private nằm "chìm" trong payload — khiến server nhận được thông tin sai (IP private, không route được) và không kết nối lại được.

Cách khắc phục thường gặp:
- Đổi sang **FTP passive mode**, giao thức không còn nhúng địa chỉ vào payload theo kiểu đó nữa, hoặc
- Router dùng thêm module **ALG (Application Layer Gateway)** — một cơ chế "đặc cách" hiểu trước cấu trúc của từng giao thức cụ thể (FTP, SIP, ...), cho phép NAT bóc sâu hơn Layer 4 *chỉ với những giao thức đã biết trước* để sửa luôn cả địa chỉ nằm trong payload.

### Nhiều máy dùng chung một public IP cùng lúc

Đây là lúc vai trò của port trong NAT table thể hiện rõ nhất. Giả sử cả `192.168.1.10` và `192.168.1.14` cùng lúc kết nối ra internet:

| Private IP:Port | Public IP:Port | Destination IP:Port |
| --- | --- | --- |
| `192.168.1.10:54321` | `203.0.113.5:40001` | `93.184.216.34:443` |
| `192.168.1.14:33445` | `203.0.113.5:40002` | `93.184.216.34:443` |
| `192.168.1.10:51000` | `203.0.113.5:40003` | `172.217.0.1:443` |

Cả ba dòng đều dùng chung một public IP (`203.0.113.5`), kể cả khi hai dòng đầu cùng gửi đến cùng một server đích (`93.184.216.34:443`). Router phân biệt được các luồng này chỉ nhờ **public port khác nhau** (`40001`, `40002`, `40003`). Nếu không có cơ chế đổi port, router sẽ không thể biết một gói response từ `93.184.216.34:443` là dành cho `192.168.1.10` hay `192.168.1.14`.

## Bước 2 — Server nhận gói và trả lời

Server `93.184.216.34` chỉ nhìn thấy packet đến từ `203.0.113.5:40001`. Nó không biết gì về `192.168.1.10` hay mạng nội bộ phía sau router. Server phản hồi bằng cách gửi ngược lại đúng địa chỉ nó nhận được:

| Trường | Giá trị |
| --- | --- |
| Source IP | `93.184.216.34` |
| Source Port | `443` |
| Destination IP | `203.0.113.5` |
| Destination Port | `40001` |

## Bước 3 — Gói tin quay về (Inbound), tra NAT table

Gói response đến router tại `203.0.113.5:40001`. Router tra NAT table theo cặp **(Destination IP:Port)** vừa nhận được:

- Tìm entry có **Public IP:Port** = `203.0.113.5:40001` → khớp với entry đã lưu ở Bước 1.
- Từ entry đó, router biết gói này thực chất phải trả về cho `192.168.1.10:54321`.

Router **đổi ngược** Destination IP:Port trong gói:

| Trường | Trước (khi đến router) | Sau (khi vào LAN) |
| --- | --- | --- |
| Destination IP | `203.0.113.5` | `192.168.1.10` |
| Destination Port | `40001` | `54321` |

Sau đó router forward gói vào LAN, đến đúng `192.168.1.10:54321` — nơi ứng dụng (ví dụ trình duyệt) đang chờ response trên port đó.

## Vì sao cần cả Port, không chỉ IP?

Vì tất cả thiết bị trong LAN (`192.168.1.10`, `192.168.1.11`, `192.168.1.14`, ...) cùng dùng chung **một IP public** duy nhất của router. Router không thể phân biệt các kết nối chỉ dựa vào IP — nó phải dựa vào **port** để biết gói inbound này thuộc về máy nội bộ nào.

Đây là lý do PAT còn hay được ví như một "bảng điện thoại nội bộ": nhiều máy trong nhà dùng chung một số điện thoại chính (public IP), nhưng mỗi cuộc gọi được gắn với một số máy lẻ (port) khác nhau để lễ tân (router) biết chuyển cuộc gọi đến đúng người.

## Các kiểu NAT (theo mức độ nghiêm ngặt khi lọc inbound)

Không phải mọi router đều tra NAT table theo cùng một cách. RFC 3489 (STUN) phân loại hành vi NAT thành 4 kiểu, ảnh hưởng trực tiếp đến việc thiết bị ngoài internet có thể "chen ngang" vào một entry NAT đã mở hay không:

| Kiểu NAT | Router chấp nhận gói inbound từ | Ghi chú |
| --- | --- | --- |
| **Full Cone** | Bất kỳ ai gửi đến đúng `public IP:port` đã map | Lỏng nhất — một khi entry mở, ai cũng gửi vào được |
| **Restricted Cone** | Chỉ IP đã từng nhận gói outbound tới | Kiểm tra thêm Destination IP đã từng thấy chưa |
| **Port-Restricted Cone** | Chỉ đúng `IP:port` đã từng nhận gói outbound tới | Kiểm tra cả IP lẫn port |
| **Symmetric** | Chỉ đúng `IP:port` của phiên đó, và **mỗi destination khác nhau được cấp một public port khác nhau** | Chặt nhất — khó NAT traversal nhất (thường gây khó cho video call P2P, gaming) |

Ví dụ ở phần "Bước 3" phía trên là hành vi của **Port-Restricted Cone / Symmetric NAT** — router chỉ chấp nhận response đúng từ `93.184.216.34:443`, khớp với entry đã lưu.

## Port Forwarding và UPnP — khi cần inbound chủ động

Bình thường NAT chỉ cho phép traffic **do LAN khởi tạo trước** đi qua chiều ngược lại. Nhưng có những trường hợp cần một thiết bị ngoài internet **chủ động kết nối vào** một máy trong LAN (ví dụ: host một game server, một web server tại nhà, hay port SSH để truy cập từ xa). Khi đó cần tạo entry NAT **thủ công**, không đợi có gói outbound trước:

- **Port Forwarding (static NAT rule):** người dùng vào trang cấu hình router, khai báo cố định "mọi gói đến `203.0.113.5:8080` → forward vào `192.168.1.10:8080`". Entry này tồn tại vĩnh viễn, không phụ thuộc timeout hay có traffic outbound trước đó.
- **UPnP (Universal Plug and Play) / NAT-PMP:** ứng dụng trong LAN (ví dụ phần mềm torrent, ứng dụng chơi game) tự động gửi yêu cầu đến router qua giao thức UPnP, xin mở một port cụ thể và tự tạo entry NAT tạm thời — không cần người dùng vào router cấu hình tay. Đây là lý do một số ứng dụng "tự nhiên connect được" mà không cần cấu hình gì.

## Một số điểm quan trọng

- **NAT table có timeout.** Nếu không có traffic qua lại trong một khoảng thời gian (tùy loại giao thức, thường vài phút với TCP, ngắn hơn với UDP), entry sẽ bị xóa khỏi bảng. Đây là lý do các kết nối long-lived (như WebSocket) cần cơ chế keep-alive để giữ entry NAT không bị xóa giữa chừng.
- **NAT hoạt động như một lớp bảo vệ ngầm (implicit firewall).** Nếu router nhận được một gói inbound mà **không có entry nào khớp** trong NAT table — tức không phải response cho một kết nối do máy trong LAN chủ động khởi tạo — router sẽ **drop gói** đó. Đây là lý do một thiết bị từ internet không thể tự ý kết nối vào máy trong LAN, trừ khi có port forwarding hoặc UPnP như trên.
- **NAT không thay đổi bản chất của Ethernet/ARP đã học ở bài trước.** Việc dịch địa chỉ này xảy ra ở **Network Layer** (IP) và **Transport Layer** (port), hoàn toàn tách biệt với việc tạo Ethernet frame và ARP resolution ở **Data Link Layer** — hai cơ chế này chạy ở các layer khác nhau, trong cùng một router nhưng độc lập với nhau.
- **NAT làm tăng độ trễ (dù rất nhỏ) và phá vỡ tính "end-to-end" thuần túy của IP.** Một số giao thức (như IPsec ở chế độ AH, hoặc các ứng dụng nhúng địa chỉ IP vào payload thay vì chỉ dùng header) có thể gặp vấn đề khi đi qua NAT vì payload không được router hiểu để dịch theo.
- **IPv6 được thiết kế để giảm sự phụ thuộc vào NAT**, vì không gian địa chỉ đủ lớn để mỗi thiết bị có một địa chỉ public riêng — khi đó việc định tuyến inbound/outbound đơn giản hơn nhiều, nhưng đổi lại cần các cơ chế firewall khác để bù cho lớp bảo vệ ngầm mà NAT vô tình mang lại.
