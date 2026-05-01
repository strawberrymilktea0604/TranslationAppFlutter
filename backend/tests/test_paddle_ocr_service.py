import pytest
from unittest.mock import patch, MagicMock
from app.services.paddle_ocr_service import PaddleOCRService, PaddleOCRError
from app.services.ocr_service import OCRService, OCRError
import numpy as np
from PIL import Image
import io

@pytest.fixture
def sample_image_bytes():
    # Create a simple dummy image
    img = Image.new('RGB', (100, 100), color = 'white')
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='PNG')
    return img_byte_arr.getvalue()

@pytest.fixture
def mock_paddle_ocr():
    with patch("app.services.paddle_ocr_service.PaddleOCRService._get_ocr_engine") as mock_get_engine:
        mock_engine = MagicMock()
        mock_get_engine.return_value = mock_engine
        
        # Mock OCR output format: list of list of [box, (text, confidence)]
        # Result has page output as first element
        mock_engine.ocr.return_value = [
            [
                [[[10, 10], [50, 10], [50, 20], [10, 20]], ("Xin chào", 0.95)],
                [[[10, 30], [50, 30], [50, 40], [10, 40]], ("thế giới", 0.90)]
            ]
        ]
        yield mock_get_engine, mock_engine

@pytest.mark.asyncio
async def test_paddle_ocr_service_extract_text(sample_image_bytes, mock_paddle_ocr):
    mock_get_engine, mock_engine = mock_paddle_ocr
    
    result = await PaddleOCRService.extract_text(
        image_bytes=sample_image_bytes,
        language="vi",
        preprocess=False
    )
    
    # Assert engine called
    mock_get_engine.assert_called_once_with("vi")
    mock_engine.ocr.assert_called_once()
    
    # Assert result structure
    assert result["language"] == "vi"
    assert "Xin chào\nthế giới" in result["raw_text"]
    assert result["confidence"] == 92.5  # average of 95 and 90
    assert len(result["text_regions"]) == 2
    assert result["text_regions"][0]["text"] == "Xin chào"
    assert result["text_regions"][0]["confidence"] == 95

@pytest.mark.asyncio
async def test_paddle_ocr_service_handles_empty_result(sample_image_bytes, mock_paddle_ocr):
    mock_get_engine, mock_engine = mock_paddle_ocr
    mock_engine.ocr.return_value = [[]] # Empty result
    
    result = await PaddleOCRService.extract_text(
        image_bytes=sample_image_bytes,
        language="en"
    )
    
    assert result["raw_text"] == ""
    assert result["confidence"] == 0.0
    assert len(result["text_regions"]) == 0

@pytest.mark.asyncio
@patch("app.services.paddle_ocr_service.PaddleOCRService.extract_text")
async def test_ocr_service_routes_to_paddle(mock_paddle_extract, sample_image_bytes):
    mock_paddle_extract.return_value = {
        "raw_text": "Routed to Paddle",
        "confidence": 99.0,
        "language": "vi",
        "text_regions": [],
        "processing_time_ms": 10.0,
        "image_size": (100, 100)
    }
    
    result = await OCRService.extract_text(
        image_bytes=sample_image_bytes,
        language="vi",
        engine="paddleocr"
    )
    
    mock_paddle_extract.assert_called_once_with(
        image_bytes=sample_image_bytes,
        language="vi",
        preprocess=True
    )
    
    assert result["raw_text"] == "Routed to Paddle"
    assert result["ocr_engine"] == "paddleocr"

@pytest.mark.asyncio
async def test_ocr_service_invalid_engine(sample_image_bytes):
    with pytest.raises(OCRError) as exc_info:
        await OCRService.extract_text(
            image_bytes=sample_image_bytes,
            engine="invalid_engine"
        )
    assert "Invalid OCR engine" in str(exc_info.value)
