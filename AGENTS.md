# TranslationAppFlutter Agent Guidelines

## Backend Development

### Setup
1. Create virtual environment: `python -m venv .venv`
2. Activate: `.\.venv\Scripts\Activate.ps1` (PowerShell)
3. Install dependencies: `pip install -r backend/requirements.txt`
4. Copy `.env.example` to `.env` and update `DATABASE_URL`

### Database
- Run migrations: `alembic upgrade head`
- Migration files: `backend/alembic/versions/`

### Development Server
- Start API: `uvicorn app.main:app --reload`
- Health check: `GET http://127.0.0.1:8000/api/v1/health`
- Staging: `docker-compose -f docker-compose.staging.yml up -d` (checks on port 8001)

### Code Quality
- Linting: `ruff check backend`
- Tests: Likely `pytest` (check `backend/tests/`)

### Project Structure
- Clean architecture: `app/{api,core,models,repositories,schemas,services}`
- API v1 endpoints: `app/api/v1/endpoints/`
- Core config/database/security: `app/core/`

## Frontend Development
- Flutter project in `frontend/`
- Standard Flutter tooling applies

## Important Notes
- Backend and frontend are separate projects
- Environment files are critical for database connections
- Alembic migrations must be run before starting the server
- Health endpoints differ between local (8000) and staging (8001)