# TranslationAppFlutter

## FastAPI Backend Scaffold (Clean Architecture)

Project has been scaffolded with this backend structure:

```text
app/
├── api/
│   └── v1/
│       ├── api.py
│       └── endpoints/
├── core/
│   ├── config.py
│   ├── database.py
│   ├── dependencies.py
│   └── security.py
├── models/
├── repositories/
├── schemas/
└── services/
```

### SQLAlchemy + Alembic

- SQLAlchemy 2.0 async engine is configured in `app/core/database.py`.
- Alembic is configured in `alembic.ini` and `alembic/env.py`.
- Initial migration exists at `alembic/versions/20260407_0001_create_users_table.py`.

### Quick Start

1. Create virtual environment and install dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

1. Create `.env` from `.env.example` and update `DATABASE_URL`.

1. Run migrations:

```powershell
alembic upgrade head
```

1. Start API:

```powershell
uvicorn app.main:app --reload
```

1. Health check:

```text
GET http://127.0.0.1:8000/api/v1/health
```

### Staging environment

To run the backend in a local staging-like environment:

1. Copy `backend/.env.staging.example` to `backend/.env.staging.local`.
2. Update `SECRET_KEY`, `DATABASE_URL`, and `REDIS_URL` as needed.
3. Start staging services:

```powershell
docker-compose -f docker-compose.staging.yml up -d
```

4. Check staging health:

```text
GET http://127.0.0.1:8001/api/v1/health
```

### Production and Monitoring

The repository includes production and monitoring support:

- `docker-compose.prod.yml` for production-style deployment.
- `docker-compose.monitoring.yml` for Prometheus, Grafana, Alertmanager and Postgres exporter.
- Prometheus configuration: `prometheus.yml`
- Alert rules: `alert_rules.yml`
- Grafana provisioning: `grafana/provisioning/`
- Dashboard JSON: `grafana/dashboards/translation_app.json`
- Database index tuning SQL: `backend/db_indexes.sql`
- Load test helper: `backend/scripts/load_test.py`

#### Start monitoring stack

```powershell
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

#### Start production stack

```powershell
docker compose -f docker-compose.prod.yml up -d --build
```

#### Load testing example

```powershell
python backend/scripts/load_test.py --host http://localhost:8000 --concurrency 20 --requests 100 --endpoint /health
```
