# CI Testing - Quick Reference

## What Was Implemented

✅ **Unit Tests in Docker**: Runs pytest with PostgreSQL and Redis containers
✅ **Integration Tests**: Tests multiple components working together
✅ **E2E Tests**: End-to-end workflow tests
✅ **Code Linting**: Ruff and Black for code quality
✅ **Coverage Reports**: HTML and terminal coverage reports
✅ **Automatic CI on Push/PR**: GitHub Actions workflow triggers automatically

## Quick Start - Run Tests Locally

### Using Docker Compose (Recommended)

```bash
cd /path/to/TranslationAppFlutter

# Run all tests in Docker
docker-compose -f docker-compose.test.yml up

# Or run specific tests
docker-compose -f docker-compose.test.yml run --rm backend-tests \
  pytest tests/test_admin.py -v

# View coverage report
open backend/coverage/index.html  # macOS
start backend\coverage\index.html # Windows
```

### Without Docker (Manual Setup)

```bash
cd backend

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # or .\.venv\Scripts\Activate.ps1 on Windows

# Install dependencies
pip install -r requirements-dev.txt

# Set environment variables
export DATABASE_URL="postgresql://postgres:test_password@localhost:5433/translation_app_test"
export REDIS_URL="redis://localhost:6379"
export TESTING="true"

# Run tests
pytest tests/ -v --cov=app --cov-report=html
```

## CI/CD Pipeline Overview

```
┌─────────────────────────────────────────────────────────┐
│         Push to main / Create Pull Request              │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
    [LINT]         [UNIT]        [INTEGRATION]
    (Pass?)        TESTS          TESTS
        │              │              │
        └──────────┬───┴──────────────┘
                   │
             [E2E TESTS]
                   │
          [BUILD DOCKER IMAGE]
          (only on main push)
                   │
            [TEST SUMMARY]
         (PR comment + artifacts)
```

## File Structure

```
TranslationAppFlutter/
├── backend/
│   ├── requirements-dev.txt          ← Development dependencies
│   ├── pytest.ini                    ← Pytest configuration
│   ├── Dockerfile.test               ← Test image build file
│   ├── tests/
│   │   ├── conftest.py              ← Shared test fixtures
│   │   ├── test_e2e_utils.py        ← E2E utilities
│   │   ├── test_*_examples.py       ← Integration test examples
│   │   ├── test_admin.py            ← Existing unit tests
│   │   ├── test_api_metrics.py      ← Existing unit tests
│   │   └── e2e/
│   │       ├── __init__.py
│   │       └── test_api_workflows.py ← E2E test examples
│   └── ... other backend files
├── docker-compose.test.yml           ← Test environment setup
├── .github/
│   └── workflows/
│       └── backend-ci.yml            ← CI/CD Pipeline (UPDATED)
└── CI_TESTING_GUIDE.md              ← Full testing documentation
```

## Key Files Updated/Created

| File | Purpose |
|------|---------|
| `.github/workflows/backend-ci.yml` | Complete CI/CD pipeline with tests ✨ |
| `backend/requirements-dev.txt` | Test dependencies (pytest, etc.) |
| `backend/pytest.ini` | Pytest configuration |
| `backend/Dockerfile.test` | Docker image for running tests |
| `docker-compose.test.yml` | Services for testing (DB, Redis) |
| `backend/tests/e2e/` | E2E test directory with examples |
| `backend/tests/test_e2e_utils.py` | Test utilities and fixtures |
| `CI_TESTING_GUIDE.md` | Complete testing documentation |

## How to Write Tests

### Unit Test Example
```python
@pytest.mark.unit
class TestAdminAPI:
    def test_get_users_success(self, client: TestClient):
        response = client.get("/api/v1/admin/users")
        assert response.status_code == 200
```

### E2E Test Example
```python
@pytest.mark.e2e
class TestCompleteWorkflow:
    def test_user_creation_to_translation(self, client, test_factory, db_session):
        user = test_factory.create_test_user(db_session)
        response = client.get(f"/api/v1/users/{user.id}")
        assert response.status_code == 200
```

## Monitoring CI/CD Status

### In GitHub
1. Go to your repository
2. Click "Actions" tab
3. View running/completed workflows
4. Click job name to see detailed logs
5. Download coverage reports from "Artifacts"

### In Pull Request
- CI status shown under PR title
- Test summary posted as comment
- Coverage reports available in artifacts

## Common Commands

```bash
# Install test dependencies
pip install -r backend/requirements-dev.txt

# Run all tests with coverage
pytest tests/ -v --cov=app --cov-report=html

# Run specific test file
pytest tests/test_admin.py -v

# Run E2E tests only
pytest tests/e2e/ -v -m e2e

# Run with detailed output
pytest -vv --tb=long

# Stop on first failure
pytest -x

# Run failed tests first
pytest --ff

# Run in parallel
pytest -n auto

# Check linting
ruff check backend/

# Format code
black backend/
```

## Expected Test Output

When all tests pass, you'll see:
```
===== test session starts =====
collected 45 items

tests/test_admin.py::TestAdmin::test_get_users PASSED        [ 5%]
tests/test_api_metrics.py::TestMetrics::test_metrics PASSED  [10%]
...
====== 45 passed in 15.23s ======
------- coverage: 78.5% -------
```

## Troubleshooting

### Tests fail locally but pass in CI?
- Check Python version (should be 3.10)
- Ensure DATABASE_URL and REDIS_URL are set
- Try running in Docker: `docker-compose -f docker-compose.test.yml up`

### Tests timeout?
- Increase timeout in `pytest.ini`
- Skip slow tests: `pytest -m "not slow"`

### Import errors?
- Install dev dependencies: `pip install -r backend/requirements-dev.txt`
- Ensure you're in the right directory

### Database connection refused?
- Check if PostgreSQL is running: `docker ps | grep postgres`
- Verify port is 5433 (not 5432)

## Next Steps

1. **Push code** to main or create a PR
2. **Check GitHub Actions** for CI results
3. **Review coverage reports** in artifacts
4. **Fix any failures** and push again
5. **Merge when all checks pass** ✅

## Need Help?

See [CI_TESTING_GUIDE.md](CI_TESTING_GUIDE.md) for detailed documentation.
