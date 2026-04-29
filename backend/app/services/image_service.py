"""
Image Service - Image preprocessing and in-memory handling
Ensures images are processed in RAM and never persisted to disk
"""
import logging
import io
import hashlib
import time
from typing import Optional, Tuple, BinaryIO
from PIL import Image
import cv2
import numpy as np

logger = logging.getLogger(__name__)


class ImageError(Exception):
    """Custom exception for image operations"""
    pass


class ImageService:
    """
    Image Service for handling image preprocessing
    
    Key Features:
    - All processing done in-memory (no temporary files)
    - Automatic cleanup after processing
    - Image optimization and compression
    - Format conversion
    - Metadata stripping for security
    """
    
    MAX_IMAGE_SIZE = 10 * 1024 * 1024  # 10MB
    SUPPORTED_FORMATS = {'JPEG', 'JPG', 'PNG', 'BMP', 'TIFF', 'GIF'}
    
    @staticmethod
    async def optimize_image(
        image_bytes: bytes,
        max_width: int = 2048,
        max_height: int = 2048,
        quality: int = 85,
        strip_metadata: bool = True
    ) -> bytes:
        """
        Optimize image in-memory for faster processing.
        
        Process:
        1. Load image from bytes
        2. Resize if needed
        3. Compress/optimize
        4. Strip metadata
        5. Return optimized bytes
        
        Args:
            image_bytes: Original image bytes
            max_width: Maximum width (resize if larger)
            max_height: Maximum height (resize if larger)
            quality: JPEG compression quality (1-100, default 85)
            strip_metadata: Remove EXIF and other metadata
        
        Returns:
            Optimized image bytes
        
        Raises:
            ImageError: If optimization fails
        """
        start_time = time.time()
        
        try:
            # Load image from bytes
            image = Image.open(io.BytesIO(image_bytes))
            logger.info(f"📷 Image loaded: {image.size}, format: {image.format}")
            
            # Convert RGBA to RGB if needed
            if image.mode in ('RGBA', 'LA'):
                bg = Image.new('RGB', image.size, (255, 255, 255))
                bg.paste(image, mask=image.split()[-1])
                image = bg
            elif image.mode not in ('RGB', 'L'):
                image = image.convert('RGB')
            
            # Resize if needed
            original_size = image.size
            if image.width > max_width or image.height > max_height:
                image.thumbnail((max_width, max_height), Image.Resampling.LANCZOS)
                logger.info(f"📐 Resized: {original_size} → {image.size}")
            
            # Save to bytes with optimization
            output = io.BytesIO()
            
            # Use appropriate format based on original
            fmt = 'JPEG' if image.format and 'JPEG' in image.format.upper() else 'PNG'
            
            if fmt == 'JPEG':
                image.save(
                    output,
                    format='JPEG',
                    quality=quality,
                    optimize=True
                )
            else:
                image.save(
                    output,
                    format='PNG',
                    optimize=True
                )
            
            output_bytes = output.getvalue()
            
            # Calculate compression ratio
            compression_ratio = len(output_bytes) / len(image_bytes)
            processing_time = (time.time() - start_time) * 1000
            
            logger.info(
                f"✅ Image optimized: "
                f"{len(image_bytes)/1024:.1f}KB → {len(output_bytes)/1024:.1f}KB "
                f"({compression_ratio*100:.1f}%), "
                f"time: {processing_time:.1f}ms"
            )
            
            return output_bytes
            
        except Exception as e:
            raise ImageError(f"Image optimization failed: {str(e)}") from e

    @staticmethod
    async def get_image_hash(image_bytes: bytes) -> str:
        """
        Generate SHA256 hash of image for deduplication.
        
        Useful for:
        - Detecting duplicate uploads
        - Caching OCR results
        - Integrity verification
        """
        return hashlib.sha256(image_bytes).hexdigest()

    @staticmethod
    async def convert_image_format(
        image_bytes: bytes,
        target_format: str = 'PNG'
    ) -> bytes:
        """
        Convert image between formats (all in memory).
        
        Args:
            image_bytes: Original image bytes
            target_format: Target format (PNG, JPEG, BMP, etc.)
        
        Returns:
            Image bytes in new format
        """
        try:
            image = Image.open(io.BytesIO(image_bytes))
            
            # Ensure RGB for JPEG
            if target_format.upper() == 'JPEG' and image.mode != 'RGB':
                image = image.convert('RGB')
            
            output = io.BytesIO()
            image.save(output, format=target_format.upper())
            
            return output.getvalue()
            
        except Exception as e:
            raise ImageError(f"Image format conversion failed: {str(e)}") from e

    @staticmethod
    async def extract_image_metadata(image_bytes: bytes) -> dict:
        """
        Extract basic image metadata without storing to disk.
        """
        try:
            image = Image.open(io.BytesIO(image_bytes))
            
            metadata = {
                "format": image.format,
                "size": image.size,
                "width": image.width,
                "height": image.height,
                "mode": image.mode,
                "bytes": len(image_bytes),
                "estimated_text_density": await ImageService._estimate_text_density(image),
            }
            
            return metadata
            
        except Exception as e:
            raise ImageError(f"Metadata extraction failed: {str(e)}") from e

    @staticmethod
    async def _estimate_text_density(image: Image.Image) -> float:
        """
        Estimate percentage of image that might contain text.
        Uses edge detection to find text-like regions.
        """
        try:
            # Convert to grayscale
            img_array = np.array(image.convert('L'))
            
            # Apply Canny edge detection
            edges = cv2.Canny(img_array, 100, 200)
            
            # Calculate text density (percentage of edge pixels)
            total_pixels = edges.size
            edge_pixels = np.count_nonzero(edges)
            text_density = (edge_pixels / total_pixels) * 100
            
            return round(text_density, 2)
            
        except Exception as e:
            logger.warning(f"Text density estimation failed: {e}")
            return 0.0

    @staticmethod
    def validate_image_bytes(image_bytes: bytes) -> Tuple[bool, str]:
        """
        Validate image bytes before processing.
        
        Checks:
        - File size
        - Magic bytes (file signature)
        - Image integrity
        """
        try:
            # Check size
            if len(image_bytes) > ImageService.MAX_IMAGE_SIZE:
                return False, f"Image exceeds {ImageService.MAX_IMAGE_SIZE/1024/1024:.0f}MB limit"
            
            # Check magic bytes
            if not ImageService._has_valid_magic_bytes(image_bytes[:12]):
                return False, "Invalid image format (bad magic bytes)"
            
            # Try to load image
            image = Image.open(io.BytesIO(image_bytes))
            image.verify()
            
            return True, "Image is valid"
            
        except Exception as e:
            return False, f"Image validation failed: {str(e)}"

    @staticmethod
    def _has_valid_magic_bytes(header: bytes) -> bool:
        """
        Check if image has valid magic bytes.
        """
        if header.startswith(b'\xFF\xD8\xFF'):  # JPEG
            return True
        if header.startswith(b'\x89PNG'):  # PNG
            return True
        if header.startswith(b'BM'):  # BMP
            return True
        if header.startswith(b'GIF'):  # GIF
            return True
        if header.startswith(b'II\x2A') or header.startswith(b'MM\x00\x2A'):  # TIFF
            return True
        
        return False

    @staticmethod
    async def cleanup_image_memory(image_bytes: Optional[bytes] = None) -> None:
        """
        Explicitly cleanup image from memory.
        (Python garbage collection handles most cases, but this ensures cleanup)
        """
        if image_bytes is not None:
            del image_bytes
        
        # Force garbage collection
        import gc
        gc.collect()
        
        logger.debug("🧹 Image memory cleaned up")
