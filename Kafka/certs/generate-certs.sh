#!/bin/bash
# Generate self-signed CA + per-broker keystore/truststore for Kafka SASL_SSL (EXTERNAL listener).
# Run this once before starting the cluster: ./certs/generate-certs.sh
set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD="${KAFKA_CERTIFICATE_PASSWORD:-changeit}"
PUBLIC_IP="103.75.186.139"
DAYS_VALID=3650
BROKERS=(kafka-0 kafka-1 kafka-2)

cd "$CERT_DIR"
rm -f ./*.jks ./*.srl ./*.csr ./*.crt ./*.key ./ca-cert*

echo "== 1. Generating self-signed CA =="
openssl req -new -x509 -keyout ca-key -out ca-cert -days "$DAYS_VALID" \
  -subj "/CN=kafka-cluster-ca/OU=dev/O=personal-projects" \
  -passin pass:"$PASSWORD" -passout pass:"$PASSWORD"

for broker in "${BROKERS[@]}"; do
  echo "== Generating keystore/truststore for $broker =="

  keystore="${broker}.keystore.jks"
  truststore="${broker}.truststore.jks"

  # 1. Create broker's private key + self-signed cert request, with SANs
  #    covering the public IP and the Docker-internal hostname.
  keytool -genkeypair -keystore "$keystore" -alias "$broker" \
    -validity "$DAYS_VALID" -keyalg RSA -keysize 2048 \
    -dname "CN=${broker}, OU=dev, O=personal-projects" \
    -ext "SAN=dns:${broker},ip:${PUBLIC_IP}" \
    -storepass "$PASSWORD" -keypass "$PASSWORD"

  # 2. Create a certificate signing request and sign it with our CA.
  keytool -certreq -keystore "$keystore" -alias "$broker" \
    -file "${broker}.csr" -storepass "$PASSWORD" \
    -ext "SAN=dns:${broker},ip:${PUBLIC_IP}"

  openssl x509 -req -CA ca-cert -CAkey ca-key -in "${broker}.csr" \
    -out "${broker}-signed.crt" -days "$DAYS_VALID" -CAcreateserial \
    -passin pass:"$PASSWORD" \
    -extfile <(printf "subjectAltName=DNS:%s,IP:%s" "$broker" "$PUBLIC_IP")

  # 3. Import CA cert + signed cert back into the broker's keystore.
  keytool -importcert -keystore "$keystore" -alias CARoot \
    -file ca-cert -storepass "$PASSWORD" -noprompt
  keytool -importcert -keystore "$keystore" -alias "$broker" \
    -file "${broker}-signed.crt" -storepass "$PASSWORD" -noprompt

  # 4. Truststore: clients (and other brokers) trust our CA.
  keytool -importcert -keystore "$truststore" -alias CARoot \
    -file ca-cert -storepass "$PASSWORD" -noprompt

  rm -f "${broker}.csr" "${broker}-signed.crt"
done

echo "== Done. Files created in $CERT_DIR: =="
ls -1 ./*.jks

cat <<EOF

Next steps:
  1. Set KAFKA_CERTIFICATE_PASSWORD=${PASSWORD} in your .env file (must match this script's password).
  2. For any external client connecting over SASL_SSL, copy kafka-N.truststore.jks
     (any one of them - they all trust the same CA) to the client machine and set:
       ssl.truststore.location=/path/to/kafka-0.truststore.jks
       ssl.truststore.password=${PASSWORD}
     Since this is a self-signed CA (not a public one), the client must have this
     truststore, or it will reject the broker's certificate as untrusted.
EOF
