from fastapi import APIRouter

from app.schemas.language import Language, LanguageListResponse

router = APIRouter(prefix="/languages", tags=["languages"])

# Supported languages list
SUPPORTED_LANGUAGES = [
    Language(
        code="en",
        name="English",
        nativeName="English"
    ),
    Language(
        code="vi",
        name="Vietnamese",
        nativeName="Tiếng Việt"
    ),
]


@router.get("", response_model=LanguageListResponse)
async def get_supported_languages() -> LanguageListResponse:
    """
    Get list of supported languages.
    
    This endpoint returns all languages supported by the system.
    Frontend can use this to populate language selection dropdowns.
    
    **Returns:**
    - `status`: Response status ("success")
    - `data`: List of languages with code, English name, and native name
    
    **Example Response:**
    ```json
    {
      "status": "success",
      "data": [
        {
          "code": "en",
          "name": "English",
          "nativeName": "English"
        },
        {
          "code": "vi",
          "name": "Vietnamese",
          "nativeName": "Tiếng Việt"
        }
      ]
    }
    ```
    """
    return LanguageListResponse(data=SUPPORTED_LANGUAGES)
