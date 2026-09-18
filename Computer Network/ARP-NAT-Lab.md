# Lab: Chứng Minh ARP và NAT/PAT Trên Máy Thật

Tài liệu này là phần **thực hành kiểm chứng** cho hai bài lý thuyết:
- [ARP: Từ Packet Đến Ethernet Frame](ARP.md)
- [NAT: Khi Destination Nằm Ngoài Internet](NAT.md)

Toàn bộ lệnh dưới đây chỉ **quan sát** (đọc trạng thái mạng, bắt gói), không thay đổi cấu hình hệ thống — an toàn để chạy trên máy Ubuntu cá nhân. Một vài lệnh xóa ARP cache tạm thời (tự phục hồi ngay sau khi ping) và cần quyền `sudo`.

## Chuẩn bị: xác định interface và gateway thật

Trước khi chạy bất kỳ kịch bản nào, xác định thông tin mạng thật của máy bạn — vì các giá trị `192.168.1.x` trong ARP.md/NAT.md chỉ là ví dụ minh họa:

```bash
ip -brief addr show          # tìm interface đang UP với IP thật (không phải docker0/veth...)
ip route show default        # xem default gateway
```

Ví dụ trên một máy cụ thể: interface `wlp0s20f3`, IP `192.168.2.27/24`, gateway `192.168.2.1`. Thay các giá trị này vào mọi lệnh bên dưới cho khớp với máy của bạn.

## Kịch bản 1 — Bắt trực tiếp ARP Request/Reply

**Đối chiếu với:** phần "Bước 2 — Tra ARP table, cần Destination MAC" trong [ARP.md](ARP.md).

**Ý tưởng:** ép máy xóa MAC của gateway khỏi ARP table (để mô phỏng trạng thái "chưa biết MAC" trong tài liệu), sau đó ping gateway để buộc ARP phải chạy lại từ đầu, đồng thời bắt gói bằng `tcpdump`.

**Bước 1 — Mở 2 terminal.**

Terminal A (bắt gói ARP, chạy trước và giữ chạy):
```bash
sudo tcpdump -i wlp0s20f3 arp -n -v
```

Terminal B (xóa ARP cache của gateway, rồi ping):
```bash
sudo ip neigh del 192.168.2.1 dev wlp0s20f3
ping -c 1 192.168.2.1
```

**Kết quả kỳ vọng ở Terminal A:**
```
ARP, Request who-has 192.168.2.1 tell 192.168.2.27, length 28
ARP, Reply 192.168.2.1 is-at 14:49:bc:99:19:30, length 46
```

**Đối chiếu với lý thuyết:**
| Quan sát thực tế | Khớp với phần nào trong ARP.md |
| --- | --- |
| Dòng `Request who-has ... tell ...` | ARP Request — Operation = 1, Target MAC = `00:00:00:00:00:00` |
| Dòng `Reply ... is-at ...` | ARP Reply — Operation = 2, Sender MAC = MAC thật của gateway |
| Chỉ có đúng 1 request + 1 reply, không có nhiều reply khác | Chỉ thiết bị có IP trùng Target IP mới respond, các thiết bị khác discard |

**Bước 2 — Xác nhận ARP table được cập nhật lại:**
```bash
ip neigh show dev wlp0s20f3
```
Kỳ vọng thấy lại dòng `192.168.2.1 lladdr 14:49:bc:99:19:30 REACHABLE` — đúng như mục "2.4. Cập nhật ARP table" trong ARP.md.

## Kịch bản 2 — Xác nhận EtherType trong Ethernet Frame

**Đối chiếu với:** "Bước 3 — Đóng gói Ethernet Frame hoàn chỉnh" trong [ARP.md](ARP.md), phần bảng có cột `EtherType`.

```bash
sudo tcpdump -i wlp0s20f3 -e -n icmp
```

Ở một terminal khác, tạo traffic ICMP:
```bash
ping -c 3 8.8.8.8
```

**Kết quả kỳ vọng:**
```
aa:bb:cc:dd:ee:ff > 14:49:bc:99:19:30, ethertype IPv4 (0x0800), length 98: 192.168.2.27 > 8.8.8.8: ICMP echo request
```

**Đối chiếu:** `ethertype IPv4 (0x0800)` chính là giá trị EtherType mà bảng Ethernet frame trong ARP.md liệt kê cho packet IP thật, phân biệt với `ethertype ARP (0x0806)` đã thấy ở Kịch bản 1.

## Kịch bản 3 — Chứng minh PAT đổi Source IP:Port khi ra internet

**Đối chiếu với:** [NAT.md](NAT.md), đặc biệt mục "Bước 1 — Gói tin đi ra (Outbound)".

Vì máy Ubuntu ở đây là **client phía sau NAT**, không phải router, nên không đọc được NAT table thật của router. Thay vào đó, ta chứng minh **hệ quả** của NAT: private IP:port nội bộ khác với public IP:port mà server bên ngoài nhìn thấy.

**Bước 1 — Xem private IP:port thật khi mở một kết nối:**
```bash
(curl -s https://ifconfig.me > /tmp/pub_ip.txt &) ; sleep 0.3 ; ss -tn state established '( dport = :443 )'
```
Kỳ vọng thấy dòng dạng `192.168.2.27:53412 -> 34.117.x.x:443` — đây chính là Source IP:Port **trước khi qua NAT**, khớp cột "Trước NAT" trong bảng ở NAT.md.

**Bước 2 — Xem public IP mà server thật sự nhận được:**
```bash
cat /tmp/pub_ip.txt
```
Kết quả là một IP hoàn toàn khác `192.168.2.27` — đây chính là public IP mà router đã dịch Source IP sang, khớp cột "Sau NAT" trong bảng ở NAT.md.

**Giới hạn của thí nghiệm này:** client chỉ thấy được private port của chính nó (`53412` trong ví dụ), không thấy được public port mà router đã đổi sang (ví dụ `40001` trong NAT.md) — vì bản chất one-way visibility của NAT: chỉ router (và server đích) biết ánh xạ đầy đủ, client không có cách nào tự quan sát port sau NAT nếu không có quyền truy cập router.

## Kịch bản 4 (nâng cao, tùy chọn) — Xem NAT table thật nếu có Docker

Nếu máy có cài Docker, container publish port chính là một ví dụ NAT/PAT thật chạy ngay trên máy (Docker dùng `iptables` NAT để forward port từ host vào container):

```bash
docker run -d -p 8080:80 --name nat-demo nginx
sudo iptables -t nat -L -n -v | grep -A 5 DOCKER
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080
docker rm -f nat-demo
```

Dòng rule `DNAT` trong output `iptables -t nat -L` chính là một entry NAT table thật — ánh xạ `host:8080` → `172.17.0.x:80` (IP nội bộ của container), tương tự cơ chế Port Forwarding đã mô tả trong mục "Port Forwarding và UPnP" ở NAT.md.

## Ghi chú về nguồn kiến thức

Nội dung lý thuyết trong ARP.md và NAT.md dựa trên kiến thức nền tổng hợp, tham chiếu gần nhất với:
- **RFC 826** — ARP
- **RFC 3022** — Traditional IP NAT
- **RFC 3489** (đã deprecated bởi RFC 5389/8489) — phân loại 4 kiểu NAT

Các lệnh trong lab này là cách đối chiếu trực tiếp, độc lập với nguồn — nếu kết quả tcpdump/ss/iptables không khớp với mô tả lý thuyết, ưu tiên tin vào kết quả quan sát thực tế trên máy.
