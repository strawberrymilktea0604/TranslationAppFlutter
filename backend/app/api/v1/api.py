from fastapi import APIRouter

from app.api.v1.endpoints import (
    admin,
    audio,
    auth,
    health,
    images,
    languages,
    learning,
    sync,
    translate,
    translation,
    users,
    vocabulary,
    vocabulary_categories,
    websocket,
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(languages.router)
api_router.include_router(translation.router)
api_router.include_router(translate.router)
api_router.include_router(images.router)
api_router.include_router(audio.router)
api_router.include_router(vocabulary.router)
api_router.include_router(vocabulary_categories.router)
api_router.include_router(learning.router)
api_router.include_router(sync.router)
api_router.include_router(websocket.router)
api_router.include_router(admin.router)
