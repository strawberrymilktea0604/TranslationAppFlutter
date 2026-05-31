"""
Test cases for image translation pipeline
Tests: OCR, image preprocessing, memory cleanup, caching
"""
import pytest
import io
from PIL import Image

from app.services.image_service import ImageService
from app.services.ocr_service import OCRService


@pytest.fixture
def sample_image_bytes():
    """Create a simple test image with text"""
    # Create a PIL image with text
    img = Image.new('RGB', (400, 100), color='white')
    from PIL import ImageDraw, ImageFont
    
    draw = ImageDraw.Draw(img)
    
    # Try to use a default font, fallback to default if not available
    try:
        font = ImageFont.truetype("arial.ttf", 20)
    except Exception:
        font = ImageFont.load_default()
    
    draw.text((10, 10), "Hello World", fill='black', font=font)
    
    # Convert to bytes
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='PNG')
    return img_bytes.getvalue()


@pytest.fixture
def large_image_bytes():
    """Create a large test image"""
    img = Image.new('RGB', (2000, 2000), color='white')
    img_bytes = io.BytesIO()
    img.save(img_bytes, format='PNG')
    return img_bytes.getvalue()


@pytest.fixture
def corrupted_image_bytes():
    """Create corrupted image bytes"""
    return b'This is not a valid image file content'


class TestImageService:
    """Test image preprocessing service"""
    
    def test_validate_image_success(self, sample_image_bytes):
        """Test valid image validation"""
        is_valid, msg = ImageService.validate_image_bytes(sample_image_bytes)
        assert is_valid is True
        assert "valid" in msg.lower()
    
    def test_validate_corrupted_image(self, corrupted_image_bytes):
        """Test corrupted image detection"""
        is_valid, msg = ImageService.validate_image_bytes(corrupted_image_bytes)
        assert is_valid is False
        assert "Invalid" in msg
    
    def test_validate_oversized_image(self, sample_image_bytes):
        """Test oversized image detection"""
        oversized = sample_image_bytes * (11 * 1024 * 1024 // len(sample_image_bytes))
        is_valid, msg = ImageService.validate_image_bytes(
            oversized,
            max_size_mb=10
        )
        assert is_valid is False
        assert "exceeds" in msg
    
    @pytest.mark.asyncio
    async def test_optimize_image(self, sample_image_bytes):
        """Test image optimization in memory"""
        optimized = await ImageService.optimize_image(sample_image_bytes)
        
        assert optimized is not None
        assert len(optimized) > 0
        assert isinstance(optimized, bytes)
        
        # Verify it's still a valid image
        img = Image.open(io.BytesIO(optimized))
        assert img is not None
    
    @pytest.mark.asyncio
    async def test_image_hash(self, sample_image_bytes):
        """Test image hashing"""
        hash1 = await ImageService.get_image_hash(sample_image_bytes)
        hash2 = await ImageService.get_image_hash(sample_image_bytes)
        
        assert hash1 == hash2
        assert len(hash1) == 64  # SHA256 hex length
    
    @pytest.mark.asyncio
    async def test_image_metadata(self, sample_image_bytes):
        """Test image metadata extraction"""
        metadata = await ImageService.extract_image_metadata(sample_image_bytes)
        
        assert metadata['format'] is not None
        assert 'size' in metadata
        assert 'width' in metadata
        assert 'height' in metadata
        assert metadata['bytes'] == len(sample_image_bytes)
    
    @pytest.mark.asyncio
    async def test_memory_cleanup(self, sample_image_bytes):
        """Test explicit memory cleanup"""
        # Should not raise any error
        await ImageService.cleanup_image_memory(sample_image_bytes)


class TestOCRService:
    """Test OCR service"""
    
    def test_validate_image(self, sample_image_bytes):
        """Test image validation before OCR"""
        is_valid, msg = OCRService.validate_image(sample_image_bytes)
        assert is_valid is True
    
    def test_validate_corrupted(self, corrupted_image_bytes):
        """Test corrupted image validation"""
        is_valid, msg = OCRService.validate_image(corrupted_image_bytes)
        assert is_valid is False
    
    def test_supported_languages(self):
        """Test language mapping"""
        assert 'en' in OCRService.SUPPORTED_LANGUAGES
        assert 'vi' in OCRService.SUPPORTED_LANGUAGES
        assert OCRService.SUPPORTED_LANGUAGES['en'] == 'eng'
        assert OCRService.SUPPORTED_LANGUAGES['vi'] == 'vie'
    
    @pytest.mark.asyncio
    @pytest.mark.slow
    async def test_extract_text(self, sample_image_bytes):
        """Test text extraction from image
        
        Note: This is a slow test because Tesseract OCR takes time
        Run with: pytest -m slow
        """
        result = await OCRService.extract_text(
            sample_image_bytes,
            language='en',
            preprocess=True
        )
        
        assert 'raw_text' in result
        assert 'confidence' in result
        assert 'language' in result
        assert 'processing_time_ms' in result
        assert result['confidence'] >= 0
        assert result['confidence'] <= 100
    
    @pytest.mark.asyncio
    @pytest.mark.slow
    async def test_extract_text_vietnamese(self, sample_image_bytes):
        """Test Vietnamese text extraction"""
        result = await OCRService.extract_text(
            sample_image_bytes,
            language='vi',
            preprocess=True
        )
        
        assert result['language'] == 'vie'
        assert 'processing_time_ms' in result


class TestImagePipeline:
    """Test complete image translation pipeline"""
    
    @pytest.mark.asyncio
    async def test_optimization_pipeline(self, sample_image_bytes):
        """Test image optimization pipeline"""
        # Validate
        is_valid, _ = ImageService.validate_image_bytes(sample_image_bytes)
        assert is_valid
        
        # Optimize
        optimized = await ImageService.optimize_image(sample_image_bytes)
        assert optimized is not None
        
        # Verify optimization reduced size or maintained quality
        assert len(optimized) > 0
    
    @pytest.mark.asyncio
    @pytest.mark.slow
    async def test_ocr_pipeline(self, sample_image_bytes):
        """Test OCR pipeline"""
        # Validate
        is_valid, _ = OCRService.validate_image(sample_image_bytes)
        assert is_valid
        
        # Extract
        result = await OCRService.extract_text(
            sample_image_bytes,
            language='en'
        )
        
        assert result['raw_text'] is not None
        assert result['confidence'] > 0
    
    @pytest.mark.asyncio
    async def test_memory_no_temp_files(self, sample_image_bytes):
        """Verify no temporary files are created"""
        import tempfile
        import os
        
        # Get initial temp dir contents
        temp_dir = tempfile.gettempdir()
        initial_files = set(os.listdir(temp_dir))
        
        # Run optimization (should work in-memory)
        await ImageService.optimize_image(sample_image_bytes)
        
        # Check no new files were created
        final_files = set(os.listdir(temp_dir))
        assert initial_files == final_files, "Temporary files were created!"
    
    @pytest.mark.asyncio
    async def test_large_image_handling(self, large_image_bytes):
        """Test handling of large images"""
        # Validate
        is_valid, _ = ImageService.validate_image_bytes(large_image_bytes)
        assert is_valid
        
        # Optimize (should resize)
        optimized = await ImageService.optimize_image(
            large_image_bytes,
            max_width=1024,
            max_height=1024
        )
        
        assert optimized is not None
        # Optimized should be smaller than original
        assert len(optimized) < len(large_image_bytes)


# Pytest markers
def pytest_configure(config):
    config.addinivalue_line("markers", "slow: marks tests as slow (OCR tests)")
