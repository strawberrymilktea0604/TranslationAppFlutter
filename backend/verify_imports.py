import sys
sys.path.insert(0, '.')
try:
    from app.schemas.admin import QuestionBankCreate, QuestionBankUpdate, QuestionBankToggleResponse
    print('✅ Schemas OK: QuestionBankCreate, QuestionBankUpdate, QuestionBankToggleResponse')
    from app.api.v1.endpoints.admin import router
    routes = [r.path for r in router.routes]
    print(f'✅ Admin router loaded with {len(routes)} routes:')
    for r in routes:
        print(f'   {r}')
except Exception as e:
    print(f'❌ Import error: {e}')
    import traceback
    traceback.print_exc()
