# Voice Translation API - Quick Start Guide

## For Backend Developers

### 1. Install Dependencies

```bash
# Navigate to backend directory
cd backend

# Create virtual environment (if not already done)
python -m venv .venv

# Activate virtual environment
# On Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# On Linux/Mac:
source .venv/bin/activate

# Install dependencies (including new audio packages)
pip install -r requirements.txt
```

The new audio processing packages will be installed:
- `librosa==0.10.1` - Audio loading and resampling
- `soundfile==0.12.1` - WAV file I/O
- `scipy==1.14.0` - Audio processing utilities
- `pydub==0.25.1` - Alternative audio handling

### 2. Start the Backend Server

```bash
# Run development server with hot reload
uvicorn app.main:app --reload

# Server runs on: http://localhost:8000
# API docs: http://localhost:8000/docs
```

### 3. Test the Endpoint

#### Using cURL (Quick Test)

```bash
# First, prepare a test audio file or use an existing one
# Example with an MP3 file:

curl -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -F "file=@test_audio.mp3" \
  -F "source_language=vi" \
  -F "target_language=en"
```

#### Using Python

Create a test script `test_voice_api.py`:

```python
import requests
import json

def test_voice_translation():
    """Test the voice translation endpoint"""
    
    # API endpoint
    url = "http://localhost:8000/api/v1/audio/translate/voice"
    
    # Prepare files and data
    with open("test_audio.mp3", "rb") as audio_file:
        files = {"file": audio_file}
        data = {
            "source_language": "vi",
            "target_language": "en"
        }
        
        # Make request
        print("🚀 Sending request to voice translation API...")
        response = requests.post(url, files=files, data=data)
    
    # Check response
    if response.status_code == 200:
        result = response.json()
        print("\n✅ Success!")
        print(f"Original text: {result['data']['source_text']}")
        print(f"Translated text: {result['data']['translated_text']}")
        
        # Print timing information
        metadata = result.get('metadata', {})
        print(f"\n⏱️  Performance:")
        print(f"  Total time: {metadata.get('total_time_ms', 0):.1f}ms")
        print(f"  Audio preprocessing: {metadata.get('audio_preprocessing', {}).get('preprocessing_time_ms', 0):.1f}ms")
        print(f"  STT: {metadata.get('stt', {}).get('time_ms', 0):.1f}ms")
        print(f"  Translation: {metadata.get('translation', {}).get('time_ms', 0):.1f}ms")
        
        # Print audio info
        audio_info = metadata.get('audio_preprocessing', {})
        print(f"\n🎵 Audio Info:")
        print(f"  Original: {audio_info.get('original_sample_rate')}Hz, {audio_info.get('original_channels')} channels")
        print(f"  Format: {audio_info.get('original_format')}")
        print(f"  Size: {audio_info.get('original_size_mb'):.2f}MB")
        print(f"  Compressed: {audio_info.get('compression_ratio'):.1f}x")
        
    else:
        print(f"❌ Error: {response.status_code}")
        print(response.json())

if __name__ == "__main__":
    test_voice_translation()
```

Run it:
```bash
python test_voice_api.py
```

### 4. Check Supported Formats

```bash
# Get supported audio formats
curl http://localhost:8000/api/v1/audio/formats | python -m json.tool
```

Expected response:
```json
{
  "success": true,
  "data": {
    "supported_formats": ["AAC", "FLAC", "M4A", "MP3", "OGG", "WAV"],
    "audio_specifications": {
      "channels": 1,
      "format": "WAV",
      "max_duration_minutes": 30,
      "max_size_mb": 25,
      "sample_rate": 16000
    },
    "note": "All audio will be preprocessed to WAV 16kHz Mono format before transcription"
  }
}
```

### 5. Run Unit Tests

```bash
# Install pytest if needed
pip install pytest pytest-asyncio

# Run audio preprocessing tests
pytest backend/tests/test_audio_preprocessing.py -v

# Run quick test
python backend/tests/test_audio_preprocessing.py
```

---

## For Frontend Developers (Flutter)

### 1. Basic Implementation

Create a service to handle voice translation:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class VoiceTranslationService {
  final Dio _dio = Dio();
  static const String baseUrl = 'http://localhost:8000/api/v1';

  /// Translate audio file to target language
  Future<TranslationResponse> translateVoice({
    required File audioFile,
    required String targetLanguage,
    String? sourceLanguage,
    String? authToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(audioFile.path),
        'target_language': targetLanguage,
        if (sourceLanguage != null) 'source_language': sourceLanguage,
      });

      final options = Options(
        headers: {
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
      );

      final response = await _dio.post(
        '$baseUrl/audio/translate/voice',
        data: formData,
        options: options,
      );

      if (response.statusCode == 200) {
        return TranslationResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to translate: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Voice translation error: $e');
    }
  }

  /// Get supported audio formats
  Future<AudioFormatsResponse> getSupportedFormats() async {
    try {
      final response = await _dio.get('$baseUrl/audio/formats');
      return AudioFormatsResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get formats: $e');
    }
  }
}

// Response models
class TranslationResponse {
  final String sourceText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final bool isCached;
  final double responseTimes;
  final Map<String, dynamic> metadata;

  TranslationResponse({
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.confidence,
    required this.isCached,
    required this.responseTimes,
    required this.metadata,
  });

  factory TranslationResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return TranslationResponse(
      sourceText: data['source_text'] ?? '',
      translatedText: data['translated_text'] ?? '',
      sourceLanguage: data['source_language'] ?? '',
      targetLanguage: data['target_language'] ?? '',
      confidence: (data['stt_language_probability'] ?? 0).toDouble(),
      isCached: data['is_cached'] ?? false,
      responseTimes: (data['response_time_ms'] ?? 0).toDouble(),
      metadata: json['metadata'] ?? {},
    );
  }
}

class AudioFormatsResponse {
  final List<String> supportedFormats;
  final Map<String, dynamic> specifications;

  AudioFormatsResponse({
    required this.supportedFormats,
    required this.specifications,
  });

  factory AudioFormatsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return AudioFormatsResponse(
      supportedFormats: List<String>.from(data['supported_formats'] ?? []),
      specifications: data['audio_specifications'] ?? {},
    );
  }
}
```

### 2. Use in Flutter UI

```dart
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dart:io';

class VoiceTranslationScreen extends StatefulWidget {
  @override
  State<VoiceTranslationScreen> createState() => _VoiceTranslationScreenState();
}

class _VoiceTranslationScreenState extends State<VoiceTranslationScreen> {
  final VoiceTranslationService _service = VoiceTranslationService();
  final AudioRecorder _recorder = AudioRecorder();
  
  bool _isRecording = false;
  String? _recordingPath;
  String? _sourceLanguage;
  String _targetLanguage = 'en';
  bool _isTranslating = false;
  String? _translatedText;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Voice Translation')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Selection
            Text('Languages', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Source (optional)'),
                      DropdownButton<String?>(
                        isExpanded: true,
                        value: _sourceLanguage,
                        items: [
                          DropdownMenuItem(child: Text('Auto-detect'), value: null),
                          DropdownMenuItem(child: Text('Vietnamese'), value: 'vi'),
                          DropdownMenuItem(child: Text('English'), value: 'en'),
                        ],
                        onChanged: (value) => setState(() => _sourceLanguage = value),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Target'),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: _targetLanguage,
                        items: [
                          DropdownMenuItem(child: Text('English'), value: 'en'),
                          DropdownMenuItem(child: Text('Vietnamese'), value: 'vi'),
                          DropdownMenuItem(child: Text('Spanish'), value: 'es'),
                        ],
                        onChanged: (value) => setState(() => _targetLanguage = value!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Recording Section
            Text('Record Audio', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isTranslating ? null : _toggleRecording,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            if (_recordingPath != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Recording saved: $_recordingPath'),
              ),
            SizedBox(height: 24),

            // Translate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _recordingPath == null || _isTranslating ? null : _translate,
                child: _isTranslating
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Translate'),
              ),
            ),
            SizedBox(height: 24),

            // Results
            if (_translatedText != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Translation Result', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: SelectableText(_translatedText!),
                    ),
                  ),
                ],
              ),

            // Error
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Error: $_error',
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
          _recordingPath = path;
          _translatedText = null;
          _error = null;
        });
      } else {
        if (await _recorder.hasPermission()) {
          await _recorder.start();
          setState(() => _isRecording = true);
        }
      }
    } catch (e) {
      setState(() => _error = 'Recording error: $e');
    }
  }

  Future<void> _translate() async {
    if (_recordingPath == null) return;

    setState(() {
      _isTranslating = true;
      _error = null;
    });

    try {
      final response = await _service.translateVoice(
        audioFile: File(_recordingPath!),
        targetLanguage: _targetLanguage,
        sourceLanguage: _sourceLanguage,
      );

      setState(() {
        _translatedText = response.translatedText;
      });

      // Show timing info
      final metadata = response.metadata;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Translated in ${response.responseTimes.toStringAsFixed(0)}ms\n'
            'Confidence: ${(response.confidence * 100).toStringAsFixed(1)}%',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
```

### 3. Add Required Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  record: ^5.0.0
  permission_handler: ^11.4.0
```

### 4. Add Audio Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio for translation</string>
```

---

## Common Issues & Solutions

### Issue: "Audio file too large"
**Solution**: Use compressed audio format (MP3, M4A) instead of WAV

### Issue: "No text could be extracted"
**Solution**: 
- Ensure audio is not silent
- Increase volume before recording
- Try in a quieter environment
- Use higher quality audio

### Issue: "Failed to connect to backend"
**Solution**: 
- Check backend is running: `http://localhost:8000/health`
- Update API URL in Flutter service
- Check firewall/network settings

### Issue: "Module 'librosa' not found"
**Solution**:
```bash
pip install librosa soundfile scipy pydub
```

---

## Performance Tips

### For Backend

1. **Use audio caching**: Identical audio will use cached transcription
2. **Limit concurrent requests**: Use rate limiting to prevent overload
3. **Monitor resource usage**: Check CPU/memory on server

### For Flutter

1. **Show progress indicator**: Processing takes 5-20 seconds
2. **Compress audio**: Use lossy compression (MP3, AAC) for faster processing
3. **Provide source language**: Skips detection (~500ms faster)
4. **Batch operations**: Process multiple translations in parallel

---

## Next Steps

1. ✅ Audio file upload & preprocessing
2. ✅ Speech-to-Text with faster-whisper
3. ✅ Translation with caching
4. 📋 Real-time audio streaming
5. 📋 Noise reduction & audio enhancement
6. 📋 Speaker diarization
7. 📋 Word-level timestamps

Check the [Voice Translation API Documentation](VOICE_TRANSLATION_API.md) for more details.
