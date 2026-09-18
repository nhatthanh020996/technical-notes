Trong kiến trúc Apache Kafka, **sự khác biệt giữa `LISTENERS` và `ADVERTISED_LISTENERS**` là một trong những chủ đề gây nhầm lẫn nhất, đặc biệt là khi triển khai trong môi trường mãng phức tạp như Docker, Kubernetes hoặc Cloud (AWS EC2, GCP).

Hiểu một cách đơn giản nhất: **`LISTENERS` là giao diện mạng mà Kafka "lắng nghe", còn `ADVERTISED_LISTENERS` là "địa chỉ danh thiếp" mà Kafka gửi cho client để client tìm đến đúng broker.**

---

### 1. `LISTENERS`: Kafka mở cửa ở đâu?

`LISTENERS` quy định mạng (socket) mà tiến trình Kafka sẽ khởi tạo, lắng nghe và nhận các kết nối TCP tới.

* **Mục đích:** Khai báo IP/Hostname và Port mà Kafka server **ràng buộc (bind)** trực tiếp trên hệ điều hành của nó.
* **Cú pháp chung:** `LISTENERS: <Tên_Listener>://<IP_hoặc_Hostname>:<Port>`
* **Ý nghĩa thực tế:**
* Nếu bạn đặt `LISTENERS: INTERNAL://0.0.0.0:9092`, Kafka sẽ mở port `9092` trên tất cả các card mạng của máy chủ/container đó để chờ nhận dữ liệu.
* Nếu một kết nối mạng gửi request tới một port **không** nằm trong `LISTENERS`, kết nối đó sẽ bị từ chối ngay lập tức ở tầng mạng (*Connection refused*).



---

### 2. `ADVERTISED_LISTENERS`: Kafka bảo client tìm nó ở đâu?

`ADVERTISED_LISTENERS` là địa chỉ mà Kafka Broker **gửi ngược lại cho Producer/Consumer** (trong bản đồ Metadata) khi client thực hiện bước kết nối ban đầu (*Bootstrap*).

* **Mục đích:** Cung cấp cho client một địa chỉ có thể truy cập được từ phía client để client tự mở kết nối TCP trực tiếp tới broker đó ở các bước tiếp theo.
* **Cú pháp chung:** `ADVERTISED_LISTENERS: <Tên_Listener>://<IP_hoặc_Hostname_Client_Có_Thể_Truy_Cập>:<Port>`
* **Ý nghĩa thực tế:**
* Client kết nối đến `bootstrap.servers` chỉ để hỏi: *"Topic này nằm ở đâu?"*
* Broker trả lời: *"Partition 0 nằm ở Broker A, hãy kết nối tới địa chỉ `X` này."*
* Địa chỉ `X` chính là giá trị được định nghĩa trong `ADVERTISED_LISTENERS`.



---

### 3. Tại sao lại cần tách làm 2 cấu hình riêng biệt?

Nếu bạn chạy Kafka trực tiếp trên một máy chủ vật lý duy nhất không qua Docker/NAT, `LISTENERS` và `ADVERTISED_LISTENERS` có thể dùng chung một địa chỉ IP.

Tuy nhiên, trong các mô hình mạng hiện đại (Docker, Kubernetes, Cloud), **địa chỉ mà Kafka nhìn thấy nội bộ thường KHÔNG PHẢI là địa chỉ mà Client bên ngoài nhìn thấy**.

#### Ví dụ minh họa thực tế với Docker:

Giả sử bạn chạy Kafka trong Docker Container trên máy tính cá nhân (`localhost`):

1. **Bên trong Container (Góc nhìn của Kafka):**
* IP của container là `172.18.0.2`.
* Kafka cần nghe trên port `9092` của chính nó:
`LISTENERS: EXTERNAL://0.0.0.0:9092`


2. **Bên ngoài Host (Góc nhìn của Producer trên laptop của bạn):**
* Laptop của bạn không thể kết nối trực tiếp tới IP `172.18.0.2` của Docker.
* Bạn dùng Docker port-mapping để đẩy port `9095` trên laptop vào port `9092` của container.
* Để Producer trên laptop kết nối được, Kafka bắt buộc phải gửi "tấm danh thiếp" ghi địa chỉ `localhost:9095`:
`ADVERTISED_LISTENERS: EXTERNAL://localhost:9095`



> **Chuyện gì xảy ra nếu cấu hình sai `ADVERTISED_LISTENERS`?**
> Producer kết nối bước đầu (*Bootstrap*) thành công tới `localhost:9095`. Kafka trả về Metadata bảo: *"Hãy gửi tin nhắn tới IP `172.18.0.2:9092`"*. Producer trên laptop thử kết nối tới IP `172.18.0.2` và bị **Timeout/UnknownHostException**, mặc dù bước Bootstrap ban đầu vẫn chạy bình thường.

---

### 4. Mô hình Nhiều Listener (Multiple Listeners)

Trong thực tế production, một Kafka Cluster thường phục vụ đồng thời cả **nội bộ cluster** (Internal: giữa các Broker với nhau, hoặc với Microservices chạy chung mạng) và **bên ngoài** (External: các ứng dụng chạy ở môi trường/mạng khác).

Để giải quyết việc này, Kafka cho phép khai báo nhiều Listener song song:

```properties
# Khai báo các chuẩn kết nối
listener.security.protocol.map=INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT

# Kafka mở 2 cổng trên Container/Máy chủ
listeners=INTERNAL://0.0.0.0:9092,EXTERNAL://0.0.0.0:9095

# Kafka trả về 2 danh thiếp khác nhau tùy theo cửa mà Client đi vào
advertised.listeners=INTERNAL://broker1-container:9092,EXTERNAL://my-company-kafka.com:9095
inter.broker.listener.name=INTERNAL

```

* **Kết nối nội bộ (Microservices trong cùng mạng/Docker network):** Đi vào cổng `9092`, nhận lại địa chỉ `broker1-container:9092` để giao tiếp nội bộ tốc độ cao.
* **Kết nối bên ngoài (Client bên ngoài internet/VPN):** Đi vào cổng `9095`, nhận lại địa chỉ `my-company-kafka.com:9095` đã qua NAT/Load Balancer.

---

### Tóm tắt nhanh

| Cấu hình | Câu hỏi tương ứng | Đối tượng sử dụng |
| --- | --- | --- |
| **`LISTENERS`** | Kafka mở cổng ở đâu trên máy này? | Dành cho Hệ điều hành / Mạng nội bộ của Broker. |
| **`ADVERTISED_LISTENERS`** | Client phải tìm đến địa chỉ nào để gặp Broker? | Dành cho Client (Producer / Consumer / Replica Broker khác). |