"""
Kafka producer chạy từ bên ngoài internet, kết nối tới cluster qua listener
EXTERNAL (SASL_SSL) trên public IP 103.75.186.139.

Yêu cầu trước khi chạy:
  pip install confluent-kafka python-dotenv
  export KAFKA_CLIENT_USERS / KAFKA_CLIENT_PASSWORDS (giống giá trị trong .env của cluster)
  File certs/ca-cert.pem phải tồn tại (export từ kafka-0.truststore.jks bằng keytool -list -rfc)
"""

import os

from confluent_kafka import KafkaError, Producer

BOOTSTRAP_SERVERS = ",".join(
    [
        "103.75.186.139:9095",
        "103.75.186.139:9096",
        "103.75.186.139:9097",
    ]
)

CA_CERT_PATH = os.path.join(os.path.dirname(__file__), "certs", "ca-cert.pem")

conf = {
    "bootstrap.servers": BOOTSTRAP_SERVERS,
    # EXTERNAL listener = SASL_SSL: cần login (SASL/PLAIN) + mã hoá TLS.
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "PLAIN",
    "sasl.username": os.environ["KAFKA_CLIENT_USERS"],
    "sasl.password": os.environ["KAFKA_CLIENT_PASSWORDS"],
    # Vì broker dùng self-signed CA (không phải CA công khai), client cần
    # được chỉ rõ CA cert này để tin cậy chứng chỉ broker đưa ra.
    "ssl.ca.location": CA_CERT_PATH,
    # Tối ưu độ an toàn: chờ mọi in-sync replica ghi xong mới coi là thành công.
    "acks": "all",
    # Cấu hình batch/linger — gom message lại thành từng batch, tăng throughput.
    "linger.ms": 20,
    "batch.size": 32768,
}

producer = Producer(conf)


def on_delivery(err: KafkaError | None, msg) -> None:
    """Callback chạy khi broker đã ack (hoặc báo lỗi) cho một message."""
    if err is not None:
        print(f"Gửi thất bại: {err}")
        return
    print(
        f"Đã ghi vào broker: topic={msg.topic()} "
        f"partition={msg.partition()} offset={msg.offset()}"
    )


def main() -> None:
    topic = "orders"
    orders = [
        {"key": "user-42", "value": "order-created:sku=A100,qty=2"},
        {"key": "user-42", "value": "order-shipped:sku=A100,qty=2"},
        {"key": "user-7", "value": "order-created:sku=B200,qty=1"},
    ]

    for order in orders:
        # produce() không block — message vào buffer nội bộ của producer,
        # gửi thật đi khi batch đầy hoặc linger.ms hết hạn.
        producer.produce(
            topic,
            key=order["key"],
            value=order["value"],
            callback=on_delivery,
        )
        # poll() để thread nền xử lý callback (và các sự kiện SASL/SSL, lỗi mạng...).
        producer.poll(0)

    # flush() chờ cho tới khi mọi message trong buffer được gửi và ack xong,
    # hoặc hết timeout. Luôn gọi trước khi kết thúc chương trình.
    producer.flush(timeout=10)


if __name__ == "__main__":
    main()
