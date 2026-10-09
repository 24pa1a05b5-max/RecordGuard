import hashlib
from pathlib import Path
from typing import List, Dict, Any, Tuple
import pymupdf  # modern PyMuPDF import
from backend.app.services.ocr_service import is_tesseract_available, run_ocr_on_image

def calculate_file_hash(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()

def extract_pages_from_pdf(content: bytes) -> Tuple[List[Dict[str, Any]], bool, List[str]]:
    """
    Extracts text page by page from PDF using PyMuPDF.
    Returns (pages_data, ocr_used, warnings).
    Each page contains: {page_number: int, text: str, has_text: bool}
    """
    pages_data = []
    ocr_used = False
    warnings = []
    
    doc = pymupdf.open(stream=content, filetype="pdf")
    total_pages = len(doc)
    
    for idx in range(total_pages):
        page = doc[idx]
        text = page.get_text("text").strip()
        page_num = idx + 1
        
        if len(text) > 0:
            pages_data.append({
                "page_number": page_num,
                "text": text,
                "has_text": True,
                "ocr": False
            })
        else:
            # Page has no text layer, might be scanned image
            pix = page.get_pixmap()
            img_bytes = pix.tobytes("png")
            success, ocr_text, err = run_ocr_on_image(img_bytes)
            
            if success and len(ocr_text.strip()) > 0:
                ocr_used = True
                pages_data.append({
                    "page_number": page_num,
                    "text": ocr_text.strip(),
                    "has_text": True,
                    "ocr": True
                })
            else:
                warn_msg = f"Page {page_num} contains no selectable text."
                if err:
                    warn_msg += f" {err}"
                warnings.append(warn_msg)
                pages_data.append({
                    "page_number": page_num,
                    "text": "",
                    "has_text": False,
                    "ocr": False
                })
                
    doc.close()
    return pages_data, ocr_used, warnings

def extract_pages_from_txt(content: bytes) -> Tuple[List[Dict[str, Any]], bool, List[str]]:
    """
    Extracts text from UTF-8 / ASCII text document.
    Plain text documents lack physical page structures, so page_number is None
    to avoid fabricating pagination metadata.
    """
    text = content.decode("utf-8", errors="replace").strip()
    return [{
        "page_number": None,
        "text": text,
        "has_text": len(text) > 0,
        "ocr": False
    }], False, []
