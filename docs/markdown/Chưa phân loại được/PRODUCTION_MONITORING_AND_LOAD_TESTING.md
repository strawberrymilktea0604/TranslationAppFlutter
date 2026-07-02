# Production, Monitoring, and Load Testing for TranslationApp

## 1. Tối ưu Index PostgreSQL

1. Sau khi kết nối vào database, tệp `backend/db_indexes.sql` sẽ tạo:
   - `pg_trgm` extension để tối ưu tìm kiếm `ILIKE '%...%'`
   - index composite cho `translations(user_id, created_at DESC)`
   - index composite cho `translations(user_id, source_language, target_language, created_at DESC)`
   - index GIN cho `source_text` và `translated_text`
   - index cho bảng `vocabularies`, `conversation_sessions`, `conversation_messages` và `api_metrics`

2. Đây là bước tự động: backend gọi `ensure_database_indexes()` trong `backend/app/main.py` khi khởi động.

## 2. Thiết lập Prometheus & Grafana

- Prometheus cấu hình trong `prometheus.yml`
- Grafana datasource và dashboard tự động provision trong `grafana/provisioning`
- Các dịch vụ monitoring được cấu hình trong `docker-compose.monitoring.yml`

### Khởi động stack monitoring

```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

### Truy cập

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000
- Alertmanager: http://localhost:9093

### Dashboard mẫu

- file dashboard: `grafana/dashboards/translation_app.json`
- datasource Grafana: Prometheus

## 3. Thiết lập cảnh báo tự động

Alert rules có trong tệp `alert_rules.yml`:

- `BackendHighErrorRate` — lỗi 5xx > 5% trong 5 phút
- `BackendHighLatency` — 95th percentile latency > 5 giây
- `PostgresExporterDown`
- `BackendDown`

Alertmanager được cấu hình trong `alertmanager.yml` với mẫu email receiver. Bạn nên cập nhật thông tin SMTP thực tế trước khi dùng trong production.

## 4. Triển khai môi trường Production

### File cấu hình

- `docker-compose.prod.yml`
- `backend/.env.production.example`

### Chạy production local

1. Tạo `backend/.env.production` từ file example.
2. Build và khởi động:
   ```bash
   docker compose -f docker-compose.prod.yml up -d --build
   ```

## 5. Kiểm thử chịu tải

### Script load test

- File: `backend/scripts/load_test.py`
- Ví dụ chạy kiểm thử endpoint translate/text:
  ```bash
  python backend/scripts/load_test.py --host http://localhost:8000 --concurrency 20 --requests 100 --endpoint /api/v1/translate/text
  ```

### Kiểm thử endpoint health

```bash
python backend/scripts/load_test.py --host http://localhost:8000 --concurrency 20 --requests 100 --endpoint /health
```

## 6. Ghi chú quan trọng

- Backend hiện đã có `/metrics` để Prometheus scrape.
- Nếu bạn dùng môi trường production thật, cần cập nhật `backend/.env.production` với `SECRET_KEY` mạnh và giá trị `DATABASE_URL`/`REDIS_URL` thực tế.
- Nếu muốn alert thực sự gửi email, cập nhật `alertmanager.yml` với cấu hình SMTP đúng.
