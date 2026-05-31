# Quick Start - Image Translation Pipeline

## 🚀 5 Phút Setup

### 1. Install Dependencies

```bash
# Backend
cd backend
pip install -r requirements.txt

# System (Ubuntu/Debian)
sudo apt-get install -y tesseract-ocr

# Or Docker (recommended)
docker-compose up --build
```

### 2. Start Server

```bash
# Local development
cd backend
uvicorn app.main:app --reload

# Or Docker
docker-compose up
```

### 3. Test Endpoint

```bash
# Single image
curl -X POST http://localhost:8000/api/v1/images/translate \
  -F "file=@/path/to/image.jpg" \
  -F "source_language=en" \
  -F "target_language=vi"

# Response
{
  "status": "success",
  "data": {
    "source_text": "Hello World",
    "translated_text": "Xin chào Thế giới",
    "ocr_confidence": 92.5,
    "is_cached": false,
    "response_time_ms": 1250.5
  }
}
```

---

## 📱 Frontend Integration (Flutter)

### Example Code

```dart
// lib/features/image_translation/services/image_translation_service.dart

import 'package:http/http.dart' as http;
import 'dart:io';

class ImageTranslationService {
  static const String baseUrl = 'http://localhost:8000/api/v1';

  static Future<Map<String, dynamic>> translateImage({
    required File imageFile,
    required String sourceLanguage,
    required String targetLanguage,
    bool optimizeImage = true,
    bool returnRegions = false,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/images/translate'),
    );

    // Add file
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    // Add parameters
    request.fields['source_language'] = sourceLanguage;
    request.fields['target_language'] = targetLanguage;
    request.fields['optimize_image'] = optimizeImage.toString();
    request.fields['return_regions'] = returnRegions.toString();

    // Add auth token
    var token = await getAuthToken();
    request.headers['Authorization'] = 'Bearer $token';

    // Send
    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonData = jsonDecode(responseData);

    if (response.statusCode == 200) {
      return jsonData['data'];
    } else {
      throw Exception('Image translation failed: ${jsonData['detail']}');
    }
  }

  static Future<List<Map<String, dynamic>>> translateImagesBatch({
    required List<File> imageFiles,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/images/translate/batch'),
    );

    // Add multiple files
    for (var file in imageFiles) {
      request.files.add(
        await http.MultipartFile.fromPath('files', file.path),
      );
    }

    request.fields['source_language'] = sourceLanguage;
    request.fields['target_language'] = targetLanguage;

    var token = await getAuthToken();
    request.headers['Authorization'] = 'Bearer $token';

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonData = jsonDecode(responseData);

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonData['data']['results']);
    } else {
      throw Exception('Batch translation failed');
    }
  }
}
```

### Usage in UI

```dart
// lib/features/image_translation/screens/image_translation_screen.dart

class ImageTranslationScreen extends StatefulWidget {
  @override
  State<ImageTranslationScreen> createState() => _ImageTranslationScreenState();
}

class _ImageTranslationScreenState extends State<ImageTranslationScreen> {
  bool _isTranslating = false;
  String? _sourceText;
  String? _translatedText;
  double? _ocrConfidence;
  double? _responseTime;

  Future<void> _selectAndTranslateImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isTranslating = true);

      try {
        final result = await ImageTranslationService.translateImage(
          imageFile: File(pickedFile.path),
          sourceLanguage: 'en',
          targetLanguage: 'vi',
          returnRegions: true,
        );

        setState(() {
          _sourceText = result['source_text'];
          _translatedText = result['translated_text'];
          _ocrConfidence = result['ocr_confidence'];
          _responseTime = result['response_time_ms'];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation successful!'))
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      } finally {
        setState(() => _isTranslating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Translation')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.image),
                label: Text('Select Image'),
                onPressed: _isTranslating ? null : _selectAndTranslateImage,
              ),
              SizedBox(height: 20),
              if (_isTranslating)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Translating image...'),
                  ],
                )
              else if (_sourceText != null) ...[
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Source Text:',
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: 8),
                        Text(_sourceText!),
                        SizedBox(height: 16),
                        Text('Translated Text:',
                            style: Theme.of(context).textTheme.titleMedium),
                        SizedBox(height: 8),
                        Text(_translatedText!),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'OCR Confidence: ${_ocrConfidence?.toStringAsFixed(1)}%',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Response: ${_responseTime?.toStringAsFixed(0)}ms',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 🔧 Troubleshooting

### Error: "pytesseract.TesseractNotFoundError"

```bash
# Install Tesseract
sudo apt-get install tesseract-ocr

# Or use Docker (no setup needed)
docker-compose up --build
```

### Error: "No module named cv2"

```bash
pip install opencv-python==4.9.0.80
```

### Slow OCR (> 10s)

**Enable image preprocessing:**
```python
ocr_result = await OCRService.extract_text(
    image_bytes,
    preprocess=True  # This reduces processing time!
)
```

**Or optimize image first:**
```python
image_bytes = await ImageService.optimize_image(
    image_bytes,
    max_width=1024,
    max_height=1024,
    quality=85
)
```

### Out of Memory

```bash
# Check memory usage
docker stats backend

# Increase Docker memory limit
# In docker-compose.yml:
services:
  backend:
    mem_limit: 1g  # Increase from default
```

---

## 📊 Performance Tips

### 1. Enable Image Optimization (default: true)

```python
# Reduces image by 30-50%, improves OCR by 15-30%
optimize_image=True
```

### 2. Use Batch Processing for Multiple Images

```bash
# Better than multiple single requests
curl -X POST http://localhost:8000/api/v1/images/translate/batch \
  -F "files=@image1.jpg" \
  -F "files=@image2.jpg" \
  -F "files=@image3.jpg" \
  -F "target_language=vi"
```

### 3. Cache Translation Results

- Redis caching enabled by default
- Same text + language pair → 20ms response
- Check `is_cached` field in response

### 4. Supported Languages

```python
# OCR works best with these
'en', 'vi', 'fr', 'de', 'es', 'pt', 'zh', 'ja', 'ko', 'ru', 'ar', 'th'
```

---

## 📈 Response Times

```
Request Flow                          Time Range
─────────────────────────────────────────────────
Upload + Validation                   5-20ms
Image Optimization                    20-50ms
OCR Extraction (main bottleneck)     800-2000ms
Translation (cache hit)               20-50ms
Translation (new, API call)          2000-5000ms
Response Building                     5-10ms
─────────────────────────────────────────────────

TOTAL (cache hit):      850-2100ms   (~1-2 seconds)
TOTAL (API call):      2800-7100ms   (~3-7 seconds)
```

---

## 🎯 Key Features

✅ **No Temporary Files** - All processing in RAM
✅ **Rate Limiting** - 100 req/hr (auth), 10 req/hr (guest)
✅ **Batch Processing** - Translate 10 images at once
✅ **Text Regions** - Get bounding boxes of extracted text
✅ **Confidence Scores** - Know how accurate OCR is
✅ **Cache Status** - See if result came from cache
✅ **20+ Languages** - English, Vietnamese, French, German, etc.
✅ **Error Handling** - Graceful fallback on failures

---

**Next Steps**: Check [IMAGE_TRANSLATION_IMPLEMENTATION.md](IMAGE_TRANSLATION_IMPLEMENTATION.md) for detailed documentation
