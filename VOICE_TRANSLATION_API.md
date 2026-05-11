# Voice Translation API - Audio Preprocessing & STT Integration

## Overview

The Voice Translation API endpoint (`/audio/translate/voice`) provides a complete pipeline for translating audio files with built-in audio preprocessing. This endpoint:

1. **Validates** audio format and file size
2. **Preprocesses** audio to standard format (WAV 16kHz mono)
3. **Transcribes** audio to text using faster-whisper
4. **Translates** the extracted text
5. **Returns** comprehensive metadata about the entire process

## Supported Audio Formats

The API supports multiple input audio formats and automatically converts them to the standard format:

| Format | MIME Type | File Extensions |
|--------|-----------|-----------------|
| MP3 | audio/mpeg, audio/mp3 | .mp3 |
| M4A/AAC | audio/mp4, audio/aac | .m4a, .aac |
| WAV | audio/wav | .wav |
| FLAC | audio/flac | .flac |
| OGG Vorbis | audio/ogg | .ogg |

## Audio Specifications

### Input Requirements
- **Maximum file size**: 25 MB
- **Maximum duration**: 30 minutes
- **Supported formats**: MP3, M4A, AAC, WAV, FLAC, OGG
- **Any sample rate**: 8kHz - 48kHz+
- **Any channel count**: Mono, stereo, or multi-channel

### Output Format (After Preprocessing)
- **Format**: WAV (Waveform Audio File Format)
- **Sample Rate**: 16 kHz (16,000 samples per second)
- **Channels**: 1 (Mono)
- **Bit Depth**: 16-bit PCM (implied by librosa/soundfile defaults)

## API Endpoint Details

### POST `/api/v1/audio/translate/voice`

Translate voice audio with automatic preprocessing and transcription.

#### Request

**Content-Type**: `multipart/form-data`

**Parameters**:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | File | Yes | Audio file (MP3, M4A, AAC, WAV, FLAC, OGG) |
| `target_language` | String | Yes | Target language code (e.g., 'en', 'vi', 'fr') |
| `source_language` | String | No | Source language code. If omitted, language is auto-detected |

#### Response

**Status Code**: `200 OK`

**Response Body**:

```json
{
  "success": true,
  "data": {
    "source_text": "Xin chào, đây là test",
    "translated_text": "Hello, this is a test",
    "source_language": "vi",
    "target_language": "en",
    "stt_language_probability": 0.95,
    "is_cached": false,
    "response_time_ms": 2345.67,
    "translation_type": "voice"
  },
  "metadata": {
    "audio_preprocessing": {
      "original_sample_rate": 48000,
      "original_channels": 2,
      "original_format": "MP3",
      "original_size_mb": 2.34,
      "preprocessing_time_ms": 234.5,
      "target_sample_rate": 16000,
      "target_channels": 1,
      "target_format": "WAV",
      "preprocessed_size_mb": 0.45,
      "compression_ratio": 5.2
    },
    "stt": {
      "detected_language": "vi",
      "language_probability": 0.95,
      "time_ms": 1200.3
    },
    "translation": {
      "is_cached": false,
      "time_ms": 800.2
    },
    "total_time_ms": 2345.67
  }
}
```

#### Error Responses

**400 Bad Request** - Empty file:
```json
{
  "detail": "Empty audio file provided"
}
```

**422 Unprocessable Entity** - Audio preprocessing error:
```json
{
  "detail": "Audio preprocessing failed: Audio file too large (30.5MB > 25MB). Maximum allowed size is 25MB"
}
```

**422 Unprocessable Entity** - No text extracted:
```json
{
  "detail": "No text could be extracted from the audio. The audio may be silent or unclear."
}
```

**429 Too Many Requests** - Rate limit exceeded:
```json
{
  "detail": "Rate limit exceeded. Reset in 3456s"
}
```

**500 Internal Server Error** - Server error:
```json
{
  "detail": "Internal server error during voice translation"
}
```

## Audio Preprocessing Process

The preprocessing pipeline automatically handles various input formats:

```
Input Audio File
  ↓
[Format Detection]
  - Detect MIME type or file extension
  - Support: MP3, M4A, AAC, WAV, FLAC, OGG
  ↓
[Validation]
  - Check file size (max 25MB)
  - Check duration (max 30 min)
  - Verify audio data integrity
  ↓
[Loading & Analysis]
  - Load audio with librosa
  - Get sample rate and channel info
  ↓
[Channel Conversion]
  - If stereo/multi-channel: Convert to mono (average channels)
  ↓
[Resampling]
  - If not 16kHz: Resample to 16kHz
  ↓
[Normalization]
  - Normalize audio level to prevent clipping
  - Scale to [-1, 1] range
  ↓
[Encoding]
  - Save as WAV 16-bit PCM
  ↓
Output: WAV 16kHz Mono
  ↓
[Speech-to-Text Processing]
```

## Example Usage

### cURL

```bash
# Translate a Vietnamese audio file to English
curl -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@/path/to/audio.mp3" \
  -F "source_language=vi" \
  -F "target_language=en"

# Auto-detect source language
curl -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -F "file=@/path/to/audio.m4a" \
  -F "target_language=es"
```

### Python (with requests)

```python
import requests

# Prepare the request
url = "http://localhost:8000/api/v1/audio/translate/voice"
files = {"file": open("/path/to/audio.mp3", "rb")}
data = {
    "source_language": "vi",
    "target_language": "en"
}

# Optional: Add authorization header
headers = {"Authorization": "Bearer YOUR_TOKEN"}

# Make request
response = requests.post(url, files=files, data=data, headers=headers)
result = response.json()

print(f"Translated: {result['data']['translated_text']}")
print(f"Time taken: {result['metadata']['total_time_ms']:.1f}ms")
print(f"Preprocessing: {result['metadata']['audio_preprocessing']['preprocessing_time_ms']:.1f}ms")
print(f"STT: {result['metadata']['stt']['time_ms']:.1f}ms")
print(f"Translation: {result['metadata']['translation']['time_ms']:.1f}ms")
```

### Flutter (with dio)

```dart
import 'package:dio/dio.dart';

Future<void> translateAudio() async {
  final dio = Dio();
  final file = File('/path/to/audio.mp3');
  
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(file.path),
    'source_language': 'vi',
    'target_language': 'en',
  });
  
  try {
    final response = await dio.post(
      'http://localhost:8000/api/v1/audio/translate/voice',
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer YOUR_TOKEN'}
      ),
    );
    
    final result = response.data;
    print('Translated: ${result['data']['translated_text']}');
    print('Total time: ${result['metadata']['total_time_ms']}ms');
  } catch (e) {
    print('Error: $e');
  }
}
```

## Rate Limiting

Rate limits are applied per user:

- **Authenticated users**: 100 requests/hour
- **Guest users**: 10 requests/hour per IP address

Rate limit information is returned in response metadata.

## Get Supported Formats

### GET `/api/v1/audio/formats`

Get list of supported audio formats and specifications.

**Response**:
```json
{
  "success": true,
  "data": {
    "supported_formats": ["MP3", "M4A", "AAC", "WAV", "FLAC", "OGG"],
    "audio_specifications": {
      "sample_rate": 16000,
      "channels": 1,
      "format": "WAV",
      "max_size_mb": 25,
      "max_duration_minutes": 30
    },
    "note": "All audio will be preprocessed to WAV 16kHz Mono format before transcription"
  }
}
```

## Performance Characteristics

### Processing Time Breakdown

Typical processing times (for 1-minute audio on standard hardware):

| Component | Typical Time | Notes |
|-----------|--------------|-------|
| File upload | 2-5s | Depends on network and file size |
| Audio preprocessing | 200-500ms | Depends on sample rate and channels |
| Speech-to-Text | 3-8s | Depends on audio quality and duration |
| Translation | 1-3s | Cached requests are much faster |
| **Total** | **6-20s** | Mostly I/O bound |

### File Size After Preprocessing

The WAV 16kHz mono format is relatively compact:

- **Bitrate**: 16-bit × 16,000Hz = 256 kbps
- **Per minute**: ~1.92 MB
- **Compression**: Typically 2-10x smaller than MP3

### Memory Usage

- **Peak memory**: ~500MB (for 25MB input file)
- **Per-request**: ~50-200MB depending on audio length
- **Model**: Whisper model uses ~2GB RAM (singleton, shared across requests)

## Error Handling

The API provides detailed error messages for common issues:

### Audio Validation Errors

1. **Empty file**: File has no data
2. **File too large**: Exceeds 25MB limit
3. **Duration too long**: Exceeds 30-minute limit
4. **Invalid format**: Unrecognized audio format
5. **Corrupt file**: Cannot load audio data

### STT Errors

1. **No text extracted**: Audio is silent or too unclear
2. **Language not detected**: Could not determine source language
3. **Model error**: Whisper model failed to initialize

### Translation Errors

1. **Invalid language code**: Language not supported
2. **Translation failed**: Service unavailable
3. **Rate limit exceeded**: Too many requests

## Best Practices

### Input Audio Quality

- **Bitrate**: 128kbps or higher (320kbps+ recommended)
- **Sample rate**: 16kHz or higher
- **Noise**: Minimize background noise for better accuracy
- **Duration**: Shorter clips (< 10 min) process faster

### Preprocessing Considerations

- **Channel mixing**: Stereo/mono conversion may introduce slight quality loss
- **Resampling**: Downsampling from high sample rates is lossless, upsampling may introduce artifacts
- **Clipping**: Audio levels are normalized to prevent overflow

### API Usage

- **File size**: Keep files under 10MB for better performance
- **Parallel requests**: Start with 1-2 concurrent requests, monitor server load
- **Caching**: Translation results are cached - repeated audio with same language pair will be faster
- **Language detection**: Providing source_language skips detection (~500ms saved)

## Dependencies

The implementation uses:

- **librosa**: Audio loading and resampling
- **soundfile**: WAV file I/O
- **scipy**: Audio processing utilities
- **faster-whisper**: Speech-to-Text transcription
- **FastAPI**: Web framework

## Installation

### Backend Setup

```bash
# Install dependencies
pip install -r requirements.txt

# Or manually
pip install librosa soundfile scipy faster-whisper

# For audio format support, ensure ffmpeg is installed:
# Ubuntu/Debian:
sudo apt-get install ffmpeg

# macOS:
brew install ffmpeg

# Windows:
# Download from https://ffmpeg.org/download.html
# Or: choco install ffmpeg
```

### Running Tests

```bash
# Test audio preprocessing
pytest backend/tests/test_audio_preprocessing.py -v

# Quick test
python backend/tests/test_audio_preprocessing.py
```

## Troubleshooting

### "Audio file too large"
- Ensure file is under 25MB
- Convert to compressed format (MP3, AAC) before uploading
- Trim long files (max 30 minutes)

### "No text could be extracted"
- Check audio is not silent or background noise only
- Increase audio volume/boost levels
- Use higher quality audio file
- Try providing source_language hint

### "Failed to validate audio file"
- Verify file is a valid audio format
- Try converting with ffmpeg: `ffmpeg -i input.m4a -acodec libmp3lame output.mp3`
- Check file is not corrupted

### Slow processing
- Reduce file size or duration
- Audio files with high sample rates will be processed slower
- Check server CPU/RAM availability
- Large Whisper models are slower - the API uses "small" model for speed

## API Documentation

For interactive API documentation, visit:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

The `/audio/translate/voice` endpoint will be listed under the "audio" tag.

## Future Enhancements

Planned improvements:

1. **Streaming audio**: Support for streaming audio uploads
2. **Batch processing**: Process multiple files in one request
3. **Custom preprocessing**: Allow users to control preprocessing parameters
4. **Audio enhancement**: Noise reduction and audio quality improvement
5. **Caching preprocessed audio**: Cache preprocessing results for identical inputs
6. **Language-specific models**: Use language-optimized Whisper models
7. **Speaker diarization**: Identify different speakers in audio
8. **Timestamps**: Word-level timing information in output
