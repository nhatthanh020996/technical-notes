# ARP: Từ Packet Đến Ethernet Frame

## Bài toán đặt ra

Giả sử chúng ta có một local network như hình vẽ sau, đây là một local network đơn giản và phổ biến trong một hộ gia đình hoặc doanh nghiệp vừa và nhỏ.

![Local network topology](Screenshot%20from%202025-01-09%2014-14-01.png)

> **Câu hỏi:** Làm thế nào để có thể truyền một packet từ LaptopA sang LaptopB?

Lưu ý Protocol Data Unit ở đây là `packet` nên mình sẽ chỉ giải thích đường đi từ network layer trở xuống trong mô hình OSI.

## Thông tin ban đầu

Packet được gửi từ network layer của `192.168.1.10` đến network layer của `192.168.1.14`, nên ta xác định được các thông tin sau:

| Trường | Giá trị |
| --- | --- |
| Source IP | `192.168.1.10` |
| Source MAC | `01-23-45-67-89-ab` |
| Destination IP | `192.168.1.14` |
| Destination MAC | *(chưa biết — cần ARP)* |
| Subnet mask | `255.255.255.0` |
| Router IP | `192.168.1.1` |

> Tất cả các devices trong local network sẽ learn được địa chỉ IP của router tại thời điểm chúng được cấp phát địa chỉ private IP thông qua DHCP protocol.

## Bước 1 — Packet hình thành tại Network Layer

Sau khi packet được hình thành tại network layer ở `192.168.1.10`, packet sẽ trông như sau:

| Source IP | Destination IP | Segment Data |
| --- | --- | --- |
| `192.168.1.10` | `192.168.1.14` | ... |

## Bước 2 — Tra ARP table, cần Destination MAC

Tại Data Link Layer của `192.168.1.10`, packet trên cần được đóng gói thành một Ethernet frame — nhưng trước tiên phải biết được destination MAC.

Trước khi tra ARP table, `192.168.1.10` phải xác định **resolve MAC cho IP nào**, bằng cách so sánh 2 kết quả `(192.168.1.10 AND 255.255.255.0)` và `(192.168.1.14 AND 255.255.255.0)`:
- Nếu 2 kết quả này giống nhau → hai máy cùng subnet → cần ARP cho chính destination IP (`192.168.1.14`).
- Nếu 2 kết quả này khác nhau → khác subnet → cần ARP cho router IP (`192.168.1.1`), vì gói tin phải được route qua default gateway trước.

Trong trường hợp này, `192.168.1.10` kiểm tra trong ARP table của chính nó để biết được MAC của `192.168.1.14`. Nếu MAC chưa tồn tại trong ARP table, Address Resolution Protocol (ARP) sẽ được sử dụng để lấy destination MAC.

### 2.1. Gửi ARP Request (broadcast)

Từ data link layer của `192.168.1.10`, một ARP request sẽ được gửi đi để hỏi MAC ứng với IP cần resolve đã xác định ở bước trên. ARP request sẽ trông như sau:

```
ARP Request Frame:
                     Ethernet Header
+-------------------+-------------------+-----------------+
| Source MAC        | Destination MAC   | Type            |
| 01-23-45-67-89-ab | FF:FF:FF:FF:FF:FF | ARP (0x0806)    |
+-------------------+-------------------+-----------------+

                     ARP Message
+--------------------------------------------------+
| Operation:  Request (1)                          |
| Sender MAC: 01-23-45-67-89-ab                    |
| Sender IP:  192.168.1.10                         |
| Target MAC: 00:00:00:00:00:00                    |
| Target IP:  192.168.1.14                         |
+--------------------------------------------------+
```

- Với Destination MAC là `FF:FF:FF:FF:FF:FF`, khi switch nhận được request này sẽ tiến hành broadcast request trên tất cả các ports của nó ngoại trừ port của sender.
- Target MAC = `00:00:00:00:00:00` → để indicate rằng destination MAC vẫn chưa được xác định.
- Target IP chính là IP cần resolve MAC đã xác định ở bước trên — trong trường hợp này là `192.168.1.14` vì hai máy cùng subnet.

### 2.2. Switch broadcast request

Khi nhận được request trên, switch sẽ tiến hành broadcast request ra toàn bộ ports của nó (trừ port của request sender). Trong trường hợp này những devices nhận được ARP request sẽ là: `192.168.1.11`, `192.168.1.12`, `192.168.1.14`, và `192.168.1.1`.

Các device này sẽ kiểm tra xem Target IP trong request có match với private IP của mình hay không:
- Nếu không match sẽ tiến hành discard request mà không response lại.
- Trong trường hợp này, device với IP `192.168.1.14` sẽ tiến hành respond lại ARP reply.

### 2.3. ARP Reply

Message ARP reply sẽ trông như sau:

```
ARP Response Frame:
                     Ethernet Header
+-------------------+-------------------+-----------------+
| Source MAC        | Destination MAC   | Type            |
| cd-ef-12-34-56-78 | 01-23-45-67-89-ab | ARP (0x0806)    |
+-------------------+-------------------+-----------------+

                     ARP Message
+--------------------------------------------------+
| Operation:  Reply (2)                            |
| Sender MAC: cd-ef-12-34-56-78                    |
| Sender IP:  192.168.1.14                         |
| Target MAC: 01-23-45-67-89-ab                    |
| Target IP:  192.168.1.10                         |
+--------------------------------------------------+
```

- Source MAC là MAC address của device với IP `192.168.1.14`.
- Destination MAC là MAC address của device gửi request.
- Operation = 2 để indicate đây là ARP reply.
- Sender MAC và Sender IP là thông tin của device đang gửi response.
- Target MAC và Target IP là thông tin của device đã gửi request.

### 2.4. Cập nhật ARP table

Sau khi lấy được Destination MAC từ ARP reply trên, ARP module của `192.168.1.10` sẽ update Destination IP và Destination MAC vào ARP table.

## Bước 3 — Đóng gói Ethernet Frame hoàn chỉnh

Sau khi lấy được destination MAC, ethernet frame sẽ trông như sau:

| Source MAC | Destination MAC | EtherType | Packet Data | FCS |
| --- | --- | --- | --- | --- |
| `01-23-45-67-89-ab` | `cd-ef-12-34-56-78` | IPv4 (0x0800) | ... | ... |

## Bước 4 — Truyền xuống Physical Layer

Tất cả ethernet frames sẽ được chuyển xuống physical layer, tại đây NIC sẽ chuyển từ digital binary data sang physical signals. Physical signal type như thế nào thì còn phụ thuộc vào NIC loại nào:
- Nếu NIC cho cổng mạng LAN thì signal type là `electrical signal`.
- Nếu NIC cho mạng wifi thì signal type là `radio frequency signal`.

Khi physical signals được đưa đến hop tiếp theo bằng LAN cable (trong trường hợp này), hop tiếp theo chính là switch. Trong switch sẽ có thiết bị giúp chuyển đổi physical signals thành digital signal. Switch sẽ tra MAC address table (bảng học được từ source MAC của các frame đi qua) để xác định frame cần forward tới port nào, dựa vào destination MAC:
- Nếu MAC đã có trong bảng, switch sẽ forward (unicast) đúng port đó.
- Nếu MAC chưa có trong bảng (chưa từng học được), switch sẽ flood frame ra tất cả các port (trừ port nhận vào), tương tự broadcast, cho đến khi học được.

Trong trường hợp này destination MAC là `cd-ef-12-34-56-78`, và frames sẽ được forward về port mà device có MAC = `cd-ef-12-34-56-78`.

Device `cd-ef-12-34-56-78` nhận được frames và tiến hành bóc tách để lấy được những protocol data unit ở những layer phía trên trong mô hình OSI.
