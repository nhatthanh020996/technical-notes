# Quy trình setup SASL_SSL cho Kafka cluster

Tài liệu này mô tả từng bước thực tế đã thực hiện để nâng cấp cluster 3 broker (`docker-compose-cluster.yml`) từ chỗ chỉ dùng `SASL_PLAINTEXT` cho client bên ngoài, sang: `INTERNAL` dùng `SASL_PLAINTEXT`, `EXTERNAL` dùng `SASL_SSL`.

## 1. Mục tiêu và lý do

| Listener | Đối tượng | Yêu cầu |
|---|---|---|
| `INTERNAL` (9092) | Client trong Docker network | Login (SASL), không cần mã hoá — mạng nội bộ đã tin cậy |
| `EXTERNAL` (9095/9096/9097) | Client từ internet | Login (SASL) **và** mã hoá (SSL) — dữ liệu đi qua internet, ai đó có thể nghe trộm cả credentials và message nếu không mã hoá |
| `CONTROLLER` (9093) | Quorum nội bộ giữa broker | Giữ `PLAINTEXT`, không đổi |

`SASL_PLAINTEXT` chỉ xác thực (biết ai đang kết nối) nhưng không mã hoá nội dung truyền đi — username/password và message vẫn có thể bị đọc được nếu ai đó chặn traffic. `SASL_SSL` = `SASL_PLAINTEXT` + TLS, giải quyết đúng lỗ hổng đó cho traffic đi qua internet.

## 2. Certificate: vì sao cần, và Bitnami image không tự tạo

`SASL_SSL` cần TLS certificate ở hai phần:
- **Keystore**: chứa private key + certificate của broker — dùng để broker "chứng minh mình là ai" với client.
- **Truststore**: chứa certificate của CA (Certificate Authority) — dùng để bên kia (client, hoặc broker khác) verify certificate nhận được có đáng tin không.

Bitnami Kafka image **không tự sinh certificate** (đã bỏ tính năng dummy cert từ bản 1.1.0-r41) — phải tự tạo và mount vào container, tại đường dẫn cố định:

```
/opt/bitnami/kafka/config/certs/kafka.keystore.jks
/opt/bitnami/kafka/config/certs/kafka.truststore.jks
```

Vì đường dẫn này cố định (không phân biệt theo tên broker) và mỗi container là instance riêng biệt, **mỗi broker cần một cặp keystore/truststore riêng của nó**, mount đè lên đúng đường dẫn đó trong từng container.

### Vì sao chọn self-signed CA thay vì CA thật (Let's Encrypt)

Let's Encrypt yêu cầu một **domain name** trỏ tới server để cấp certificate — không cấp certificate cho IP trần. Vì cluster chỉ có địa chỉ IP public `103.75.186.139`, không có domain, nên dùng self-signed CA: tự tạo một CA riêng, rồi tự ký certificate cho từng broker bằng CA đó.

Đánh đổi: client kết nối tới cluster phải được cấp file truststore chứa CA cert này để tin cậy — không tự động được trust như CA công khai.

## 3. Script tạo certificate: `certs/generate-certs.sh`

Script thực hiện theo đúng luồng PKI (Public Key Infrastructure) tiêu chuẩn:

```
Bước 1: Tạo CA riêng
   openssl req -new -x509 -keyout ca-key -out ca-cert ...
   → sinh ra cặp khoá + certificate tự ký, đóng vai trò "cơ quan cấp chứng chỉ"
     cho riêng cluster này.

Với mỗi broker (kafka-0, kafka-1, kafka-2):

  Bước 2: Tạo keypair riêng cho broker, kèm SAN (Subject Alternative Name)
     keytool -genkeypair ... -ext "SAN=dns:kafka-0,ip:103.75.186.139"
     → SAN liệt kê MỌI địa chỉ mà client có thể dùng để gọi tới broker này
       (hostname Docker nội bộ VÀ IP public) — nếu thiếu một địa chỉ nào
       trong SAN, client kết nối bằng địa chỉ đó sẽ bị lỗi
       "hostname verification failed" dù cert hợp lệ về mặt CA.

  Bước 3: Tạo CSR (Certificate Signing Request) và ký bằng CA ở bước 1
     keytool -certreq ...  →  openssl x509 -req -CA ca-cert -CAkey ca-key ...
     → đây là bước biến "self-signed cert của broker" thành "cert được CA
       riêng của cluster xác nhận" — để broker khác / client chỉ cần tin
       một CA duy nhất, không cần tin riêng từng broker.

  Bước 4: Import CA cert + cert đã ký vào keystore của broker
     keytool -importcert -keystore kafka-0.keystore.jks ...
     → keystore giờ chứa: private key của broker + cert đã ký + cert CA
       (chain đầy đủ để bên nhận verify được).

  Bước 5: Import CA cert vào truststore
     keytool -importcert -keystore kafka-0.truststore.jks -alias CARoot ...
     → truststore chỉ cần chứa CA cert (không cần private key) — vì mọi
       cert của 3 broker đều được ký bởi CA này, 1 truststore verify được cả 3.
```

Chạy trước khi start cluster (cần `openssl` và `keytool`/JDK có sẵn trên máy):

```bash
cd Kafka
set -a && source .env && set +a   # load KAFKA_CERTIFICATE_PASSWORD từ .env
./certs/generate-certs.sh
```

Kết quả: 6 file trong `certs/` — `kafka-0.keystore.jks`, `kafka-0.truststore.jks`, tương tự cho `kafka-1`, `kafka-2`. Toàn bộ dùng chung 1 password (`KAFKA_CERTIFICATE_PASSWORD`).

## 4. Thay đổi trong `docker-compose-cluster.yml`

### 4.1. Đổi bảng security protocol

```
KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=INTERNAL:SASL_PLAINTEXT,EXTERNAL:SASL_SSL,CONTROLLER:PLAINTEXT
```

### 4.2. Thêm biến TLS (mỗi broker)

```
- KAFKA_TLS_TYPE=JKS
- KAFKA_CERTIFICATE_PASSWORD=${KAFKA_CERTIFICATE_PASSWORD}
- KAFKA_TLS_CLIENT_AUTH=none
```

- `KAFKA_TLS_TYPE=JKS`: định dạng certificate (JKS — Java KeyStore — thay vì PEM).
- `KAFKA_CERTIFICATE_PASSWORD`: password chung để mở keystore/truststore, lấy từ `.env`.
- `KAFKA_TLS_CLIENT_AUTH=none`: broker **không** yêu cầu client cũng phải có certificate riêng (không dùng mTLS hai chiều) — chỉ client verify cert của broker là đủ. Nếu cần mTLS (broker xác thực cả client), đổi thành `required`.

### 4.3. Mount keystore/truststore riêng cho từng container

```yaml
volumes:
  - kafka_0_data:/bitnami/kafka
  - ./certs/kafka-0.keystore.jks:/opt/bitnami/kafka/config/certs/kafka.keystore.jks:ro
  - ./certs/kafka-0.truststore.jks:/opt/bitnami/kafka/config/certs/kafka.truststore.jks:ro
```

(tương ứng đổi `kafka-0` → `kafka-1`/`kafka-2` cho từng broker khác — file nguồn khác nhau nhưng đường dẫn đích trong container luôn giống nhau, vì đó là đường dẫn cố định của Bitnami image.)

### 4.4. Gotcha: SSL setting là chia sẻ chung, không phải theo từng listener

Theo README của Bitnami: *"SSL settings are shared by all listeners configured using SSL or SASL_SSL protocols. Setting different certificates per listener is not yet supported."* — nghĩa là nếu một broker có **nhiều hơn 1** listener dùng SSL/SASL_SSL, chúng buộc phải dùng chung certificate. Ở đây không vấn đề gì vì mỗi broker chỉ có 1 listener SSL (`EXTERNAL`).

## 5. Ảnh hưởng tới client

### 5.1. Client trong Docker network (nói với `INTERNAL`)

Trước đây `INTERNAL` là `PLAINTEXT` — không cần credentials gì. Giờ đổi thành `SASL_PLAINTEXT`, nên client (dù ở cùng Docker network) **bắt đầu cần khai báo SASL username/password**:

```python
conf = {
    "bootstrap.servers": "kafka-0:9092,kafka-1:9092,kafka-2:9092",
    "security.protocol": "SASL_PLAINTEXT",
    "sasl.mechanism": "PLAIN",
    "sasl.username": "...",
    "sasl.password": "...",
}
```

Không cần truststore vì không có TLS ở listener này.

### 5.2. Client từ internet (nói với `EXTERNAL`)

Cần đủ 2 lớp: SASL (đăng nhập) + SSL (mã hoá, verify cert broker):

```python
conf = {
    "bootstrap.servers": "103.75.186.139:9095,103.75.186.139:9096,103.75.186.139:9097",
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": "...",
    "sasl.password": "...",
    "ssl.ca.location": "/path/to/ca-cert.pem",
}
```

`librdkafka` (thư viện nền của `confluent_kafka` Python) cần certificate dạng **PEM**, không đọc trực tiếp file `.jks` (định dạng JKS chỉ Java hiểu). Vì vậy cần export CA cert từ truststore ra PEM một lần:

```bash
keytool -list -rfc \
  -keystore certs/kafka-0.truststore.jks \
  -storepass "$KAFKA_CERTIFICATE_PASSWORD" \
  -alias CARoot \
  > certs/ca-cert.pem
```

File `ca-cert.pem` này là thứ thực sự được phân phối cho client bên ngoài (không cần gửi file `.jks` nào, không cần gửi private key của broker — chỉ cần CA cert công khai).

## 6. Kiểm tra lỗi thường gặp

| Lỗi | Nguyên nhân | Cách sửa |
|---|---|---|
| `SSLHandshakeException: unable to find valid certification path` | Client không có/ sai CA cert trong truststore | Kiểm tra `ssl.ca.location` trỏ đúng `ca-cert.pem` xuất từ đúng CA đã ký cho broker |
| Hostname verification failed | SAN trong cert broker thiếu địa chỉ mà client dùng để kết nối | Kiểm tra lại `SAN=dns:...,ip:...` trong `generate-certs.sh` có đủ mọi địa chỉ (hostname Docker + IP public) |
| `SaslAuthenticationException` | Sai username/password, hoặc `KAFKA_CLIENT_USERS`/`PASSWORDS` không khớp giữa broker và client | Đối chiếu lại giá trị trong `.env` |
| Container Kafka không start được, log báo không tìm thấy keystore | Chưa chạy `generate-certs.sh` trước khi `docker compose up`, hoặc sai đường dẫn mount | Chạy script tạo cert trước, kiểm tra `volumes:` trong compose |
| `KAFKA_CERTIFICATE_PASSWORD` không khớp giữa lúc tạo cert và lúc chạy container | Password dùng để tạo `.jks` phải giống với giá trị broker dùng để mở nó | Luôn load `.env` (`source .env`) trước khi chạy `generate-certs.sh` |
