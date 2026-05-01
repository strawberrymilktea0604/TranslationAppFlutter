import pytest
import cv2
import numpy as np
import io
from PIL import Image, ExifTags
from app.services.image_service import ImageService
from app.services.paddle_ocr_service import PaddleOCRService

@pytest.fixture
def sample_image_bytes():
    # Create a simple RGB image
    img = Image.new('RGB', (100, 100), color='blue')
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG')
    return img_byte_arr.getvalue()

@pytest.fixture
def image_with_exif_rotation():
    """Create an image with EXIF orientation tag = 3 (Rotate 180)"""
    img = Image.new('RGB', (100, 50), color='red')
    
    # We will just patch auto_rotate_image for the complex EXIF part, 
    # or we can construct a basic EXIF dictionary.
    # ExifTags.TAGS maps id to name. We need the id for "Orientation".
    orientation_key = next(k for k, v in ExifTags.TAGS.items() if v == 'Orientation')
    
    exif_dict = {orientation_key: 3} # 3 means 180 degrees
    
    img_byte_arr = io.BytesIO()
    
    # PIL's save allows passing exif as bytes.
    # A simple way to test auto_rotate_image is to just pass a mock if needed, 
    # but let's test it directly by mocking Image.open inside the function to return our manipulated EXIF.
    return img

def test_auto_rotate_image_no_exif(sample_image_bytes):
    # Should return original bytes if no EXIF
    result = ImageService.auto_rotate_image(sample_image_bytes)
    assert result == sample_image_bytes

def test_preprocess_for_ocr(sample_image_bytes):
    # Test that preprocess_for_ocr successfully runs and returns PNG bytes
    result_bytes = ImageService.preprocess_for_ocr(sample_image_bytes)
    
    assert isinstance(result_bytes, bytes)
    
    # Verify it is a valid image (PNG)
    img = Image.open(io.BytesIO(result_bytes))
    assert img.format == 'PNG'
    # Grayscale image converted to PNG usually loads as 'L' or 'RGB'.
    # Just checking it loads successfully is sufficient.

def test_paddle_ocr_light_preprocess():
    # Test PaddleOCRService._light_preprocess
    # Create a dummy BGR image (OpenCV format)
    # 100x100 pixels, 3 channels
    dummy_bgr = np.full((100, 100, 3), 128, dtype=np.uint8)
    
    result = PaddleOCRService._light_preprocess(dummy_bgr)
    
    # Should return a numpy array of same shape
    assert isinstance(result, np.ndarray)
    assert result.shape == (100, 100, 3)
    assert result.dtype == np.uint8

@pytest.mark.asyncio
async def test_optimize_image(sample_image_bytes):
    # Test optimize_image downscales and compresses
    result_bytes = await ImageService.optimize_image(
        sample_image_bytes,
        max_width=50,
        max_height=50,
        quality=50
    )
    
    assert isinstance(result_bytes, bytes)
    img = Image.open(io.BytesIO(result_bytes))
    assert img.size == (50, 50)  # Downscaled

def test_image_validation(sample_image_bytes):
    is_valid, msg = ImageService.validate_image_bytes(sample_image_bytes)
    assert is_valid is True
    assert msg == "Image is valid"

def test_image_validation_invalid():
    # Pass random bytes that are not an image
    bad_bytes = b"Not an image file"
    is_valid, msg = ImageService.validate_image_bytes(bad_bytes)
    assert is_valid is False
    assert "Invalid image format" in msg
