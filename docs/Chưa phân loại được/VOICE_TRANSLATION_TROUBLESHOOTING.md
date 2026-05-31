# Voice Translation API - Complete Reference & Troubleshooting

## 📚 Complete Code Reference

### 1. Audio Preprocessing Service

**File**: `backend/app/services/audio_preprocessing_service.py`

Key constants:
```python
SUPPORTED_AUDIO_FORMATS = {
    "audio/mpeg": ".mp3",
    "audio/mp4": ".m4a",
    "audio/aac": ".aac",
    "audio/wav": ".wav",
    "audio/flac": ".flac",
    "audio/ogg": ".ogg",
}

TARGET_SAMPLE_RATE = 16000      # 16 kHz
TARGET_CHANNELS = 1              # Mono
TARGET_FORMAT = "WAV"            # Waveform Audio
MAX_AUDIO_SIZE_MB = 25           # 25 MB
MAX_AUDIO_DURATION_MINUTES = 30  # 30 minutes
```

Main methods:
```python
# Validate without preprocessing
validation = AudioPreprocessingService.validate_audio_file(
    audio_bytes=audio_bytes,
    content_type="audio/mp3",
    filename="voice.mp3"
)

# Full preprocessing
preprocessed_bytes, metadata = await AudioPreprocessingService.preprocess_audio(
    audio_bytes=audio_bytes,
    content_type="audio/mp3",
    filename="voice.mp3"
)

# Get supported formats
formats = AudioPreprocessingService.get_supported_formats()
# Returns: ['AAC', 'FLAC', 'M4A', 'MP3', 'OGG', 'WAV']

# Get audio specs
specs = AudioPreprocessingService.get_audio_specs()
# Returns: {
#     'sample_rate': 16000,
#     'channels': 1,
#     'format': 'WAV',
#     'max_size_mb': 25,
#     'max_duration_minutes': 30
# }
```

### 2. Endpoint Implementation

**File**: `backend/app/api/v1/endpoints/audio.py`

New endpoint:
```python
@router.post("/translate/voice", response_model=SuccessResponse)
async def translate_voice_with_preprocessing(
    request: Request,
    source_language: Optional[str] = Form(None),
    target_language: str = Form(...),
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_current_user_optional),
):
    # Handles:
    # 1. Rate limiting
    # 2. Audio preprocessing
    # 3. Speech-to-Text
    # 4. Translation
    # 5. Response building
```

Format info endpoint:
```python
@router.get("/formats", response_model=SuccessResponse)
async def get_supported_audio_formats():
    return SuccessResponse(
        data={
            "supported_formats": AudioPreprocessingService.get_supported_formats(),
            "audio_specifications": AudioPreprocessingService.get_audio_specs(),
            "note": "All audio will be preprocessed to WAV 16kHz Mono format",
        }
    )
```

---

## 🔧 Installation & Setup

### Prerequisites

```bash
# Python 3.9+
python --version

# ffmpeg (required by librosa)
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install ffmpeg

# macOS:
brew install ffmpeg

# Windows (using chocolatey):
choco install ffmpeg
# Or download from https://ffmpeg.org/download.html
```

### Backend Setup

```bash
# Navigate to backend
cd backend

# Create virtual environment
python -m venv .venv

# Activate (Windows PowerShell)
.\.venv\Scripts\Activate.ps1

# Activate (Linux/Mac)
source .venv/bin/activate

# Upgrade pip
python -m pip install --upgrade pip

# Install all dependencies
pip install -r requirements.txt

# Verify installation
python -c "import librosa, soundfile, scipy; print('✅ All audio libs installed')"
```

### Start Backend

```bash
# Development with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4

# Custom settings
uvicorn app.main:app --reload --log-level debug
```

---

## 🧪 Testing Guide

### Quick Test

```bash
# Run all audio preprocessing tests
pytest backend/tests/test_audio_preprocessing.py -v

# Run specific test
pytest backend/tests/test_audio_preprocessing.py::TestAudioPreprocessing::test_audio_validation_valid_file -v

# Run with output
pytest backend/tests/test_audio_preprocessing.py -v -s

# Quick validation script
python backend/tests/test_audio_preprocessing.py
```

### Manual API Testing

#### Using cURL

```bash
# Basic translation
curl -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -F "file=@test_audio.mp3" \
  -F "target_language=en"

# With source language
curl -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -F "file=@test_audio.mp3" \
  -F "source_language=vi" \
  -F "target_language=en"

# Get supported formats
curl http://localhost:8000/api/v1/audio/formats | python -m json.tool

# With authentication
curl -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@test_audio.mp3" \
  -F "target_language=en"

# Save response to file
curl -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -F "file=@test_audio.mp3" \
  -F "target_language=en" \
  > response.json

python -m json.tool < response.json
```

#### Using Python

```python
import requests
import json
from pathlib import Path

def test_voice_translation():
    """Complete test of voice translation endpoint"""
    
    url = "http://localhost:8000/api/v1/audio/translate/voice"
    
    # Test 1: Get supported formats
    print("🔍 Test 1: Get supported formats")
    formats_response = requests.get(
        "http://localhost:8000/api/v1/audio/formats"
    )
    print(f"Supported formats: {formats_response.json()['data']['supported_formats']}")
    print()
    
    # Test 2: Upload audio file
    print("🔍 Test 2: Upload and translate audio")
    audio_file = Path("test_audio.mp3")
    
    if not audio_file.exists():
        print("⚠️  No test audio file found. Create one first.")
        return
    
    with open(audio_file, "rb") as f:
        files = {"file": f}
        data = {
            "source_language": "vi",
            "target_language": "en"
        }
        
        print(f"Uploading {audio_file.name}...")
        response = requests.post(url, files=files, data=data)
    
    if response.status_code == 200:
        result = response.json()
        
        print("✅ Success!")
        print(f"Original text: {result['data']['source_text']}")
        print(f"Translated text: {result['data']['translated_text']}")
        print(f"Source language: {result['data']['source_language']}")
        print(f"Confidence: {result['data']['stt_language_probability']:.2%}")
        
        metadata = result.get('metadata', {})
        print(f"\n⏱️  Timing:")
        print(f"  Total: {metadata.get('total_time_ms', 0):.0f}ms")
        print(f"  Preprocessing: {metadata.get('audio_preprocessing', {}).get('preprocessing_time_ms', 0):.0f}ms")
        print(f"  STT: {metadata.get('stt', {}).get('time_ms', 0):.0f}ms")
        print(f"  Translation: {metadata.get('translation', {}).get('time_ms', 0):.0f}ms")
        
        print(f"\n💾 Audio Info:")
        audio_info = metadata.get('audio_preprocessing', {})
        print(f"  Original: {audio_info.get('original_sample_rate')}Hz, {audio_info.get('original_channels')} channels")
        print(f"  Preprocessed: {audio_info.get('target_sample_rate')}Hz, {audio_info.get('target_channels')} channel")
        print(f"  Compression: {audio_info.get('compression_ratio', 1):.1f}x")
        
    else:
        print(f"❌ Error: {response.status_code}")
        print(response.json())

if __name__ == "__main__":
    test_voice_translation()
```

#### Using httpie

```bash
# More readable than curl
http -f POST http://localhost:8000/api/v1/audio/translate/voice \
  file@test_audio.mp3 \
  source_language=vi \
  target_language=en

# Pretty print response
http -f POST http://localhost:8000/api/v1/audio/translate/voice \
  file@test_audio.mp3 \
  target_language=en | python -m json.tool

# Save response
http -f POST http://localhost:8000/api/v1/audio/translate/voice \
  file@test_audio.mp3 \
  target_language=en > response.json
```

#### Using Postman

1. **Create new request**:
   - Method: POST
   - URL: `http://localhost:8000/api/v1/audio/translate/voice`

2. **Headers**:
   ```
   Authorization: Bearer YOUR_TOKEN  (if needed)
   ```

3. **Body** (form-data):
   - Key: `file`, Type: File, Value: Select audio file
   - Key: `source_language`, Type: text, Value: `vi`
   - Key: `target_language`, Type: text, Value: `en`

4. **Send and view response**

---

## 🐛 Troubleshooting Guide

### Installation Issues

#### Problem: "ModuleNotFoundError: No module named 'librosa'"

```bash
# Solution 1: Install individually
pip install librosa soundfile scipy pydub

# Solution 2: Install from requirements
pip install -r requirements.txt

# Verify
python -c "import librosa; print(librosa.__version__)"
```

#### Problem: "FFmpeg not found"

```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# Check installation
ffmpeg -version

# Test librosa with ffmpeg
python -c "import librosa; audio, sr = librosa.load('/path/to/file.mp3')"
```

#### Problem: "No module named 'soundfile'"

```bash
# Linux might need build tools
sudo apt-get install build-essential

# Install soundfile
pip install soundfile

# If still failing, try with conda
conda install -c conda-forge soundfile
```

### Runtime Issues

#### Problem: "Audio file too large"

```
Response: "Audio file too large (30.5MB > 25MB). Maximum allowed size is 25MB"
```

**Solutions**:
1. Compress to MP3: `ffmpeg -i input.wav -acodec libmp3lame -ab 128k output.mp3`
2. Trim file: `ffmpeg -i input.mp3 -ss 0 -to 600 output.mp3` (600 seconds = 10 min)
3. Use online compressor

#### Problem: "No text could be extracted"

```
Response: "No text could be extracted from the audio. The audio may be silent or unclear."
```

**Solutions**:
1. Ensure audio is not silent - check volume
2. Try in quieter environment
3. Increase audio volume: `ffmpeg -i input.mp3 -filter:a "volume=1.5" output.mp3`
4. Use higher quality audio source
5. Try with source language provided

#### Problem: "Failed to validate audio file"

```
Response: "Failed to validate audio file: [error message]"
```

**Solutions**:
1. Verify file is valid audio: `ffprobe file.mp3`
2. Try converting: `ffmpeg -i input.mp3 -acodec libmp3lame -q:a 5 output.mp3`
3. Check file isn't corrupted
4. Try different format

#### Problem: "The file could not be decoded with any codec"

**Solutions**:
```bash
# Convert to standard MP3
ffmpeg -i input.m4a -acodec libmp3lame -q:a 5 output.mp3

# Or convert to WAV
ffmpeg -i input.m4a -acodec pcm_s16le -ar 44100 output.wav

# Check what format it actually is
ffprobe input.m4a
```

### Performance Issues

#### Problem: "Request timeout"

**Solutions**:
1. Reduce file size: `ffmpeg -i input.mp3 -q:a 7 output.mp3`
2. Trim duration: Split long files into chunks
3. Increase server timeout (if using reverse proxy)
4. Check server resources: `top`, `free -h`

#### Problem: "High memory usage"

**Solutions**:
1. Use smaller Whisper model (change in `stt_service.py`)
2. Process shorter audio files
3. Close other applications
4. Increase swap space (if needed)

#### Problem: "Slow transcription"

**Solutions**:
1. Provide source language (skips detection)
2. Use lower quality model (in production)
3. Check server CPU: `top`
4. Use GPU if available (update Whisper config)

### Connection Issues

#### Problem: "Failed to connect to http://localhost:8000"

**Solutions**:
1. Verify backend is running: `http://localhost:8000/health`
2. Check if port 8000 is in use: `lsof -i :8000` (Mac/Linux) or `netstat -ano | findstr :8000` (Windows)
3. Start backend: `uvicorn app.main:app --reload`
4. Check firewall settings

#### Problem: "ConnectionRefusedError"

```python
# Backend not running
# Solution: Start it with:
cd backend
uvicorn app.main:app --reload
```

#### Problem: "Request timed out"

**Solutions**:
1. Check network connection
2. Increase timeout in client: `requests.post(..., timeout=60)`
3. Check server logs for errors
4. Verify server isn't overloaded

### Database Issues

#### Problem: "Database connection error"

```python
# Error: could not connect to server
# Solution: Check PostgreSQL is running
```

```bash
# Linux
systemctl status postgresql

# macOS
brew services list

# Windows
# Check Services > PostgreSQL
```

#### Problem: "Redis connection failed"

```python
# Warning: Redis initialization failed
# Solution: Backend works without Redis (uses DB fallback)
```

### Authentication Issues

#### Problem: "Unauthorized: 401"

```bash
# Missing or invalid token
# Solution: Provide valid JWT token
curl -H "Authorization: Bearer YOUR_TOKEN" \
  -X POST "http://localhost:8000/api/v1/audio/translate/voice" \
  -F "file=@audio.mp3" \
  -F "target_language=en"
```

#### Problem: "Forbidden: 403"

```bash
# Valid token but insufficient permissions
# Solution: Use different user or modify permissions
```

---

## 📊 Performance Tuning

### Audio Preprocessing

```python
# Current settings (balanced)
TARGET_SAMPLE_RATE = 16000      # Good balance for STT
TARGET_CHANNELS = 1              # Mono is standard for STT
MAX_AUDIO_SIZE_MB = 25           # Prevent memory issues
MAX_AUDIO_DURATION_MINUTES = 30  # Reasonable limit

# For faster processing (lower quality)
TARGET_SAMPLE_RATE = 8000        # Faster but lower quality
MAX_AUDIO_DURATION_MINUTES = 15  # Shorter limit

# For higher quality (slower processing)
TARGET_SAMPLE_RATE = 22050       # Higher quality, slower
MAX_AUDIO_DURATION_MINUTES = 60  # Longer limit
```

### Whisper Model Tuning

```python
# In stt_service.py
class STTService:
    _model_size = "small"       # Current: small (good balance)
    _device = "cpu"             # Use "cuda" if GPU available
    _compute_type = "int8"      # int8 for speed, float32 for quality
    
    # Other options:
    # _model_size = "base"      # Faster, lower quality
    # _model_size = "medium"    # Slower, higher quality
    # _model_size = "large"     # Slowest, best quality
```

### Concurrency Tuning

```bash
# Adjust uvicorn workers based on CPU cores
# Rule of thumb: (2 x CPU cores) + 1

# For 4 CPU cores:
uvicorn app.main:app --workers 9

# Monitor resource usage:
htop  # Linux/Mac
tasklist  # Windows
```

---

## 📈 Monitoring & Logging

### Enable Debug Logging

```python
# In audio.py or main.py
import logging

logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)
```

### Monitor Endpoints

```bash
# Check health
curl http://localhost:8000/health | python -m json.tool

# Check if API is working
curl http://localhost:8000/docs

# Monitor logs in real-time
tail -f backend/logs/*.log
```

### Performance Metrics

```python
# The API returns detailed timing:
response = requests.post(url, files=files, data=data).json()

metadata = response['metadata']
print(f"Total: {metadata['total_time_ms']:.0f}ms")
print(f"  Preprocessing: {metadata['audio_preprocessing']['preprocessing_time_ms']:.0f}ms")
print(f"  STT: {metadata['stt']['time_ms']:.0f}ms")
print(f"  Translation: {metadata['translation']['time_ms']:.0f}ms")
```

---

## 🔍 Debugging Techniques

### Check Audio File

```bash
# Get audio info
ffprobe audio.mp3
ffmpeg -i audio.mp3 2>&1 | grep -E "Stream|Duration"

# Validate audio
ffmpeg -i audio.mp3 -f null -
```

### Test Components Individually

```python
# Test 1: Audio preprocessing only
from app.services.audio_preprocessing_service import AudioPreprocessingService

audio_bytes = open("test.mp3", "rb").read()
validation = AudioPreprocessingService.validate_audio_file(audio_bytes)
print(validation)

# Test 2: STT only
from app.services.stt_service import STTService

result = await STTService.transcribe_audio(preprocessed_bytes)
print(result)

# Test 3: Translation only
from app.services.translation_service import TranslationService

text = "Hello, this is a test"
translated = await TranslationService.translate_with_cache(request, db, None, True)
print(translated)
```

### Use Python Debugger

```python
# Add breakpoint
import pdb; pdb.set_trace()

# Or in Python 3.7+
breakpoint()

# Then navigate with:
# n (next), s (step), c (continue), l (list), p var (print)
```

---

## ✅ Final Verification Checklist

- [ ] Backend starts without errors
- [ ] `/health` endpoint responds
- [ ] `/api/v1/audio/formats` returns formats
- [ ] Audio file can be uploaded
- [ ] Audio is preprocessed correctly
- [ ] STT produces text output
- [ ] Translation produces correct translation
- [ ] Response includes all metadata
- [ ] Rate limiting works
- [ ] Error handling works
- [ ] Tests pass
- [ ] No memory leaks
- [ ] Reasonable response times

---

## 🆘 Getting Help

If issues persist:

1. **Check logs**: Look at backend console output
2. **Review documentation**: Check VOICE_TRANSLATION_API.md
3. **Run tests**: `pytest backend/tests/test_audio_preprocessing.py -v`
4. **Try minimal example**: Use simplest possible audio file
5. **Check dependencies**: `pip list | grep -E "librosa|soundfile|scipy"`
6. **Verify setup**: Follow VOICE_TRANSLATION_QUICK_START.md

---

**Good luck with your Voice Translation API! 🚀**
