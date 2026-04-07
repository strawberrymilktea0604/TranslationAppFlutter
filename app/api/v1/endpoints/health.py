from fastapi import APIRouter


router = APIRouter()


@router.get("/health")
async def health_check() -> dict[str, dict[str, str] | str]:
    return {"status": "success", "data": {"message": "ok"}}
