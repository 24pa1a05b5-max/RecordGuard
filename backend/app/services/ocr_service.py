import shutil
import logging
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

def is_tesseract_available() -> bool:
    """Check if tesseract binary is accessible on PATH."""
    return shutil.which("tesseract") is not None

def run_ocr_on_image(image_bytes: bytes) -> Tuple[bool, str, Optional[str]]:
    """
    Attempts OCR on image bytes using pytesseract if available.
    Returns (success, extracted_text, error_message).
    """
    if not is_tesseract_available():
        return (
            False,
            "",
            "OCR Engine (Tesseract) is not installed or not in system PATH. Install Tesseract OCR from https://github.com/UB-Mannheim/tesseract/wiki to enable scanned image OCR."
        )
    
    try:
        import pytesseract
        from PIL import Image
        import io
        
        image = Image.open(io.BytesIO(image_bytes))
        text = pytesseract.image_to_string(image)
        return (True, text, None)
    except Exception as e:
        logger.error(f"OCR execution failed: {str(e)}")
        return (False, "", f"OCR extraction failed: {str(e)}")
