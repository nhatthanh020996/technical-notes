# Kiến trúc Kafka — Ghi chú tổng hợp

Tài liệu này tổng hợp lại các khái niệm về kiến trúc Kafka đã trao đổi, dựa trên file `docker-compose-cluster.yml` trong repo này.

## 1. Vấn đề Kafka giải quyết

Nhiều app sinh ra dữ liệu (producer) và nhiều app khác cần đọc dữ liệu đó (consumer). Nếu nối trực tiếp producer với consumer thì rất dễ vỡ (consumer down là mất data). Kafka đứng giữa như một message broker bền (durable): producer viết vào, Kafka lưu lại, consumer đọc ra độc lập, theo tốc độ riêng của từng consumer.

## 2. Các khái niệm nền tảng

- **Broker**: một tiến trình Kafka server. Nhận, lưu, và phục vụ message. Một "cluster" là nhiều broker hoạt động cùng nhau.
- **Topic**: tên một luồng dữ liệu, ví dụ `orders`. Giống tên bảng hoặc tên thư mục.
- **Partition**: mỗi topic được chia thành nhiều partition — một log chỉ ghi thêm (append-only), có thứ tự. Chia partition để: (1) xử lý song song, (2) trải dữ liệu ra nhiều broker.
- **Offset**: số thứ tự tuần tự của message trong một partition.
- **Producer**: app viết message vào topic.
- **Consumer**: app đọc message từ topic, tự theo dõi offset đã đọc tới đâu.
- **Replication**: mỗi partition có thể có nhiều bản sao (replica) trên nhiều broker khác nhau. Một bản là leader (xử lý đọc/viết), các bản còn lại là follower (chỉ copy từ leader).

## 3. Role: broker vs controller

Mỗi node Kafka đóng một hoặc cả hai vai trò:

- **Broker role**: "data plane" — lưu partition, phục vụ producer/consumer.
- **Controller role**: "management plane" — không đụng vào message, chỉ theo dõi metadata của cluster: topic nào tồn tại, broker nào là leader của partition nào, broker nào còn sống.

Kafka cũ dùng ZooKeeper riêng biệt để làm việc "cầm sổ" này. Kafka hiện đại (KRaft mode) để chính một số broker kiêm luôn vai trò controller — đó là ý nghĩa của:

```
KAFKA_CFG_PROCESS_ROLES=controller,broker
```

## 4. Quorum

Nếu chỉ có một controller và nó chết, cluster mất luôn "bộ nhớ" về trạng thái. Vì vậy production cần nhiều controller node, và chúng phải đồng thuận với nhau về trạng thái cluster — đó là **quorum**. Chúng dùng thuật toán Raft để bầu ra một controller "active", còn lại là backup đồng bộ sẵn sàng thay thế.

```
KAFKA_CFG_CONTROLLER_QUORUM_BOOTSTRAP_SERVERS=kafka-0:9093,kafka-1:9093,kafka-2:9093
KAFKA_INITIAL_CONTROLLERS=0@kafka-0:9093:...,1@kafka-1:9093:...,2@kafka-2:9093:...
```

Đọc là: "voter id 0 ở kafka-0:9093, voter id 1 ở kafka-1:9093..." — danh sách ai được quyền vote.

## 5. Listeners

Một broker có thể mở nhiều cổng, cho nhiều đối tượng khác nhau, vì không phải ai kết nối vào cũng nên được đối xử giống nhau. Listener = "mở cổng này, và đây là quy tắc bảo mật cho ai dùng nó."

Ví dụ 4 cổng trong cluster:

| Listener | Port | Đối tượng dùng |
|---|---|---|
| INTERNAL | 9092 | Service khác trong cùng Docker network |
| CONTROLLER | 9093 | Chỉ controller khác, để vote trong quorum |
| BROKER (inter-broker) | 9094 | Broker khác, để replicate data |
| EXTERNAL | 9095+ | Client ngoài Docker (máy host, internet) |

```
KAFKA_CFG_LISTENERS=INTERNAL://:9092,EXTERNAL://:9095,CONTROLLER://:9093
```

`LISTENERS` chỉ là sự thật cơ học nội bộ: "tôi bind các port này." Nó không có hostname vì bind không cần hostname.

## 6. Advertised Listeners

Đây là phần dễ gây nhầm lẫn nhất.

Khi client (producer/consumer) kết nối vào Kafka lần đầu, nó không được viết message ngay. Kafka trả lời trước: "đây là metadata cluster — topic này, partition đó nằm ở broker nào, địa chỉ nào." Client sau đó **ngắt kết nối và kết nối lại trực tiếp** tới địa chỉ được chỉ định.

Địa chỉ đó chính là **advertised listener** — "địa chỉ để công bố lại cho client."

Advertised listener có thể khác với listener thật, vì:

- Trong Docker, hostname của broker là `kafka` — chỉ container khác resolve được.
- Từ máy host (ngoài Docker), `kafka` không có nghĩa gì — cần `localhost` hoặc IP thật.

```
KAFKA_CFG_ADVERTISED_LISTENERS=INTERNAL://kafka-0:9092,EXTERNAL://103.75.186.139:9095
```

**Analogy**: một người có số máy nội bộ (chỉ gọi được từ trong công ty) và số điện thoại di động (gọi được từ ngoài). Cùng một người, chỉ khác số tùy vào ai gọi.

`LISTENERS` = đường dây điện thoại thực sự nối vào máy. `ADVERTISED_LISTENERS` = số điện thoại được đưa ra, tùy ai đang hỏi.

### Điều gì xảy ra nếu KHÔNG có advertised_listeners?

Kafka sẽ tự dùng hostname máy nội bộ (thường là container ID, ví dụ `a3f9c21b8e4d`). Bước 1 (kết nối bootstrap) vẫn thành công, nhưng bước 3 (kết nối trực tiếp tới broker leader) sẽ fail vì client bên ngoài không resolve được hostname đó — đây chính là lỗi phổ biến nhất khi chạy Kafka trong Docker: "connect được nhưng sau đó timeout."

## 7. Bootstrap server

`bootstrap.servers` là setting **bên client** (producer/consumer), không phải setting của broker. Đây là địa chỉ khởi đầu để client "vào cửa" cluster.

```
bootstrap.servers=localhost:9095
```

Client không biết gì về cluster lúc đầu — nó cần "bootstrap" bằng cách hỏi **một** broker bất kỳ: "cho tôi biết toàn cảnh cluster." Chỉ cần một broker phản hồi là đủ, vì mọi broker đều có bản đồng bộ đầy đủ metadata (được controller đẩy xuống).

**Analogy**: gọi lên tổng đài công ty để hỏi "phòng kế toán số máy nào" — tổng đài (`bootstrap.servers`) không phải người xử lý kế toán, chỉ cho biết số cần gọi tiếp.

### Quan hệ giữa bootstrap.servers và controller

- Controller là **nguồn gốc** của thông tin "partition nào do broker nào làm leader" — dữ liệu này có nguồn gốc từ controller.
- Nhưng client **không bao giờ nói chuyện trực tiếp với controller** — client chỉ nói chuyện với broker thường (qua `bootstrap.servers`), broker đó relay lại metadata mà controller đã tính toán.
- `bootstrap.servers` không bao giờ chỉ vào port CONTROLLER (9093), không dùng SASL credentials của controller, và giao thức nói chuyện ở đó hoàn toàn khác giao thức Raft/controller.

## 8. Toàn bộ hành trình chi tiết: từ producer đến khi message vào broker

### Giai đoạn 0 — Trước khi gọi `send()`

Khởi tạo `KafkaProducer` với `bootstrap.servers=103.75.186.139:9095` chưa mở kết nối gì cả — chỉ lưu config trong bộ nhớ. Kết nối thật chỉ xảy ra khi gọi `producer.send(record)` lần đầu (lazy connection).

### Giai đoạn 1 — Mở TCP + SASL handshake tới bootstrap server

Producer mở TCP socket tới `103.75.186.139:9095` — một broker bất kỳ trong danh sách bootstrap, không quan trọng broker nào, vì mọi broker đều biết toàn bộ metadata cluster.

Nếu listener đó là `SASL_PLAINTEXT`, ngay sau TCP handshake có thêm bước **SASL handshake**: client gửi username/password (từ `sasl.jaas.config`), broker xác thực. Sai credentials → connection đóng ngay, lỗi `SaslAuthenticationException`.

### Giai đoạn 2 — Gửi `MetadataRequest`

Request Kafka protocol đầu tiên, hoàn toàn tự động. Producer hỏi: "cho tôi biết cluster có gì, và cụ thể topic `orders` thì sao." Broker trả `MetadataResponse` chứa:

- Danh sách toàn bộ broker: node id, host, port (giá trị lấy từ `ADVERTISED_LISTENERS` của **từng** broker, đã được controller đẩy xuống từ trước — broker bootstrap không tự bịa).
- Với topic `orders`: từng partition, ai là leader, ai là các replica (ISR — in-sync replica set).

```
brokers: [
  {nodeId: 0, host: "103.75.186.139", port: 9095},
  {nodeId: 1, host: "103.75.186.139", port: 9096},
  {nodeId: 2, host: "103.75.186.139", port: 9097},
]
topics: [
  { name: "orders",
    partitions: [
      {partition: 0, leader: 1, replicas: [1,2,0], isr: [1,2,0]},
      {partition: 1, leader: 2, replicas: [2,0,1], isr: [2,0,1]},
      {partition: 2, leader: 0, replicas: [0,1,2], isr: [0,1,2]},
    ]
  }
]
```

Producer **cache** response này trong bộ nhớ (`metadata.max.age.ms`, mặc định 5 phút, quyết định khi nào hỏi lại — hoặc hỏi lại ngay khi gặp lỗi liên quan tới đổi leader).

### Giai đoạn 3 — Chọn partition (client-side, không qua network)

Partitioner quyết định message thuộc partition nào:

- **Có key**: `hash(key)` (murmur2) để chọn partition cố định — cùng key luôn ra cùng partition, đảm bảo thứ tự cho các message cùng key.
- **Không có key**: chiến lược "sticky" — dồn vào 1 partition trong khoảng ngắn để gom batch hiệu quả, rồi xoay sang partition khác.
- **Chỉ định partition rõ ràng** trong `ProducerRecord`: dùng luôn, bỏ qua hash.

Giả sử rơi vào **partition 1** → tra bảng metadata → leader là **broker node 1**, địa chỉ `103.75.186.139:9096`.

### Giai đoạn 4 — Vào buffer, chưa gửi ngay

Producer **không gửi từng message riêng lẻ ngay**. Message vào `RecordAccumulator`, tổ chức theo từng partition — mỗi partition có hàng đợi batch riêng.

Hai tham số quyết định khi nào batch gửi thật:
- `batch.size` (mặc định 16KB) — batch đầy thì gửi.
- `linger.ms` (mặc định 0) — chờ thêm trước khi gửi dù batch chưa đầy, để gom thêm message (đổi throughput lấy latency).

Một **Sender thread** riêng (chạy background trong producer) liên tục quét batch sẵn sàng và gửi đi.

### Giai đoạn 5 — Mở kết nối riêng tới broker leader (nếu chưa có)

Vì leader của partition 1 là node 1 (`:9096`) — khác broker bootstrap (node 0, `:9095`) — Sender thread mở **TCP connection mới** tới `103.75.186.139:9096`.

Producer duy trì **connection pool**: một connection cho mỗi broker nó từng cần nói chuyện, tái sử dụng cho request sau. SASL handshake xảy ra lại ở đây vì đây là connection độc lập với connection bootstrap.

### Giai đoạn 6 — Gửi `ProduceRequest`

Sender thread gửi batch (nén nếu có `compression.type`) dưới dạng `ProduceRequest`: tên topic, số partition, các record (key/value/timestamp/headers), và mức `acks` yêu cầu.

### Giai đoạn 7 — Broker leader ghi vào log — đây là lúc "message nằm trong broker"

Ở phía broker node 1:

1. Request đến, xử lý bởi **request handler thread**.
2. Broker kiểm tra mình đúng là leader của partition 1 không (nếu không → lỗi `NOT_LEADER_OR_FOLLOWER`, producer tự refresh metadata và gửi lại đúng broker).
3. Ghi batch vào **log segment file** trên đĩa (ví dụ `00000000000000000000.log` trong `/bitnami/kafka/data/orders-1/`) — append-only, ghi tuần tự, rất nhanh (không random-write).
4. Mỗi record được gán **offset** kế tiếp (tăng dần tuyệt đối, không tái sử dụng).
5. Cập nhật `.index` file (offset index) để đọc nhanh hơn sau này.
6. Dữ liệu có thể chưa `fsync` xuống đĩa vật lý ngay — Kafka dựa vào OS page cache để throughput cao; flush thật theo policy (`log.flush.interval.messages/ms`) hoặc khi OS tự flush.

→ **Đây là thời điểm chính xác "message nằm trong broker"**: đã tồn tại trong log partition, có offset chính thức. Trước đó nó chỉ tồn tại trong RAM producer (buffer) hoặc đang bay trên network.

### Giai đoạn 8 — Replicate sang follower (nếu replication factor > 1)

- Follower (node 2, node 0 cho partition 1) liên tục gửi `FetchRequest` tới leader (node 1) qua listener **INTERNAL** (port 9092) — đây là inter-broker traffic (`KAFKA_CFG_INTER_BROKER_LISTENER_NAME=INTERNAL`).
- Leader trả về record mới nhất, follower ghi vào log của chính nó.
- Follower ghi xong → báo lại leader "đã bắt kịp tới offset X" → leader cập nhật tập **ISR (in-sync replicas)**.

### Giai đoạn 9 — Gửi ack lại cho producer

Tùy `acks`:

- **`acks=0`**: broker không trả lời gì, producer coi như xong ngay khi push ra socket (rủi ro mất message nếu broker crash trước khi ghi).
- **`acks=1`**: broker leader trả `ProduceResponse` ngay sau khi ghi xong (giai đoạn 7), **không chờ** follower — leader chết ngay sau đó trước khi follower kịp replicate có thể mất message.
- **`acks=all`** (an toàn nhất): leader **chờ** đủ số replica trong ISR ghi xong (đủ `min.insync.replicas`) rồi mới trả response. Không đủ ISR → producer nhận lỗi (`NotEnoughReplicasException`), có thể retry.

Producer nhận response → callback (`onCompletion`) chạy, chứa offset thật, partition thật.

### Sơ đồ tổng hợp

```
Producer app
   │
   │ [1] TCP connect + SASL handshake
   ▼
Broker bootstrap (node 0, :9095)
   │
   │ [2] MetadataRequest / MetadataResponse
   ▼
Producer cache metadata trong bộ nhớ
   │
   │ [3] Partitioner chọn partition 1 → leader = node 1
   │ [4] Message vào RecordAccumulator, chờ batch/linger
   ▼
Sender thread
   │
   │ [5] TCP connect mới tới node 1 (:9096) nếu chưa có
   │ [6] Gửi ProduceRequest (batch, có thể nén)
   ▼
Broker leader (node 1)
   │
   │ [7] Append vào log file + gán offset  ← MESSAGE ĐÃ "NẰM TRONG BROKER"
   │ [8] Follower fetch để replicate (qua INTERNAL listener)
   │ [9] Trả ProduceResponse theo acks
   ▼
Producer nhận ack → callback chạy với offset thật
```

### Điểm quan trọng cần nhớ

- **Metadata chỉ hỏi 1 lần** (rồi cache), không phải hỏi lại cho mỗi message.
- **Kết nối tới broker leader là kết nối riêng**, khác kết nối bootstrap — vì broker bootstrap chưa chắc là leader của partition cần dùng.
- **"Nằm trong broker"** cụ thể là thời điểm broker leader **append vào log file trên đĩa và gán offset** (giai đoạn 7).
- **Ack không đồng nghĩa với "đã ghi"** — thứ tự thực tế: ghi trước (giai đoạn 7), rồi mới quyết định *khi nào* báo cho producer là xong (giai đoạn 9), tùy `acks`.

## 9. security.protocol map

```
KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=INTERNAL:PLAINTEXT,EXTERNAL:SASL_PLAINTEXT,CONTROLLER:PLAINTEXT
```

Đây là bảng dịch: "listener tên X thì áp dụng protocol Y." Vì Kafka chỉ hiểu các protocol có sẵn (`PLAINTEXT`, `SASL_PLAINTEXT`, `SSL`, `SASL_SSL`), không hiểu tên listener tự đặt (`INTERNAL`, `EXTERNAL`...).

- `PLAINTEXT`: không auth, không encrypt.
- `SASL_PLAINTEXT`: cần login username/password, nhưng data vẫn không encrypt trên đường truyền.

## 10. Thay đổi thực tế trong `docker-compose-cluster.yml`

Mục tiêu: cluster 3 broker phải phục vụ được cả client trong Docker network và client từ internet (public IP `103.75.186.139`).

Các thay đổi chính, áp dụng cho cả 3 broker (`kafka-0`, `kafka-1`, `kafka-2`):

1. **Thêm listener EXTERNAL** bên cạnh INTERNAL. INTERNAL (port 9092) dùng cho client trong Docker network. EXTERNAL dùng cho internet.

2. **Mỗi broker EXTERNAL dùng port host riêng**: 9095 / 9096 / 9097. Lý do: cả 3 broker dùng chung một public IP, nên không thể advertise cùng port — cần port riêng để phân biệt broker nào.

3. **ADVERTISED_LISTENERS khác nhau theo từng đối tượng, từng broker**:
   ```
   INTERNAL://kafka-0:9092            (cho client trong Docker network)
   EXTERNAL://103.75.186.139:9095     (cho client internet)
   ```
   (tương tự cho kafka-1 dùng `:9096`, kafka-2 dùng `:9097`)

4. **EXTERNAL yêu cầu SASL/PLAIN login**; INTERNAL vẫn mở tự do (PLAINTEXT) — *(xem mục 11: sau đó nâng cấp thêm SSL)*.

5. **KAFKA_CFG_INTER_BROKER_LISTENER_NAME đổi từ PLAINTEXT → INTERNAL** — traffic replicate giữa các broker luôn đi qua network nội bộ, không bao giờ qua listener public.

6. **Port mapping đổi từ `"9092"` (random host port) sang `"9095:9095"` cố định** — để client internet biết chắc port nào để kết nối.

### Việc cần làm trước khi chạy

- Sửa file `.env`, đặt `KAFKA_CLIENT_USERS` / `KAFKA_CLIENT_PASSWORDS` thật, không để password mặc định.
- Mở firewall/security group cho port 9095, 9096, 9097 trên máy chủ.
- Lưu ý: ở KRaft mode, chỉ user:password **đầu tiên** trong `KAFKA_CLIENT_USERS`/`KAFKA_CLIENT_PASSWORDS` có tác dụng (SCRAM multi-user chưa được hỗ trợ) — nhưng vì cả 3 broker dùng chung 1 credential nên không sao.
- `bootstrap.servers` cho client:
  - Trong Docker: `kafka-0:9092,kafka-1:9092,kafka-2:9092`
  - Từ internet: `103.75.186.139:9095,103.75.186.139:9096,103.75.186.139:9097` (kèm SASL credentials)

## 11. Nâng cấp: INTERNAL dùng SASL_PLAINTEXT, EXTERNAL dùng SASL_SSL

Yêu cầu tiếp theo: trong mạng nội bộ Docker vẫn cần login (SASL) nhưng không cần mã hoá (đã tin cậy mạng); còn EXTERNAL (public internet) cần login **và** mã hoá — vì dữ liệu đi qua internet không an toàn, ai đó có thể nghe trộm (sniff) cả credentials và message nếu chỉ dùng SASL_PLAINTEXT.

### Thay đổi trong `KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP`

```
INTERNAL:SASL_PLAINTEXT,EXTERNAL:SASL_SSL,CONTROLLER:PLAINTEXT
```

- `INTERNAL`: từ `PLAINTEXT` → `SASL_PLAINTEXT` (thêm login, không mã hoá).
- `EXTERNAL`: từ `SASL_PLAINTEXT` → `SASL_SSL` (login + mã hoá TLS).
- `CONTROLLER`: giữ `PLAINTEXT` — traffic quorum nội bộ, không cần đổi.

### Vì sao cần certificate, và Bitnami image không tự tạo

`SASL_SSL` cần TLS certificate (keystore chứa private key + cert của broker, truststore chứa cert của CA để bên kia verify). Bitnami Kafka image **không tự sinh certificate** — phải tự tạo và mount vào container qua volume, tại đường dẫn cố định:

```
/opt/bitnami/kafka/config/certs/kafka.keystore.jks
/opt/bitnami/kafka/config/certs/kafka.truststore.jks
```

Vì tên file cố định (không phân biệt theo tên broker) và mỗi container là instance riêng, **mỗi broker cần một cặp keystore/truststore riêng**, mount đè lên đúng đường dẫn đó — nên trong compose có 3 file `kafka-0.keystore.jks`, `kafka-1.keystore.jks`, `kafka-2.keystore.jks`, v.v., mỗi cái mount vào đúng 1 container.

### Script tạo self-signed certificate: `certs/generate-certs.sh`

Vì đây là self-signed (không dùng CA thật như Let's Encrypt — muốn dùng CA thật thì cần domain trỏ vào `103.75.186.139`, IP trần không được Let's Encrypt cấp cert), script tự tạo một CA riêng rồi ký cert cho từng broker:

1. Tạo CA riêng (`ca-cert`, `ca-key`).
2. Với mỗi broker: tạo keypair + CSR (certificate signing request), có SAN (Subject Alternative Name) gồm cả hostname Docker nội bộ (`kafka-0`) và IP public (`103.75.186.139`) — để cert hợp lệ dù client kết nối bằng tên nào.
3. Dùng CA ký CSR đó → ra cert đã ký.
4. Import CA cert + cert đã ký vào keystore của broker.
5. Import CA cert vào truststore — để bất kỳ ai tin CA này cũng tin được cert của broker.

Chạy trước khi start cluster:
```
export KAFKA_CERTIFICATE_PASSWORD=change-me-cert-password
./certs/generate-certs.sh
```

### Thay đổi trong compose

Mỗi broker thêm:
```
- KAFKA_TLS_TYPE=JKS
- KAFKA_CERTIFICATE_PASSWORD=${KAFKA_CERTIFICATE_PASSWORD}
- KAFKA_TLS_CLIENT_AUTH=none
```
và mount:
```
- ./certs/kafka-0.keystore.jks:/opt/bitnami/kafka/config/certs/kafka.keystore.jks:ro
- ./certs/kafka-0.truststore.jks:/opt/bitnami/kafka/config/certs/kafka.truststore.jks:ro
```
(đổi `kafka-0` thành `kafka-1`/`kafka-2` tương ứng cho từng broker).

- `KAFKA_TLS_CLIENT_AUTH=none`: broker không yêu cầu client phải có cert riêng (mTLS) — chỉ client tự verify cert của broker là đủ. Nếu muốn mTLS (broker cũng xác thực cert của client) thì đổi thành `required`.
- **Gotcha quan trọng**: SSL settings (keystore/truststore) là **chia sẻ chung cho mọi listener dùng SSL/SASL_SSL** trong cùng 1 broker — không hỗ trợ cert riêng cho từng listener. Ở đây không vấn đề gì vì chỉ có 1 listener (EXTERNAL) dùng SSL.

### Ảnh hưởng tới client

- **Client trong Docker network** (nói với `INTERNAL`, port 9092): giờ cần thêm SASL credentials (trước đây không cần, vì listener này từng là PLAINTEXT). Không cần truststore vì không có SSL ở đây.
- **Client từ internet** (nói với `EXTERNAL`, port 9095/9096/9097): cần cả SASL credentials **và** truststore chứa CA cert (copy 1 trong 3 file `kafka-N.truststore.jks` — chúng đều tin cùng 1 CA):
  ```
  security.protocol=SASL_SSL
  sasl.mechanism=PLAIN
  ssl.truststore.location=/path/to/kafka-0.truststore.jks
  ssl.truststore.password=change-me-cert-password
  ```
- Vì cert là self-signed (không phải CA công khai), nếu client không có truststore đúng, sẽ gặp lỗi `SSLHandshakeException: unable to find valid certification path`.
