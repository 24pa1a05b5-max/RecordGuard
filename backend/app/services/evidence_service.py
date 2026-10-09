from typing import Dict, Any, Tuple, Optional

def verify_evidence_snippet(
    doc_full_text: str,
    snippet: str
) -> Tuple[bool, Optional[int]]:
    """
    Validates that the quoted evidence snippet actually exists verbatim or near-verbatim
    in the document text. Returns (is_verified, start_char_index).
    """
    if not snippet or snippet.startswith("[No "):
        # Placeholder for omitted sections
        return True, None
        
    cleaned_snippet = snippet.strip()
    if cleaned_snippet in doc_full_text:
        return True, doc_full_text.find(cleaned_snippet)
    
    # Try case-insensitive fallback
    lower_text = doc_full_text.lower()
    lower_snippet = cleaned_snippet.lower()
    if lower_snippet in lower_text:
        return True, lower_text.find(lower_snippet)
        
    return False, None

def assess_evidence_quality(
    snippet_a: str,
    snippet_b: str,
    doc_a_text: str,
    doc_b_text: str,
    page_a: Optional[int],
    page_b: Optional[int],
    date_a: Optional[str],
    date_b: Optional[str]
) -> Dict[str, float]:
    """
    Computes evidence completeness score and traceability score based on
    actual source verification rather than arbitrary estimates.
    """
    verified_a, _ = verify_evidence_snippet(doc_a_text, snippet_a)
    verified_b, _ = verify_evidence_snippet(doc_b_text, snippet_b)
    
    # Traceability: 0.5 per verified source snippet + page
    trace_score = 0.0
    if verified_a and page_a is not None:
        trace_score += 0.5
    elif verified_a:
        trace_score += 0.35
        
    if verified_b and page_b is not None:
        trace_score += 0.5
    elif verified_b:
        trace_score += 0.35
        
    # Completeness: checks whether dates, statements, and sources are present
    comp_score = 0.0
    if snippet_a and not snippet_a.startswith("[No "):
        comp_score += 0.3
    if snippet_b and not snippet_b.startswith("[No "):
        comp_score += 0.3
    if date_a:
        comp_score += 0.2
    if date_b:
        comp_score += 0.2
        
    return {
        "completeness_score": round(min(1.0, comp_score), 2),
        "traceability_score": round(min(1.0, trace_score), 2),
        "verified_a": verified_a,
        "verified_b": verified_b
    }
