from fastapi import APIRouter

from app.api.v1.endpoints import health, auth, languages, translation, translate, images, users, audio, vocabulary, learning, sync


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
api_router.include_router(learning.router)
api_router.include_router(sync.router)
