# Cấu Trúc Mạng Lưới Internet

Các bài trước ([ARP.md](ARP.md), [NAT.md](NAT.md)) giải thích cách một packet đi trong **local network** và cách nó thoát ra internet qua NAT. Bài này zoom ra một tầm nhìn lớn hơn: **sau khi thoát khỏi router nhà bạn, packet đi qua một mạng lưới router có cấu trúc như thế nào để đến được đích ở bất kỳ đâu trên thế giới?**

## Bài toán đặt ra

> **Câu hỏi:** Internet có hàng chục nghìn mạng (ISP, doanh nghiệp, chính phủ...) và hàng tỷ thiết bị. Liệu 2 router bất kỳ trên Internet có liên kết trực tiếp với nhau không? Nếu không, mạng lưới này được tổ chức theo dạng gì — cây (tree) hay dạng khác?

## Không có chuyện 2 router bất kỳ nối trực tiếp nhau

Giả sử có N router, để **mọi cặp** đều liên kết trực tiếp (full mesh) thì cần số liên kết là:

```
N × (N-1) / 2
```

Với N chỉ cỡ vài chục nghìn router lõi, số liên kết cần thiết đã là con số khổng lồ, chưa kể mỗi liên kết vật lý (cáp quang xuyên lục địa, trạm vệ tinh...) tốn hàng triệu đến hàng tỷ đô để xây dựng và duy trì. Vì vậy **full-mesh không bao giờ là mô hình thực tế** cho một mạng ở quy mô toàn cầu.

Thay vào đó, mỗi router chỉ liên kết trực tiếp với một số ít **hàng xóm (neighbor)**. Số liên kết trực tiếp của một router gọi là **degree** (bậc) trong lý thuyết đồ thị:

| Loại router | Degree điển hình |
| --- | --- |
| Router nhà bạn | 1 (chỉ nối với ISP) |
| Router ISP địa phương | Vài đến vài chục |
| Router ISP vùng/quốc gia | Hàng chục đến vài trăm |
| Router backbone lớn (Tier 1) | Hàng trăm đến hàng nghìn peering point |

Ngay cả router "nhiều liên kết nhất" cũng chỉ nối trực tiếp với một phần rất nhỏ so với tổng số **AS (Autonomous System)** đang tồn tại (hiện có khoảng 70.000+ AS hoạt động trên Internet).

## Vậy 2 router xa nhau "nói chuyện" bằng cách nào?

Bằng cách đi qua **nhiều hop trung gian** — đây chính là bản chất của **routing**. Router không cần biết đường đi trực tiếp đến mọi đích, nó chỉ cần biết "gói này nên gửi cho hàng xóm nào" dựa vào **routing table**, được xây dựng từ giao thức định tuyến giữa các mạng — **BGP (Border Gateway Protocol)**.

Ví dụ: Router ở Việt Nam muốn gửi đến Router ở Brazil — không có cáp nối thẳng, nhưng đường đi thực tế có thể là:

```
Router (VN ISP) → Tier1-Asia → Tier1-US → Tier1-Brazil → Router (BR ISP)
```

Mỗi router trên đường chỉ liên kết trực tiếp với một số ít hàng xóm — gói tin được "chuyền tay" qua nhiều hop cho đến đích.

## Internet không phải là cây

Một **cây (tree)** có đặc điểm: giữa 2 node bất kỳ chỉ có **đúng 1 đường đi**, không có vòng lặp (cycle). Nếu Internet được tổ chức thuần túy như cây, chỉ cần **một router hỏng** là chia cắt toàn bộ mạng phía sau nó.

Đây là điều thiết kế Internet cố tình tránh — mục tiêu ban đầu của ARPANET (tiền thân Internet) là **chịu lỗi khi một phần mạng bị phá hủy** (bối cảnh Chiến tranh Lạnh). Vì vậy Internet được tổ chức theo mô hình **phân cấp nhưng có mắt lưới (hierarchical mesh)**:

```
                    Tier 1 (backbone quốc tế)
                 (mesh dày đặc, nhiều peering point)
                    /        |        \
              Tier 2 ISP  Tier 2 ISP  Tier 2 ISP
              (quốc gia/vùng — vẫn có nhiều liên kết chéo)
               /    \          /    \
          Tier 3   Tier 3  Tier 3  Tier 3
        (ISP địa phương — nhà mạng bán lẻ)
           /   \                /   \
      Router  Router       Router  Router
      nhà bạn  hàng xóm    công ty  quán net
```

| Tầng | Có phải cây không? |
| --- | --- |
| Backbone quốc tế (Tier 1) | Không — mesh dày đặc, nhiều đường dự phòng |
| Mạng lõi quốc gia (Tier 2) | Gần giống cây nhưng vẫn có liên kết chéo (redundant links) |
| Mạng truy cập cuối (Tier 3 → nhà bạn) | Rất giống cây (last-mile thường chỉ có 1 đường) |

Càng đi xuống gần người dùng cuối, mạng càng giống cây hơn — vì chi phí kéo thêm đường dự phòng đến từng hộ gia đình là quá tốn kém so với lợi ích. Đây là lý do khi router của nhà mạng khu vực bạn hỏng, cả khu đó thường mất mạng cùng lúc.

## Liên kết chéo (redundant link / cross-link)

**Liên kết chéo** là một đường kết nối **thêm vào**, nối giữa hai router/mạng mà về mặt phân cấp "đáng lẽ" không cần nối trực tiếp — mục đích là tạo **đường đi thay thế** khi đường chính bị hỏng.

### Ví dụ không có liên kết chéo (cây thuần túy)

```
                Backbone
                /      \
          ISP-A          ISP-B
          /    \          /    \
       Router1 Router2 Router3 Router4
```

Nếu `Router1` muốn gửi đến `Router4`, đường duy nhất là: `Router1 → ISP-A → Backbone → ISP-B → Router4`. Nếu liên kết `ISP-A ↔ Backbone` đứt, **toàn bộ ISP-A bị cô lập** — không còn đường nào khác.

### Có liên kết chéo

```
                Backbone
                /      \
          ISP-A -------- ISP-B      ← liên kết chéo
          /    \          /    \
       Router1 Router2 Router3 Router4
```

Nối thêm một đường trực tiếp `ISP-A ↔ ISP-B`, cắt chéo qua cấu trúc cây (không đi qua Backbone). Nếu `ISP-A ↔ Backbone` đứt, `Router1` vẫn đến được `Router4` qua đường vòng: `Router1 → ISP-A → ISP-B → Router4`. Mạng không bị chia cắt nữa.

Gọi là "chéo" vì nó không đi theo chiều dọc tự nhiên của cây (cha-con), mà cắt ngang giữa hai nhánh vốn dĩ chỉ liên hệ gián tiếp qua node cha chung. Đây chính là điểm khác biệt giữa **cây** và **mesh**: mesh có thêm các cạnh "thừa" để tạo vòng lặp trong đồ thị, đổi lại có khả năng chịu lỗi (fault-tolerant).

Trong thực tế, đây chính là các đường **peering** trực tiếp giữa hai ISP/AS tại các **IXP (Internet Exchange Point)**, thay vì bắt buộc mọi traffic phải đi qua nhà cung cấp cấp trên (transit provider).

### Liên kết chéo không loại bỏ hoàn toàn nhu cầu đi qua Backbone

Liên kết chéo `ISP-A ↔ ISP-B` chỉ giúp ích khi traffic đi **giữa hai mạng này với nhau**. Nó không giúp gì nếu:

- ISP-A cần đến một mạng thứ ba không nối trực tiếp với nó → vẫn phải đi qua Backbone hoặc một AS trung gian khác.
- Backbone cần đến chính ISP-A/ISP-B → đây là traffic có đi qua Backbone, độc lập với liên kết chéo.

Ngoài ra:

- **Không phải mọi cặp mạng đều có liên kết chéo với nhau** — ISP chỉ peering trực tiếp với một số đối tác lớn/gần mình (do chi phí lắp đặt vật lý, thỏa thuận thương mại). Với phần còn lại của Internet, ISP vẫn phải đi qua **transit provider** (thường là Backbone/Tier 1).
- **Liên kết chéo thường chỉ là dự phòng (backup)**, không phải đường chính — nhiều khi traffic mặc định vẫn đi qua Backbone (đường chính, có SLA, giám sát tốt hơn), liên kết chéo chỉ được kích hoạt qua BGP khi đường chính lỗi (failover).
- **Việc chọn đường đi do BGP quyết định dựa trên routing policy** (AS-path length, local preference, thỏa thuận thương mại peering vs transit), không đơn giản là "đường vật lý ngắn nhất".

| Traffic | Có cần qua Backbone? |
| --- | --- |
| ISP-A ↔ ISP-B (liên kết chéo hoạt động tốt) | Không cần — đi thẳng qua liên kết chéo |
| ISP-A ↔ ISP-B (liên kết chéo lỗi) | Có — fallback qua Backbone |
| ISP-A ↔ mạng thứ ba không peering trực tiếp | Có — gần như luôn cần transit qua Backbone/Tier 1 |
| Traffic có đích/nguồn nằm ngay tại Backbone | Có — hiển nhiên phải qua đó |

## Mô hình phân loại 3-Tier

Các ISP thường được phân thành 3 tier — đây là thuật ngữ **thực hành ngành** (industry term), không phải chuẩn kỹ thuật chính thức như RFC, và ranh giới giữa các tier khá mờ trong thực tế.

| Tier | Đặc điểm | Ví dụ |
| --- | --- | --- |
| **Tier 1** | Không mua transit từ ai — chỉ **peering miễn phí** (settlement-free) với các Tier 1 khác. Đến được toàn bộ Internet chỉ bằng peering, không trả tiền ai. | Lumen (cựu Level 3), NTT, Cogent, Telia, Zayo, Deutsche Telekom, Tata Communications |
| **Tier 2** | **Vừa peering vừa mua transit** — peering với một số mạng ngang hàng để giảm chi phí, nhưng vẫn phải trả Tier 1 để đến phần Internet mình không peering trực tiếp. Đa số ISP quốc gia/khu vực nằm ở đây. | VNPT, Viettel, FPT Telecom, Comcast |
| **Tier 3** | **Chỉ mua transit**, không peering (hoặc rất ít) — thuần túy là khách hàng trả tiền cho Tier 2/Tier 1. Đây là ISP bán lẻ trực tiếp đến người dùng cuối. | ISP địa phương nhỏ, nhà mạng cấp phường/quận |

Định nghĩa cốt lõi chỉ dựa vào một tiêu chí: **ISP đó có phải trả tiền transit để đến được toàn bộ Internet hay không.**
- Tier 1 = không bao giờ trả tiền transit (tự cung tự cấp bằng peering).
- Tier 2 = có trả tiền transit (nhưng cũng có peering).
- Tier 3 = chỉ trả tiền transit, không peering đáng kể.

Một ISP có thể là Tier 2 ở thị trường này nhưng hoạt động gần giống Tier 3 ở thị trường khác — ranh giới không tuyệt đối.

## Tóm tắt toàn cảnh

- Internet hoạt động được **không phải vì mọi router nối trực tiếp nhau**, mà vì có giao thức định tuyến (BGP) cho phép router chỉ cần biết hàng xóm gần, rồi "chuyền tay" gói tin qua nhiều hop.
- Cấu trúc tổng thể là **hierarchical mesh**: dày đặc liên kết chéo ở lõi (Tier 1), thưa dần và gần giống cây khi tới gần người dùng cuối (Tier 3).
- **Liên kết chéo (peering)** giảm phụ thuộc vào Backbone cho từng cặp mạng cụ thể, nhưng không loại bỏ vai trò của Backbone đối với phần còn lại của Internet — phần lớn traffic liên-AS trên toàn cầu vẫn chảy qua Tier 1 ở đâu đó trên đường đi, trực tiếp hoặc gián tiếp.
- Việc packet đi qua bao nhiêu hop, qua những AS nào, là kết quả của **BGP routing policy** — không phải một quy tắc cố định, và có thể thay đổi theo thời gian thực khi có sự cố hoặc thỏa thuận thương mại mới.

## Liên hệ với các bài trước

- [ARP.md](ARP.md) giải thích packet di chuyển trong **1 local network** (Layer 2/3).
- [NAT.md](NAT.md) giải thích packet **thoát khỏi** local network đó ra internet qua router NAT (đổi Source IP:Port).
- Bài này giải thích, **sau khi thoát ra**, packet tiếp tục đi qua chuỗi router nào (Tier 3 → Tier 2 → Tier 1 → ... → đích) để đến được một server bất kỳ trên thế giới — đây là phạm vi hoạt động của **BGP**, giao thức định tuyến giữa các AS, khác với ARP (định tuyến MAC trong 1 subnet).
