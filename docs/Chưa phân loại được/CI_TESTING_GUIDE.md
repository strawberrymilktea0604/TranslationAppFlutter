# CI/CD Testing Guide - TranslationAppFlutter

## Overview

This guide explains how unit tests and E2E tests are integrated into the CI/CD pipeline for the TranslationAppFlutter backend. The pipeline automatically runs tests when you push code or create a pull request.

## CI/CD Pipeline Structure

### Workflow File
- **Location**: `.github/workflows/backend-ci.yml`
- **Trigger Events**: 
  - Push to `main` branch (paths: `backend/**`, `docker-compose.test.yml`, `.github/workflows/backend-ci.yml`)
  - Pull requests to `main` branch
  - Manual trigger via `workflow_dispatch`

### Pipeline Jobs

The CI pipeline consists of the following sequential and parallel jobs:

#### 1. **Lint & Code Quality** (Parallel, Required)
- **Purpose**: Check code style, syntax, and quality
- **Tools**: 
  - `ruff`: Python linting
  - `black`: Code formatting check
  - `compileall`: Syntax validation
- **Status**: Must pass before tests run
- **Output**: Errors/warnings displayed in PR comments

#### 2. **Unit Tests** (Parallel, Requires: Lint) ✅
- **Purpose**: Test individual components in isolation
- **Method**: Docker container with minimal setup
- **Services**: Local PostgreSQL and Redis
- **Coverage**: Reports HTML and terminal output
- **Timeout**: 300 seconds per test
- **Artifacts**: Coverage report (7-day retention)

#### 3. **Integration Tests** (Parallel, Requires: Lint)
- **Purpose**: Test components working together
- **Method**: Docker Compose with full service stack
- **Services**: PostgreSQL, Redis (via docker-compose.test.yml)
- **Coverage**: Appended to unit test coverage
- **Artifacts**: Coverage report (7-day retention)

#### 4. **E2E Tests** (Sequential, Requires: Unit Tests)
- **Purpose**: Test complete workflows across the application
- **Method**: Docker Compose with full services
- **Scope**: Tests in `backend/tests/e2e/` directory
- **Skip Logic**: Automatically skips if no E2E tests found
- **Coverage**: Combined with integration test coverage
- **Artifacts**: Test results (7-day retention)

#### 5. **Build Production Image** (Sequential, Requires: Lint + Unit Tests)
- **Trigger**: Only on push to `main` after tests pass
- **Purpose**: Build and cache Docker image for production
- **Tags**: `latest` and `{git-sha}`
- **Cache**: Uses GitHub Actions cache layer

#### 6. **Test Summary** (Final, Always Runs)
- **Purpose**: Summarize test results
- **Output**: 
  - GitHub Step Summary
  - PR comment (if applicable)
- **Artifacts**: Downloads all coverage reports

## Running Tests Locally

### Prerequisites
```bash
# Navigate to backend directory
cd backend

# Python 3.10+ required
python --version

# Create virtual environment
python -m venv .venv

# Activate (Windows)
.\.venv\Scripts\Activate.ps1

# Activate (Mac/Linux)
source .venv/bin/activate
```

### Install Dependencies
```bash
# Install all dependencies including test tools
pip install -r requirements-dev.txt
```

### Run Tests Using Docker

#### Unit Tests Only
```bash
docker-compose -f docker-compose.test.yml run --rm backend-tests
```

#### Unit Tests with Coverage Report
```bash
docker-compose -f docker-compose.test.yml run --rm backend-tests \
  pytest tests/ -v --cov=app --cov-report=html
```

#### E2E Tests Only (if exists)
```bash
docker-compose -f docker-compose.test.yml run --rm backend-tests \
  pytest tests/e2e/ -v --cov=app --cov-report=html
```

#### Specific Test File
```bash
docker-compose -f docker-compose.test.yml run --rm backend-tests \
  pytest tests/test_admin.py -v
```

#### Specific Test Class/Function
```bash
docker-compose -f docker-compose.test.yml run --rm backend-tests \
  pytest tests/test_admin.py::TestAdminEndpoints::test_get_users -v
```

### Run Tests Without Docker

#### Start Services First
```bash
# Terminal 1: Database
docker run --rm -p 5433:5432 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=test_password \
  -e POSTGRES_DB=translation_app_test \
  postgres:15

# Terminal 2: Redis
docker run --rm -p 6379:6379 redis:7
```

#### Run Tests
```bash
# Terminal 3: Backend tests
export DATABASE_URL="postgresql://postgres:test_password@localhost:5433/translation_app_test"
export REDIS_URL="redis://localhost:6379"
export SECRET_KEY="test-secret-key"
export TESTING="true"

pytest tests/ -v --cov=app --cov-report=html
```

### Run Linting Locally
```bash
# Lint check
ruff check .

# Format check
black --check .

# Format and fix
black .

# Sort imports
isort .
```

## Test Organization

### Directory Structure
```
backend/
├── tests/
│   ├── __init__.py
│   ├── conftest.py                    # Shared fixtures
│   ├── test_e2e_utils.py             # E2E utilities
│   ├── test_*_examples.py            # Integration examples
│   ├── test_admin.py                 # Existing unit tests
│   ├── test_api_metrics.py           # Existing unit tests
│   ├── ... other unit tests
│   └── e2e/
│       ├── __init__.py
│       ├── test_api_workflows.py     # API E2E tests
│       └── ... more E2E tests
├── pytest.ini                         # Pytest configuration
├── requirements-dev.txt              # Dev dependencies
├── Dockerfile.test                   # Test image
└── ... other backend files
```

### Test Markers

Tests are marked with markers for organization:

```python
@pytest.mark.unit
def test_something():
    pass

@pytest.mark.integration
def test_something_integrated():
    pass

@pytest.mark.e2e
def test_complete_workflow():
    pass

@pytest.mark.slow
def test_slow_operation():
    pass

@pytest.mark.async
async def test_async_function():
    pass
```

Run tests by marker:
```bash
# Only unit tests
pytest -m unit

# Only integration tests
pytest -m integration

# Only E2E tests
pytest -m e2e

# Skip slow tests
pytest -m "not slow"
```

## Writing Tests

### Unit Test Template
```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

@pytest.mark.unit
class TestMyFeature:
    def test_basic_functionality(self, client: TestClient, db_session: Session):
        """Test basic functionality."""
        response = client.get("/api/v1/endpoint")
        assert response.status_code == 200
```

### E2E Test Template
```python
import pytest
from fastapi.testclient import TestClient

@pytest.mark.e2e
class TestCompleteWorkflow:
    def test_end_to_end_flow(self, client: TestClient, test_factory, db_session):
        """Test complete workflow."""
        # Setup
        user = test_factory.create_test_user(db_session)
        
        # Execute
        response = client.get(f"/api/v1/users/{user.id}")
        
        # Verify
        assert response.status_code == 200
        assert response.json()["id"] == user.id
```

### Using Fixtures

Available fixtures (defined in `conftest.py`):

- **`client`**: FastAPI TestClient
- **`db_session`**: SQLAlchemy database session
- **`db_engine`**: Database engine
- **`test_factory`**: TestDataFactory for creating test data
- **`auth_headers`**: Pre-configured auth headers

## Debugging Failed Tests

### In GitHub Actions

1. **View Logs**: Click job → expand steps
2. **Download Artifacts**: Coverage reports available in Artifacts tab
3. **Check PR Comment**: Test summary posted as PR comment
4. **Re-run Failed Jobs**: Use "Re-run" button to retry

### Locally

```bash
# Verbose output
pytest -vv tests/

# Show print statements
pytest -s tests/

# Stop on first failure
pytest -x tests/

# Show local variables on failure
pytest -l tests/

# Debug specific test
pytest -vv tests/test_admin.py::TestAdminEndpoints::test_get_users --pdb
```

## Performance Optimization

### Test Execution Time

- **Unit Tests**: ~2-5 minutes (Docker)
- **Integration Tests**: ~3-5 minutes
- **E2E Tests**: ~2-3 minutes
- **Total Pipeline**: ~10-15 minutes

### Optimization Tips

1. **Parallel Execution**: 
   ```bash
   pytest -n auto  # Uses pytest-xdist
   ```

2. **Run Only Changed Tests**:
   ```bash
   pytest --lf  # Last failed
   pytest --ff  # Failed first
   ```

3. **Skip Slow Tests**:
   ```bash
   pytest -m "not slow"
   ```

4. **Coverage Thresholds**: Adjust in `.coveragerc` or `pytest.ini`

## Troubleshooting

### Common Issues

#### 1. "Database connection refused"
**Solution**: Ensure PostgreSQL is running on port 5433
```bash
docker ps | grep postgres
```

#### 2. "Redis connection refused"
**Solution**: Ensure Redis is running on port 6379
```bash
docker ps | grep redis
```

#### 3. "Tests timeout"
**Solution**: Increase timeout in `pytest.ini`
```ini
timeout = 600  # 10 minutes
```

#### 4. "Import errors in tests"
**Solution**: Ensure backend is in Python path (conftest.py handles this)

#### 5. "Fixture not found"
**Solution**: Check that fixture is defined in `conftest.py` or test file

## CI/CD Security

### Best Practices

1. **Secrets Management**: Use GitHub Secrets for sensitive data
2. **Dependency Pinning**: Lock all versions in requirements.txt
3. **Image Scanning**: Docker images are scanned for vulnerabilities
4. **Branch Protection**: Require CI to pass before merging

### Environment Variables

Test environment uses:
- `DATABASE_URL`: Test database connection string
- `REDIS_URL`: Test Redis connection
- `SECRET_KEY`: Test-specific secret
- `TESTING`: Flag indicating test mode

## Maintenance

### Regular Tasks

1. **Update Dependencies**: Monthly
   ```bash
   pip install --upgrade pip
   pip install -U -r requirements-dev.txt
   ```

2. **Review Test Coverage**: Aim for >80%
3. **Refactor Slow Tests**: Identify and optimize
4. **Clean Up Artifacts**: Old coverage reports auto-delete (7 days)

### Adding New Tests

1. Create test file: `tests/test_feature_name.py`
2. Add test class/function with `@pytest.mark.unit` or `@pytest.mark.e2e`
3. Use provided fixtures
4. Push and watch CI run automatically

## References

- **Pytest Docs**: https://docs.pytest.org/
- **FastAPI Testing**: https://fastapi.tiangolo.com/tutorial/testing/
- **Docker Compose**: https://docs.docker.com/compose/
- **GitHub Actions**: https://docs.github.com/en/actions

## Support

For issues or questions about the CI/CD pipeline:

1. Check test logs in GitHub Actions
2. Review this guide
3. Consult pytest and FastAPI documentation
4. Run tests locally to debug
