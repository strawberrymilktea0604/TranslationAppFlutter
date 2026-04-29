# API Integration Examples

## cURL Examples

### 1. Single Image Translation (English → Vietnamese)

```bash
curl -X POST http://localhost:8000/api/v1/images/translate \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@photo.jpg" \
  -F "source_language=en" \
  -F "target_language=vi" \
  -F "optimize_image=true" \
  -F "return_regions=true"
```

### 2. Batch Image Translation

```bash
curl -X POST http://localhost:8000/api/v1/images/translate/batch \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "files=@image1.jpg" \
  -F "files=@image2.jpg" \
  -F "files=@image3.jpg" \
  -F "source_language=en" \
  -F "target_language=vi"
```

### 3. Guest User (No Authentication)

```bash
curl -X POST http://localhost:8000/api/v1/images/translate \
  -F "file=@image.jpg" \
  -F "source_language=en" \
  -F "target_language=vi"
  
# Note: Guest users limited to 10 requests/hour
```

---

## Python Client Example

```python
import requests
from pathlib import Path

class ImageTranslationClient:
    def __init__(self, base_url='http://localhost:8000/api/v1', token=None):
        self.base_url = base_url
        self.headers = {}
        if token:
            self.headers['Authorization'] = f'Bearer {token}'
    
    def translate_image(self, image_path, source_lang='en', target_lang='vi'):
        """Translate single image"""
        url = f'{self.base_url}/images/translate'
        
        with open(image_path, 'rb') as f:
            files = {'file': f}
            data = {
                'source_language': source_lang,
                'target_language': target_lang,
                'optimize_image': 'true',
                'return_regions': 'false'
            }
            
            response = requests.post(url, files=files, data=data, headers=self.headers)
        
        return response.json()
    
    def translate_batch(self, image_paths, source_lang='en', target_lang='vi'):
        """Translate multiple images"""
        url = f'{self.base_url}/images/translate/batch'
        
        files = []
        for path in image_paths:
            files.append(('files', open(path, 'rb')))
        
        data = {
            'source_language': source_lang,
            'target_language': target_lang,
        }
        
        response = requests.post(url, files=files, data=data, headers=self.headers)
        
        # Close all opened files
        for _, file in files:
            file.close()
        
        return response.json()


# Usage
client = ImageTranslationClient(token='your_jwt_token')

# Single image
result = client.translate_image('photo.jpg', source_lang='en', target_lang='vi')
print(f"Source: {result['data']['source_text']}")
print(f"Translated: {result['data']['translated_text']}")
print(f"Confidence: {result['data']['ocr_confidence']}%")
print(f"Response time: {result['data']['response_time_ms']}ms")

# Batch
results = client.translate_batch(
    ['img1.jpg', 'img2.jpg', 'img3.jpg'],
    source_lang='en',
    target_lang='vi'
)
print(f"Successful: {results['data']['successful']}/{results['data']['total']}")
```

---

## JavaScript/Node.js Example

```javascript
const FormData = require('form-data');
const fs = require('fs');
const axios = require('axios');

class ImageTranslationClient {
  constructor(baseUrl = 'http://localhost:8000/api/v1', token = null) {
    this.baseUrl = baseUrl;
    this.headers = token ? { 'Authorization': `Bearer ${token}` } : {};
  }

  async translateImage(imagePath, sourceLang = 'en', targetLang = 'vi') {
    const url = `${this.baseUrl}/images/translate`;
    const form = new FormData();
    
    form.append('file', fs.createReadStream(imagePath));
    form.append('source_language', sourceLang);
    form.append('target_language', targetLang);
    form.append('optimize_image', 'true');
    form.append('return_regions', 'false');

    try {
      const response = await axios.post(url, form, {
        headers: { ...this.headers, ...form.getHeaders() },
      });
      return response.data;
    } catch (error) {
      throw new Error(`Translation failed: ${error.response?.data?.detail}`);
    }
  }

  async translateBatch(imagePaths, sourceLang = 'en', targetLang = 'vi') {
    const url = `${this.baseUrl}/images/translate/batch`;
    const form = new FormData();
    
    imagePaths.forEach(path => {
      form.append('files', fs.createReadStream(path));
    });
    
    form.append('source_language', sourceLang);
    form.append('target_language', targetLang);

    try {
      const response = await axios.post(url, form, {
        headers: { ...this.headers, ...form.getHeaders() },
      });
      return response.data;
    } catch (error) {
      throw new Error(`Batch translation failed: ${error.response?.data?.detail}`);
    }
  }
}

// Usage
(async () => {
  const client = new ImageTranslationClient(undefined, 'your_jwt_token');
  
  // Single image
  const result = await client.translateImage('photo.jpg', 'en', 'vi');
  console.log('Source:', result.data.source_text);
  console.log('Translated:', result.data.translated_text);
  console.log('Confidence:', result.data.ocr_confidence + '%');
  
  // Batch
  const batchResult = await client.translateBatch(
    ['img1.jpg', 'img2.jpg'],
    'en',
    'vi'
  );
  console.log(`Successful: ${batchResult.data.successful}/${batchResult.data.total}`);
})();
```

---

## React Component Example

```javascript
// ImageTranslator.jsx
import React, { useState } from 'react';
import axios from 'axios';

export function ImageTranslator() {
  const [image, setImage] = useState(null);
  const [preview, setPreview] = useState(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);

  const handleImageSelect = (e) => {
    const file = e.target.files[0];
    setImage(file);
    setPreview(URL.createObjectURL(file));
  };

  const handleTranslate = async (sourceLang, targetLang) => {
    if (!image) return;

    setLoading(true);
    setError(null);
    setResult(null);

    try {
      const formData = new FormData();
      formData.append('file', image);
      formData.append('source_language', sourceLang);
      formData.append('target_language', targetLang);
      formData.append('optimize_image', 'true');
      formData.append('return_regions', 'true');

      const response = await axios.post(
        'http://localhost:8000/api/v1/images/translate',
        formData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
            'Authorization': `Bearer ${localStorage.getItem('token')}`,
          },
        }
      );

      setResult(response.data.data);
    } catch (err) {
      setError(err.response?.data?.detail || 'Translation failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="translator">
      <h2>Image Translator</h2>

      {/* Image Upload */}
      <div className="upload-section">
        <input
          type="file"
          accept="image/*"
          onChange={handleImageSelect}
          disabled={loading}
        />
        {preview && (
          <img
            src={preview}
            alt="Preview"
            style={{ maxWidth: '400px', marginTop: '10px' }}
          />
        )}
      </div>

      {/* Language Selection */}
      <div className="controls">
        <select id="source-lang" defaultValue="en">
          <option value="en">English</option>
          <option value="vi">Vietnamese</option>
          <option value="fr">French</option>
        </select>
        <span> → </span>
        <select id="target-lang" defaultValue="vi">
          <option value="en">English</option>
          <option value="vi">Vietnamese</option>
          <option value="fr">French</option>
        </select>
        <button
          onClick={() => {
            const source = document.getElementById('source-lang').value;
            const target = document.getElementById('target-lang').value;
            handleTranslate(source, target);
          }}
          disabled={!image || loading}
        >
          {loading ? 'Translating...' : 'Translate'}
        </button>
      </div>

      {/* Results */}
      {result && (
        <div className="results">
          <h3>Results</h3>
          <div className="result-item">
            <strong>Source Text:</strong>
            <p>{result.source_text}</p>
          </div>
          <div className="result-item">
            <strong>Translated Text:</strong>
            <p>{result.translated_text}</p>
          </div>
          <div className="metrics">
            <span>OCR Confidence: {result.ocr_confidence.toFixed(1)}%</span>
            <span>Time: {result.response_time_ms.toFixed(0)}ms</span>
            <span>Cache: {result.is_cached ? 'HIT' : 'MISS'}</span>
          </div>

          {result.text_regions && result.text_regions.length > 0 && (
            <div className="regions">
              <h4>Detected Regions:</h4>
              {result.text_regions.map((region, idx) => (
                <div key={idx} className="region">
                  <span>{region.text}</span>
                  <span className="confidence">{region.confidence}%</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Error */}
      {error && <div className="error">{error}</div>}
    </div>
  );
}
```

---

## Request/Response Reference

### Single Image Request

```
POST /api/v1/images/translate HTTP/1.1
Host: localhost:8000
Authorization: Bearer eyJhbGc...
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary

------WebKitFormBoundary
Content-Disposition: form-data; name="file"; filename="photo.jpg"
Content-Type: image/jpeg

[binary image data]
------WebKitFormBoundary
Content-Disposition: form-data; name="source_language"

en
------WebKitFormBoundary
Content-Disposition: form-data; name="target_language"

vi
------WebKitFormBoundary
Content-Disposition: form-data; name="optimize_image"

true
------WebKitFormBoundary
Content-Disposition: form-data; name="return_regions"

true
------WebKitFormBoundary--
```

### Single Image Response (200 OK)

```json
{
  "status": "success",
  "data": {
    "source_text": "Hello, how are you?",
    "translated_text": "Xin chào, bạn khỏe không?",
    "source_language": "en",
    "target_language": "vi",
    "ocr_confidence": 92.5,
    "text_regions": [
      {
        "text": "Hello",
        "confidence": 95,
        "bbox": {
          "x": 10,
          "y": 10,
          "width": 50,
          "height": 20
        }
      },
      {
        "text": "how",
        "confidence": 92,
        "bbox": {
          "x": 70,
          "y": 10,
          "width": 40,
          "height": 20
        }
      }
    ],
    "is_cached": false,
    "response_time_ms": 1250.5,
    "image_metadata": null,
    "translation_type": "image"
  }
}
```

### Error Response (400 Bad Request)

```json
{
  "detail": "Invalid image: Image exceeds 10MB limit"
}
```

### Batch Response

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
      },
      {
        "source_text": "World",
        "translated_text": "Thế giới",
        ...
      }
    ],
    "errors": [
      {
        "file_index": 2,
        "error": "OCR failed: No text detected"
      }
    ]
  }
}
```

---

## Rate Limiting

### Headers in Response

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1715684400
```

### Rate Limit Exceeded (429)

```json
{
  "detail": "Rate limit exceeded. Reset in 3600s"
}
```

### Limits

| User Type | Limit | Window |
|-----------|-------|--------|
| Authenticated | 100 req/hour | Sliding |
| Guest | 10 req/hour | Sliding |
| Batch (auth) | 5 ops/hour | Sliding |

---

## Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Bad Request (invalid image, missing fields) |
| 401 | Unauthorized (missing/invalid token) |
| 422 | Unprocessable (no text extracted from image) |
| 429 | Too Many Requests (rate limit exceeded) |
| 500 | Internal Server Error (OCR/translation service failed) |

---

**Last Updated**: April 2024
