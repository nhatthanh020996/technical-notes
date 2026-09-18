Dưới đây là phương án active-standby hoàn chỉnh cho nginx OSS. Cốt lõi: dùng **OpenResty** + `lua-resty-upstream-healthcheck` để có active health check, kết hợp `backup` để làm standby.

---

## 1. Kiến trúc

```
Client → [nginx OSS (OpenResty)] → Kong cụm 1 (10.0.1.10:8000)  ← primary
                                 → Kong cụm 2 (10.0.2.10:8000)  ← backup
```

Health check chủ động ping mỗi 2s vào **cả hai** cụm. Khi cụm 1 fail 3 lần liên tiếp, lua đánh dấu peer down → nginx tự động dồn traffic sang cụm 2.

---

## 2. Cài OpenResty

Ubuntu/Debian:
```bash
wget -qO - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" \
  | sudo tee /etc/apt/sources.list.d/openresty.list
sudo apt update && sudo apt install -y openresty
```

RHEL/Rocky:
```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://openresty.org/package/centos/openresty.repo
sudo dnf install -y openresty
```

Module `lua-resty-upstream-healthcheck` đã có sẵn trong OpenResty, không cần cài thêm.

---

## 3. Tạo health endpoint đi XUYÊN QUA Kong

Đây là bước hay bị làm sai. Đừng check `:8001/status` của Kong — nó chỉ nói Kong còn sống.

Trên **mỗi** cụm Kong, tạo route trỏ tới một service health thật ở phía sau:

```bash
# tạo service trỏ tới backend thật
curl -i -X POST http://localhost:8001/services \
  --data name=lb-health \
  --data url=http://10.0.1.20:8080/health

# route match theo path, không ràng buộc host
curl -i -X POST http://localhost:8001/services/lb-health/routes \
  --data name=lb-health-route \
  --data 'paths[]=/lb-health' \
  --data strip_path=true
```

Kiểm tra:
```bash
curl -i http://10.0.1.10:8000/lb-health   # phải trả 200
curl -i http://10.0.2.10:8000/lb-health
```

Nếu backend chưa có endpoint `/health`, tạm thời có thể trỏ vào một upstream có sẵn, nhưng nên có endpoint thật kiểm tra được DB/dependency chính.

**Bảo vệ endpoint này:** thêm plugin `ip-restriction` trên route để chỉ IP của nginx gọi được.

---

## 4. File cấu hình đầy đủ

`/usr/local/openresty/nginx/conf/nginx.conf`

```nginx
user  nobody;
worker_processes auto;
worker_rlimit_nofile 65535;

error_log  /var/log/openresty/error.log warn;
pid        /var/run/openresty.pid;

events {
    worker_connections 10240;
    multi_accept on;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    # ---- log: có $upstream_addr để biết request đi vào cụm nào ----
    log_format lb '$remote_addr - [$time_local] "$request" '
                  '$status $body_bytes_sent '
                  'up=$upstream_addr up_status=$upstream_status '
                  'rt=$request_time urt=$upstream_response_time';
    access_log /var/log/openresty/access.log lb buffer=32k flush=5s;

    sendfile      on;
    tcp_nopush    on;
    tcp_nodelay   on;
    server_tokens off;

    client_max_body_size 50m;
    client_body_buffer_size 128k;

    # ---- shared dict cho health check, bắt buộc ----
    lua_shared_dict healthcheck 1m;
    lua_socket_log_errors off;

    # ---- hỗ trợ websocket đồng thời giữ keepalive ----
    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      '';
    }

    # =========================================================
    # UPSTREAM: cụm 1 primary, cụm 2 backup
    # =========================================================
    upstream kong_pool {
        server 10.0.1.10:8000 max_fails=3 fail_timeout=10s;   # cụm 1
        server 10.0.2.10:8000 backup max_fails=3 fail_timeout=10s;  # cụm 2

        keepalive 64;
        keepalive_timeout  60s;
        keepalive_requests 1000;
    }

    # =========================================================
    # ACTIVE HEALTH CHECK
    # =========================================================
    init_worker_by_lua_block {
        local hc = require "resty.upstream.healthcheck"

        local ok, err = hc.spawn_checker{
            shm       = "healthcheck",
            upstream  = "kong_pool",
            type      = "http",

            -- HTTP/1.0 là bắt buộc với module này
            http_req  = "GET /lb-health HTTP/1.0\r\n"
                     .. "Host: lb-health.internal\r\n"
                     .. "User-Agent: nginx-healthcheck\r\n"
                     .. "Connection: close\r\n\r\n",

            interval  = 2000,   -- ping mỗi 2s
            timeout   = 1500,   -- timeout 1.5s cho mỗi lần ping
            fall      = 3,      -- fail 3 lần liên tiếp -> down  (~6s)
            rise      = 5,      -- pass 5 lần liên tiếp -> up    (~10s), chống flapping
            valid_statuses = {200},
            concurrency = 2,
        }
        if not ok then
            ngx.log(ngx.ERR, "spawn healthchecker failed: ", err)
        end
    }

    # =========================================================
    # SERVER CHÍNH
    # =========================================================
    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        http2 on;
        server_name api.example.com;

        ssl_certificate     /etc/ssl/certs/api.crt;
        ssl_certificate_key /etc/ssl/private/api.key;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_session_cache   shared:SSL:20m;
        ssl_session_timeout 1d;

        location / {
            proxy_pass http://kong_pool;

            proxy_http_version 1.1;
            proxy_set_header Upgrade    $http_upgrade;
            proxy_set_header Connection $connection_upgrade;

            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host  $host;
            proxy_set_header X-Forwarded-Port  $server_port;

            proxy_connect_timeout 2s;
            proxy_send_timeout    60s;
            proxy_read_timeout    60s;

            # passive check: lưới an toàn cho request đang bay
            proxy_next_upstream         error timeout http_502 http_503 http_504;
            proxy_next_upstream_tries   2;
            proxy_next_upstream_timeout 8s;

            proxy_buffering on;
            proxy_buffer_size   8k;
            proxy_buffers       16 8k;
        }
    }

    # =========================================================
    # TRANG TRẠNG THÁI - chỉ localhost
    # =========================================================
    server {
        listen 127.0.0.1:8090;

        location = /hc-status {
            access_log off;
            default_type text/plain;
            content_by_lua_block {
                local hc = require "resty.upstream.healthcheck"
                ngx.say("worker pid: ", ngx.worker.pid())
                ngx.print(hc.status_page())
            }
        }

        # endpoint JSON cho monitoring: 200 nếu primary UP, 503 nếu đang chạy backup
        location = /hc-primary {
            access_log off;
            default_type application/json;
            content_by_lua_block {
                local hc  = require "resty.upstream.healthcheck"
                local page = hc.status_page() or ""
                local primary_up = page:find("10%.0%.1%.10:8000 up") ~= nil
                if not primary_up then ngx.status = 503 end
                ngx.say(string.format('{"primary_up":%s}', tostring(primary_up)))
            }
        }
    }
}
```

Áp dụng:
```bash
sudo openresty -t && sudo systemctl reload openresty
```

---

## 5. Kiểm tra

```bash
# trạng thái hiện tại
curl -s http://127.0.0.1:8090/hc-status
```
Output mong đợi:
```
Upstream kong_pool
    Primary Peers
        10.0.1.10:8000 up
    Backup Peers
        10.0.2.10:8000 up
```

**Diễn tập failover:**
```bash
# trên cụm 1, chặn cổng 8000 từ nginx
sudo iptables -A INPUT -s <IP_nginx> -p tcp --dport 8000 -j DROP

# sau ~6s, kiểm tra lại
curl -s http://127.0.0.1:8090/hc-status     # primary phải là "DOWN"
tail -f /var/log/openresty/access.log       # up=10.0.2.10:8000

# khôi phục
sudo iptables -D INPUT -s <IP_nginx> -p tcp --dport 8000 -j DROP
# sau ~10s (rise=5) primary quay lại "up", traffic tự về cụm 1
```

Đo downtime thực tế bằng cách chạy song song:
```bash
while true; do curl -s -o /dev/null -w "%{http_code} " https://api.example.com/ping; sleep 0.2; done
```

---

## 6. Những điểm bắt buộc phải nắm

**Failback tự động.** Với `rise=5`, cụm 1 vừa sống lại là traffic quay về ngay. Nếu cụm 1 chết vì quá tải, nó có thể chết lại lần nữa (flapping). Nếu muốn failback thủ công: đặt `rise = 9999`, khi nào sẵn sàng thì `systemctl reload openresty` để reset.

**Không dùng hostname trong `upstream`.** nginx OSS resolve DNS một lần lúc start và cache vĩnh viễn. Dùng IP.

**`backup` không dùng được với `hash` / `ip_hash`.** Nếu API của bạn cần sticky session thì phải xử lý ở tầng khác, hoặc chuyển sang share session store.

**POST/PUT không được retry** với config trên — đúng như vậy, để tránh double-write. Chỉ thêm `non_idempotent` vào `proxy_next_upstream` nếu bạn chắc chắn API idempotent.

**Health check khác với "cụm khỏe".** Endpoint `/lb-health` chỉ nên fail khi cụm thật sự không phục vụ được. Nếu nó check quá nhiều dependency (Redis, service phụ...), một dependency nhỏ chết sẽ kéo cả cụm ra khỏi pool oan.

**Bật health check ở tầng Kong nữa.** Hai tầng độc lập:
```bash
curl -X PATCH http://localhost:8001/upstreams/<name> \
  --data 'healthchecks.active.healthy.interval=5' \
  --data 'healthchecks.active.unhealthy.interval=3' \
  --data 'healthchecks.active.http_path=/health'
```

---

## 7. Monitoring — quan trọng không kém

Failover chạy êm quá thì bạn sẽ chạy trên cụm 2 suốt tuần mà không biết. Bắt buộc phải có alert.

**Prometheus blackbox exporter:**
```yaml
- job_name: 'lb-primary'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets: ['http://127.0.0.1:8090/hc-primary']
```
Alert khi `probe_success == 0` (endpoint trả 503 = đang chạy backup).

**Hoặc cron đơn giản:**
```bash
#!/bin/bash
# /usr/local/bin/check-lb-primary.sh — chạy mỗi phút
if ! curl -sf http://127.0.0.1:8090/hc-primary >/dev/null; then
    curl -s -X POST "$SLACK_WEBHOOK" \
      -d '{"text":"[LB] Cụm 1 DOWN, đang chạy trên cụm 2 (backup)"}'
fi
```

Thêm alert trên tỉ lệ 5xx ở tầng nginx nữa — có trường hợp cả hai cụm cùng lỗi mà health check vẫn pass.

---

## 8. Còn một SPOF nữa

Con nginx này chết là chết hết, dù hai cụm Kong đều khỏe. Nếu chưa xử lý, dựng 2 nginx + keepalived VIP:

```
# node A: priority 150, node B: priority 100
vrrp_script chk_nginx {
    script "/usr/bin/pgrep -x nginx"
    interval 2
    weight -60
}
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 150
    advert_int 1
    virtual_ipaddress { 10.0.0.100/24 }
    track_script { chk_nginx }
}
```

Config nginx đồng bộ y hệt trên cả hai node.

---

**Nếu không cài được OpenResty** (chính sách hạ tầng, image cố định...), phương án thay thế gọn nhất là bỏ nginx ở tầng LB và dùng HAProxy — active health check + backup server là tính năng mặc định, cấu hình chỉ khoảng 15 dòng. Cho tao biết nếu bạn muốn bản HAProxy tương đương.