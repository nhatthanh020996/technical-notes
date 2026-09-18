```yml
version: '3.8'

services:
  # --- TRÁI TIM CỦA HỆ THỐNG: TRAEFIK REVERSE PROXY ---
  traefik:
    image: traefik:v3.0
    container_name: traefik_gateway
    command:
      # 1. Bật Dashboard giao diện web (Cổng 8080)
      - "--api.insecure=true"
      - "--api.dashboard=true"
      
      # 2. Cấu hình Provider: Docker
      # Traefik sẽ lắng nghe các sự kiện từ Docker Socket để tự cập nhật cấu hình
      - "--providers.docker=true"
      
      # 3. Bảo mật: Không tự động expose mọi container
      # Chỉ container nào có nhãn "traefik.enable=true" mới được định tuyến
      - "--providers.docker.exposedbydefault=false"
      
      # 4. ENTRYPOINTS: Định nghĩa cổng vật lý mà Traefik lắng nghe
      # Ở đây ta đặt tên cổng 80 là "web"
      - "--entrypoints.web.address=:80"
      
      # 5. METRICS: (Tùy chọn) Bật để thu thập dữ liệu hiệu năng
      - "--metrics.prometheus=true"
    ports:
      - "80:80"       # Cổng HTTP chính cho người dùng truy cập
      - "8080:8080"   # Cổng truy cập Dashboard của Traefik
    volumes:
      # QUAN TRỌNG: Cho phép Traefik sử dụng docker API để đọc thông tin các container đang chạy
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    networks:
      - proxy-net     # Chỉ kết nối vào mạng proxy để tăng tính bảo mật

  # --- DỊCH VỤ BACKEND: FASTAPI ---
  api:
    build: ./backend  # Build từ Dockerfile trong thư mục backend của bạn
    container_name: fastapi_app
    restart: unless-stopped
    depends_on:
      - db            # Đảm bảo Database khởi động trước
    environment:
      - DATABASE_URL=postgresql://myuser:mypassword@db:5432/mydb
    labels:
      # --- DYNAMIC CONFIGURATION (Cấu hình động qua Labels) ---

      # A. Bật Traefik cho service này
      - "traefik.enable=true"

      # Cú pháp sẽ là: traefik.http.[routers|services|middlewares].<TÊN_DO_MÀY_ĐẶT>.<THUỘC_TÍNH>
      # Thuộc tính của router: rule, entrypoints, middlewares, service, tls, tls.certresolver
      # Thuộc tính của service: loadbalancer.server.port, loadbalancer.server.weight, loadbalancer.sticky, v.v.
      # Thuộc tính của middleware: stripprefix, addprefix, retry, circuitbreaker, v.v.


      # B. ROUTER: Định nghĩa luật điều hướng (The Brain)
      # Tên router: "fastapi-router". Luật: Nếu Host là "api.localhost" và Path bắt đầu bằng "/v1"
      - "traefik.http.routers.fastapi-router.rule=Host(`api.localhost`) && PathPrefix(`/v1`)"
      # Chỉ định router này lắng nghe ở entrypoint "web" (cổng 80)
      - "traefik.http.routers.fastapi-router.entrypoints=web"

      # C. MIDDLEWARE: Các bộ lọc trung gian (The Filters)
      # Tạo một middleware tên "strip-v1" để xóa tiền tố "/v1" trước khi gửi tới FastAPI
      - "traefik.http.middlewares.strip-v1.stripprefix.prefixes=/v1"
      # Gắn middleware "strip-v1" vào "fastapi-router"
      - "traefik.http.routers.fastapi-router.middlewares=strip-v1"

      # D. SERVICE: Định nghĩa đích đến (The Destination)
      # Tên service: "fastapi-svc". Khai báo port mà app đang chạy bên trong container
      - "traefik.http.services.fastapi-svc.loadbalancer.server.port=8000"
      # Liên kết Router với Service (Mặc định sẽ tự hiểu nếu chỉ có 1 service)
      - "traefik.http.routers.fastapi-router.service=fastapi-svc"
    networks:
      - proxy-net     # Để Traefik có thể gọi tới
      - db-net        # Để gọi tới Database (Mạng nội bộ)

  # --- CƠ SỞ DỮ LIỆU: POSTGRESQL ---
  db:
    image: postgres:15-alpine
    container_name: postgres_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypassword
      POSTGRES_DB: mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    # LƯU Ý: Không có Labels Traefik vì DB không nên được expose ra ngoài Internet
    networks:
      - db-net        # Chỉ nằm trong mạng nội bộ với API
    # Không dùng 'ports' để đảm bảo không ai có thể kết nối từ bên ngoài vào DB

# --- ĐỊNH NGHĨA MẠNG (NETWORKS) ---
networks:
  proxy-net:          # Mạng dùng chung giữa Traefik và các API công khai
    driver: bridge
  db-net:             # Mạng riêng tư, cô lập hoàn toàn Database
    driver: bridge

# --- ĐỊNH NGHĨA LƯU TRỮ (VOLUMES) ---
volumes:
  postgres_data:      # Lưu trữ dữ liệu DB bền vững khi container restart

```