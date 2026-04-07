from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.user import UserCreate


class UserService:
    def __init__(self, user_repository: UserRepository):
        self.user_repository = user_repository

    async def create_user(self, payload: UserCreate) -> User:
        # Password hashing should be implemented before storing user credentials.
        user = User(email=payload.email, hashed_password=payload.password)
        return await self.user_repository.create(user)
