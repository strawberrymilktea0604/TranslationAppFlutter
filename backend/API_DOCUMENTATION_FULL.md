# TranslationApp API
**Version:** 1.0.0
**Base URL:** `/api/v1` (or relative to your environment)

Comprehensive documentation for the API.

---

## Authentication

Most endpoints require authentication using Bearer tokens.

### Getting a Token

Authenticate via the `/api/v1/auth/login` endpoint (or `/api/v1/auth/register` for new users).

### Using the Token

Include the token in the `Authorization` header for protected routes:

```
Authorization: Bearer YOUR_TOKEN
```

---

## Usage Guidelines

- **Format**: All data should be sent and received as JSON unless multipart/form-data is specified (e.g. for image uploads).

- **Pagination**: Use `skip` and `limit` query parameters on list endpoints.

- **Rate Limiting**: Check response headers or body for rate limit status (e.g., `rate_limit_remaining`). Guests have lower limits than authenticated users.

---

## Error Handling

The API returns standard HTTP status codes:

- `200 OK`: Successful request
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid input or missing parameters
- `401 Unauthorized`: Missing or invalid authentication token
- `403 Forbidden`: Authenticated but insufficient permissions
- `404 Not Found`: Resource not found
- `422 Unprocessable Entity`: Validation error in request body or parameters
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server-side error

Error responses generally follow this format:

```json
{
  "detail": "Error message description"
}
```

---

## Endpoints

### Health Endpoints

#### Health Check

**Endpoint:** `GET /api/v1/health`

**Responses:**
- `200`: Successful Response
  ```json
{
  }
  ```

**Example Request (cURL):**
```bash
curl -X GET https://api.example.com/api/v1/health \
```

#### Health Check Endpoint

Health check endpoint for monitoring

**Endpoint:** `GET /health`

**Responses:**
- `200`: Successful Response
  ```json

  ```

**Example Request (cURL):**
```bash
curl -X GET https://api.example.com/health \
```

### Auth Endpoints

#### Login

User login endpoint.

Returns access token and refresh token.
Refresh token is stored in database for tracking and revocation.

**Endpoint:** `POST /api/v1/auth/login`

**Request Body:**
Schema: `Body_login_api_v1_auth_login_post` (Content-Type: `application/x-www-form-urlencoded`)

**Responses:**
- `200`: Successful Response
  ```json
{
    "access_token": <string>, // Required
    "refresh_token": <string>, // Required
    "token_type": <string>, // Optional
    "expires_in": <integer> // Required: Access token expiration time in seconds
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/auth/login \
```

#### Check Email

Check if an email is already registered.
Returns is_available = True if email is NOT registered.

**Endpoint:** `POST /api/v1/auth/check-email`

**Request Body:**
```json
{
  "email": <string> // Required
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "is_available": <boolean> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/auth/check-email \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Register

User registration endpoint.

Creates new user and returns access token and refresh token.

**Endpoint:** `POST /api/v1/auth/register`

**Request Body:**
```json
{
  "email": <string>, // Required
  "first_name": <string>, // Required
  "last_name": <string>, // Required
  "avatar_url": <string>, // Optional
  "password": <string> // Required
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "access_token": <string>, // Required
    "refresh_token": <string>, // Required
    "token_type": <string>, // Optional
    "expires_in": <integer> // Required: Access token expiration time in seconds
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Refresh

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
```json
{
  "refresh_token": <string> // Required: Refresh token from login response
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "access_token": <string>, // Required
    "refresh_token": <string>, // Required
    "token_type": <string>, // Optional
    "expires_in": <integer> // Required: Access token expiration time in seconds
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Logout

User logout endpoint.

Revokes both access token and refresh token by:
1. Adding tokens to Redis blacklist (for fast O(1) checks)
2. Marking refresh token as revoked in database (for persistence)

- Only revokes current session (not all sessions)
- User must provide access token to authenticate the logout
- Both tokens are immediately blacklisted

**Endpoint:** `POST /api/v1/auth/logout`

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "access_token": <string>, // Required: Access token to validate logout request
  "refresh_token": <string> // Required: Refresh token to revoke
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "detail": <string> // Optional
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/auth/logout \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Logout All

Logout all sessions for current user (revoke all refresh tokens).

Use this if user suspects account compromise.
All active refresh tokens will be invalidated.
User must login again from all devices.

**Endpoint:** `POST /api/v1/auth/logout-all`

**Authentication:** Required (Bearer token)

**Responses:**
- `200`: Successful Response
  ```json

  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/auth/logout-all \
  -H "Authorization: Bearer YOUR_TOKEN" \
```

### Users Endpoints

#### Get Profile

Get current user profile.

**Endpoint:** `GET /api/v1/users/me`

**Authentication:** Required (Bearer token)

**Responses:**
- `200`: Successful Response
  ```json
{
    "email": <string>, // Required
    "first_name": <string>, // Optional
    "last_name": <string>, // Optional
    "avatar_url": <string>, // Optional
    "id": <integer>, // Required
    "role": <string>, // Required
    "status": <string>, // Required
    "created_at": <string>, // Required
    "updated_at": <string> // Required
  }
  ```

**Example Request (cURL):**
```bash
curl -X GET https://api.example.com/api/v1/users/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
```

#### Update Profile

Update current user profile.

**Endpoint:** `PATCH /api/v1/users/me`

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "first_name": <string>, // Optional
  "last_name": <string>, // Optional
  "avatar_url": <string> // Optional
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "email": <string>, // Required
    "first_name": <string>, // Optional
    "last_name": <string>, // Optional
    "avatar_url": <string>, // Optional
    "id": <integer>, // Required
    "role": <string>, // Required
    "status": <string>, // Required
    "created_at": <string>, // Required
    "updated_at": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X PATCH https://api.example.com/api/v1/users/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Update Password

Update current user password.

**Endpoint:** `PATCH /api/v1/users/me/password`

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "old_password": <string>, // Required
  "new_password": <string> // Required
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "email": <string>, // Required
    "first_name": <string>, // Optional
    "last_name": <string>, // Optional
    "avatar_url": <string>, // Optional
    "id": <integer>, // Required
    "role": <string>, // Required
    "status": <string>, // Required
    "created_at": <string>, // Required
    "updated_at": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X PATCH https://api.example.com/api/v1/users/me/password \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Upload Avatar

Upload and update user avatar.

**Endpoint:** `POST /api/v1/users/me/avatar`

**Authentication:** Required (Bearer token)

**Request Body:**
Schema: `Body_upload_avatar_api_v1_users_me_avatar_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
  ```json
{
    "avatar_url": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/users/me/avatar \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F 'file=@/path/to/file.jpg'
```

#### Get Avatar

Get user avatar image.

**Endpoint:** `GET /api/v1/users/avatar/{filename}`

**Parameters:**
- `filename` (path): Required. 

**Responses:**
- `200`: Successful Response
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X GET https://api.example.com/api/v1/users/avatar/{filename} \
```

### Languages Endpoints

#### Get Supported Languages

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
  ```json
{
    "status": <string>, // Optional: Response status
    "data": <array of objects> // Required: List of supported languages
  }
  ```

**Example Request (cURL):**
```bash
curl -X GET https://api.example.com/api/v1/languages \
```

### Translations Endpoints

#### Translate Text

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

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "source_text": <string>, // Required: Text to translate (max 5000 chars)
  "source_language": <string>, // Required: Source language code (e.g., 'en', 'vi')
  "target_language": <string>, // Required: Target language code (e.g., 'en', 'vi')
  "translation_type": <string> // Optional: Type of translation: 'text', 'voice', 'image'
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/translations \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Get Translation History

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

**Authentication:** Required (Bearer token)

**Parameters:**
- `skip` (query): Optional. Number of records to skip
- `limit` (query): Optional. Maximum records per page

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <array of objects>, // Required
    "total": <integer> // Optional: Total translations count
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X GET https://api.example.com/api/v1/translations/history \
  -H "Authorization: Bearer YOUR_TOKEN" \
```

#### Delete Translation

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

**Authentication:** Required (Bearer token)

**Parameters:**
- `translation_id` (path): Required. 

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X DELETE https://api.example.com/api/v1/translations/{translation_id} \
  -H "Authorization: Bearer YOUR_TOKEN" \
```

#### Get Cache Stats

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

**Authentication:** Required (Bearer token)

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```

**Example Request (cURL):**
```bash
curl -X GET https://api.example.com/api/v1/translations/cache/stats \
  -H "Authorization: Bearer YOUR_TOKEN" \
```

#### Clear Translation Cache

Clear all translation cache (admin only).

**Warning:** This clears the entire Redis translation cache.
Use sparingly - will cause a cache warmup period.

Returns:
    SuccessResponse with cache clear status

**Endpoint:** `POST /api/v1/translations/cache/clear`

**Authentication:** Required (Bearer token)

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/translations/cache/clear \
  -H "Authorization: Bearer YOUR_TOKEN" \
```

### Translate Endpoints

#### Translate plain text

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

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "text": <string>, // Required: Text to translate (max length depends on Guest/User role)
  "source_language": <string>, // Required: Source language code (ISO 639-1, e.g., 'en', 'vi', 'auto' for auto-detect)
  "target_language": <string> // Required: Target language code (ISO 639-1, e.g., 'vi', 'en', 'ja')
}
```

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/translate/text \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```

#### Translate text from an uploaded image

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

**Authentication:** Required (Bearer token)

**Request Body:**
Schema: `Body_translate_image_api_v1_translate_image_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/translate/image \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F 'file=@/path/to/file.jpg'
```

### Images Endpoints

#### Translate Image

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

**Authentication:** Required (Bearer token)

**Request Body:**
Schema: `Body_translate_image_api_v1_images_translate_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/images/translate \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F 'file=@/path/to/file.jpg'
```

#### Translate Images Batch

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

**Authentication:** Required (Bearer token)

**Request Body:**
Schema: `Body_translate_images_batch_api_v1_images_translate_batch_post` (Content-Type: `multipart/form-data`)

**Responses:**
- `200`: Successful Response
  ```json
{
    "status": <string>, // Optional
    "data": <string> // Required
  }
  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/v1/images/translate/batch \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F 'file=@/path/to/file.jpg'
```

### Ai quotas Endpoints

#### Create User Quota

**Endpoint:** `POST /api/quotas/`

**Authentication:** Required (Bearer token)

**Request Body:**
```json
{
  "service_type": <string>, // Required: Loại dịch vụ, VD: 'text_translation', 'voice_stt'
  "max_requests": <integer>, // Optional: Hạn mức tối đa, không được âm
  "user_id": <integer> // Required: ID của người dùng được cấp hạn mức
}
```

**Responses:**
- `201`: Successful Response
  ```json

  ```
- `422`: Validation Error
  ```json
{
    "detail": <array of objects> // Optional
  }
  ```

**Example Request (cURL):**
```bash
curl -X POST https://api.example.com/api/quotas/ \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{ ... }'
```
