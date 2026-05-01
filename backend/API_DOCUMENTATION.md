# TranslationApp API
**Version:** 1.0.0

## Authentication
Most endpoints require a Bearer token. Include it in the Authorization header:

```
Authorization: Bearer YOUR_TOKEN
```


## Health Endpoints

### Health Check
**Endpoint:** `GET /api/v1/health`

**Responses:**
- `200`: Successful Response

### Health Check Endpoint
Health check endpoint for monitoring

**Endpoint:** `GET /health`

**Responses:**
- `200`: Successful Response


## Auth Endpoints

### Login
User login endpoint.

Returns access token and refresh token.
Refresh token is stored in database for tracking and revocation.

**Endpoint:** `POST /api/v1/auth/login`

**Request Body:**
Schema: `Body_login_api_v1_auth_login_post` (Content-Type: `application/x-www-form-urlencoded`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Check Email
Check if an email is already registered.
Returns is_available = True if email is NOT registered.

**Endpoint:** `POST /api/v1/auth/check-email`

**Request Body:**
Schema: `EmailCheckRequest` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Register
User registration endpoint.

Creates new user and returns access token and refresh token.

**Endpoint:** `POST /api/v1/auth/register`

**Request Body:**
Schema: `UserCreate` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Refresh
Refresh access token using refresh token.

- Validates refresh token
- Invalidates old refresh token (single-use enforcement)
- Issues new access token and refresh token

This implements the single-use refresh token pattern:
- Old refresh token is marked as revoked in both Redis and DB
- New refresh token must be used for next refresh
- Prevents token replay attacks

**Endpoint:** `POST /api/v1/auth/refresh`

**Request Body:**
Schema: `RefreshTokenRequest` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Logout
User logout endpoint.

Revokes both access token and refresh token by:
1. Adding tokens to Redis blacklist (for fast O(1) checks)
2. Marking refresh token as revoked in database (for persistence)

- Only revokes current session (not all sessions)
- User must provide access token to authenticate the logout
- Both tokens are immediately blacklisted

**Endpoint:** `POST /api/v1/auth/logout`

**Request Body:**
Schema: `LogoutRequest` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Logout All
Logout all sessions for current user (revoke all refresh tokens).

Use this if user suspects account compromise.
All active refresh tokens will be invalidated.
User must login again from all devices.

**Endpoint:** `POST /api/v1/auth/logout-all`

**Responses:**
- `200`: Successful Response


## Users Endpoints

### Get Profile
Get current user profile.

**Endpoint:** `GET /api/v1/users/me`

**Responses:**
- `200`: Successful Response

### Update Profile
Update current user profile.

**Endpoint:** `PATCH /api/v1/users/me`

**Request Body:**
Schema: `UserUpdate` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Update Password
Update current user password.

**Endpoint:** `PATCH /api/v1/users/me/password`

**Request Body:**
Schema: `UserPasswordUpdate` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Upload Avatar
Upload and update user avatar.

**Endpoint:** `POST /api/v1/users/me/avatar`

**Request Body:**
Schema: `Body_upload_avatar_api_v1_users_me_avatar_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Get Avatar
Get user avatar image.

**Endpoint:** `GET /api/v1/users/avatar/{filename}`

**Parameters:**
- `filename` (path): Required. 

**Responses:**
- `200`: Successful Response
- `422`: Validation Error


## Languages Endpoints

### Get Supported Languages
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

**Endpoint:** `GET /api/v1/languages`

**Responses:**
- `200`: Successful Response


## Translations Endpoints

### Translate Text
Translate text with caching optimization.

**Features:**
- ✅ Redis caching: Check cache before API call (< 500ms)
- ✅ DB fallback: Saves to DB for history and cold-cache warmup
- ✅ Cost optimization: Avoids redundant API calls

**Process:**
1. Check Redis cache (< 50ms if hit)
2. If cache miss: Call translation API
3. Store result in Redis (1 hour TTL) and database

**Example Request:**
```json
{
  "source_text": "Hello, how are you?",
  "source_language": "en",
  "target_language": "vi",
  "translation_type": "text"
}
```

**Example Response (Cache Hit):**
```json
{
  "status": "success",
  "data": {
    "translated_text": "Xin chào, bạn khỏe không?",
    "is_cached": true,
    "response_time_ms": 15.5
  }
}
```

**Response Time Goals:**
- Cache hit: < 50ms
- Total with DB save: < 500ms (even if API call takes 3-5 seconds)

Args:
    request: Translation request containing source text and language pair
    db: Database session
    current_user: Current authenticated user

Returns:
    SuccessResponse with translated text and cache status

Raises:
    HTTPException: 400 if invalid language pair
    HTTPException: 500 if translation service fails

**Endpoint:** `POST /api/v1/translations`

**Request Body:**
Schema: `TranslationRequest` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Get Translation History
Get user's translation history.

**Features:**
- Paginated results (max 100 per page)
- Sorted by most recent first
- Shows cache status for each translation

**Query Parameters:**
- `skip`: Number of records to skip (for pagination)
- `limit`: Maximum records to return (1-100, default 50)

**Example Response:**
```json
{
  "status": "success",
  "data": [
    {
      "id": 1001,
      "source_text": "Hello",
      "translated_text": "Xin chào",
      "source_language": "en",
      "target_language": "vi",
      "translation_type": "text",
      "is_cached": false,
      "created_at": "2024-01-15T10:30:00Z"
    }
  ],
  "total": 42
}
```

Args:
    skip: Pagination offset
    limit: Max records to return
    db: Database session
    current_user: Current authenticated user

Returns:
    TranslationListResponse with user's translation history

**Endpoint:** `GET /api/v1/translations/history`

**Parameters:**
- `skip` (query): Optional. Number of records to skip
- `limit` (query): Optional. Maximum records per page

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Delete Translation
Delete a translation from user's history.

Performs soft delete (marks as deleted, keeps data for analytics).

Args:
    translation_id: ID of translation to delete
    db: Database session
    current_user: Current authenticated user

Returns:
    SuccessResponse with deletion status

Raises:
    HTTPException: 404 if translation not found or user unauthorized

**Endpoint:** `DELETE /api/v1/translations/{translation_id}`

**Parameters:**
- `translation_id` (path): Required. 

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Get Cache Stats
Get translation cache statistics (admin only).

**Features:**
- Cache hit rate
- Number of cached translations
- Memory usage
- Expiry information

This endpoint helps monitor cache effectiveness and optimization.

Returns:
    SuccessResponse with cache statistics

**Endpoint:** `GET /api/v1/translations/cache/stats`

**Responses:**
- `200`: Successful Response

### Clear Translation Cache
Clear all translation cache (admin only).

**Warning:** This clears the entire Redis translation cache.
Use sparingly - will cause a cache warmup period.

Returns:
    SuccessResponse with cache clear status

**Endpoint:** `POST /api/v1/translations/cache/clear`

**Responses:**
- `200`: Successful Response


## Translate Endpoints

### Translate plain text
Translate a text passage from source language to target language.

**Access Control:**
- ✅ **Guest** (no token): Allowed with limits (10 req/hour, max 500 chars)
- ✅ **User** (Bearer token): Higher limits (100 req/hour, max 5000 chars)

**Rate Limiting:**
- Guest: tracked by IP address
- User: tracked by user ID

**Features:**
- Redis caching for fast repeated queries
- Google Translation API v2 backend
- Auto language detection (`source_language: "auto"`)

**Example Request:**
```json
{
    "text": "Hello, how are you?",
    "source_language": "en",
    "target_language": "vi"
}
```

**Example Response:**
```json
{
    "status": "success",
    "data": {
        "translated_text": "Xin chào, bạn khỏe không?",
        "source_text": "Hello, how are you?",
        "source_language": "en",
        "target_language": "vi",
        "is_cached": false,
        "response_time_ms": 245.3,
        "role": "guest",
        "rate_limit_remaining": 9
    }
}
```

**Endpoint:** `POST /api/v1/translate/text`

**Request Body:**
Schema: `TranslateTextRequest` (Content-Type: `application/json`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Translate text from an uploaded image
Upload an image, extract text via OCR, and translate it.

**Image Preprocessing Pipeline (OpenCV):**
1. 🔄 Auto-rotate based on EXIF orientation (phone camera correction)
2. ⬛ Convert to grayscale
3. 🔲 Enhance contrast (CLAHE - Contrast Limited Adaptive Histogram Equalisation)
4. 🧹 Denoise (fastNlMeansDenoising)

**Access Control:**
- ✅ **Guest** (no token): 10 req/hour
- ✅ **User** (Bearer token): 100 req/hour

**Supported Formats:** PNG, JPG/JPEG, BMP, TIFF, GIF (max 10 MB)

**Request:**
```
POST /api/v1/translate/image
Content-Type: multipart/form-data

- file: Image file (required)
- source_language: "en", "vi", "fr", etc. (default: "en")
- target_language: "vi", "en", etc. (required)
```

**Example Response:**
```json
{
    "status": "success",
    "data": {
        "source_text": "Hello, how are you?",
        "translated_text": "Xin chào, bạn khỏe không?",
        "source_language": "en",
        "target_language": "vi",
        "ocr_confidence": 92.5,
        "is_cached": false,
        "response_time_ms": 1250.5,
        "preprocessing_time_ms": 45.2,
        "ocr_time_ms": 980.0,
        "translation_time_ms": 225.3,
        "role": "guest",
        "rate_limit_remaining": 9
    }
}
```

**Endpoint:** `POST /api/v1/translate/image`

**Request Body:**
Schema: `Body_translate_image_api_v1_translate_image_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error


## Images Endpoints

### Translate Image
Translate image endpoint - Complete image translation pipeline.

**Pipeline:**
1. 📥 Upload image (PNG, JPG, etc.)
2. ✅ Validate and optimize image (in RAM)
3. 👁️ Extract text via OCR/Tesseract
4. 🔄 Translate extracted text (with Redis cache)
5. ✔️ Return original text + translated text

**Important:**
- ✅ ALL processing in RAM - no temporary files on disk
- ✅ Automatic memory cleanup after response
- ✅ Supports 20+ languages
- ✅ Confidence scores for both OCR and translation

**Request:**
```
POST /api/v1/images/translate
Content-Type: multipart/form-data

Parameters:
- file: Image file (required)
- source_language: "en", "vi", "fr", etc. (default: "en")
- target_language: "en", "vi", "fr", etc. (required)
- optimize_image: true/false (default: true)
- return_regions: true/false (default: false, includes bounding boxes)
```

**Example Response:**
```json
{
  "status": "success",
  "data": {
    "source_text": "Hello, how are you?",
    "translated_text": "Xin chào, bạn khỏe không?",
    "source_language": "en",
    "target_language": "vi",
    "ocr_confidence": 92.5,
    "is_cached": false,
    "response_time_ms": 1250.5,
    "translation_type": "image"
  }
}
```

**Response Times:**
- Image validation: 5-10ms
- Image optimization: 20-50ms
- OCR: 800-2000ms (depends on image complexity)
- Translation (cache hit): 20-50ms
- Translation (API call): 2000-5000ms
- **Total: 1-7 seconds**

**File Storage:**
- ✅ Zero disk writes - only RAM
- ✅ Automatic garbage collection
- ✅ Safe for high-concurrency servers

**Endpoint:** `POST /api/v1/images/translate`

**Request Body:**
Schema: `Body_translate_image_api_v1_images_translate_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error

### Translate Images Batch
Batch translate multiple images.

**Process:**
- Upload multiple images at once
- Each image is processed independently
- Parallel processing where possible
- Returns array of results with success/failure status

**Request:**
```
POST /api/v1/images/translate/batch
Content-Type: multipart/form-data

- files: Multiple image files (required)
- source_language: "en", "vi", etc.
- target_language: "vi", "en", etc.
```

**Response:**
```json
{
  "status": "success",
  "data": {
    "total": 3,
    "successful": 2,
    "failed": 1,
    "results": [
      {
        "source_text": "Hello",
        "translated_text": "Xin chào",
        ...
      }
    ],
    "errors": [
      {"file_index": 2, "error": "OCR failed: ..."}
    ]
  }
}
```

**Endpoint:** `POST /api/v1/images/translate/batch`

**Request Body:**
Schema: `Body_translate_images_batch_api_v1_images_translate_batch_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
- `422`: Validation Error


## Ai quotas Endpoints

### Create User Quota
**Endpoint:** `POST /api/quotas/`

**Request Body:**
Schema: `QuotaCreate` (Content-Type: `application/json`)

**Responses:**
- `201`: Successful Response
- `422`: Validation Error
