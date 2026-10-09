import re
from typing import List, Dict, Any, Optional
from backend.app.services.normalization import (
    normalize_medication_name,
    normalize_dose,
    normalize_frequency,
    is_no_known_allergies,
    parse_clinical_date,
    normalize_lab_value
)

# Known clinical terms for high-precision extraction
COMMON_ALLERGIES = [
    "penicillin", "amoxicillin", "sulfa", "sulfonamides", "aspirin", 
    "codeine", "latex", "peanuts", "contrast dye", "iodine", "nsaids", "morphine"
]

COMMON_DIAGNOSES = [
    "type 1 diabetes mellitus", "type 1 diabetes", "t1dm",
    "type 2 diabetes mellitus", "type 2 diabetes", "t2dm", "diabetes mellitus",
    "essential hypertension", "primary hypertension", "hypertension", "htn",
    "pulmonary arterial hypertension", "pulmonary hypertension", "pah",
    "atrial fibrillation", "afib", "a-fib",
    "coronary artery disease", "cad",
    "asthma", "copd", "chronic kidney disease", "ckd",
    "hyperlipidemia", "hypothyroidism", "major depressive disorder", "anemia"
]

DISCONTINUATION_MARKERS = [
    r"discontinued", r"d/c'?d?", r"stopped", r"ceased", r"withdrawn", r"held"
]

NEGATION_MARKERS = [
    r"no\s+evidence\s+of", r"denies", r"negative\s+for", r"ruled\s+out",
    r"without", r"no\s+history\s+of", r"absence\s+of"
]

def extract_allergies_from_text(text: str, page_num: Optional[int] = None) -> List[Dict[str, Any]]:
    results = []
    
    # 1. Check for explicit negative allergy statements (NKDA)
    nkda_match = re.search(r"(?:Allergies|Allergy(?:\s+History)?):?\s*([^\n\r]+)", text, re.IGNORECASE)
    if nkda_match:
        content = nkda_match.group(1).strip()
        start = nkda_match.start(1)
        end = nkda_match.end(1)
        if is_no_known_allergies(content):
            results.append({
                "category": "ALLERGY",
                "raw_statement": nkda_match.group(0),
                "normalized_field": "Allergies",
                "normalized_value": "NO_KNOWN_ALLERGIES",
                "normalized_unit": None,
                "normalized_frequency": None,
                "status": "NEGATED",
                "page_number": page_num,
                "char_offset_start": start,
                "char_offset_end": end,
                "extraction_method": "REGEX_RULE",
                "extraction_confidence": 0.98
            })
            return results

    # Global scan for NKDA phrases
    for line in text.splitlines():
        if is_no_known_allergies(line):
            idx = text.find(line)
            results.append({
                "category": "ALLERGY",
                "raw_statement": line.strip(),
                "normalized_field": "Allergies",
                "normalized_value": "NO_KNOWN_ALLERGIES",
                "normalized_unit": None,
                "normalized_frequency": None,
                "status": "NEGATED",
                "page_number": page_num,
                "char_offset_start": max(0, idx),
                "char_offset_end": max(0, idx + len(line)),
                "extraction_method": "REGEX_RULE",
                "extraction_confidence": 0.96
            })
            return results

    # 2. Check for positive allergy mentions
    for allergy in COMMON_ALLERGIES:
        # e.g., "Penicillin allergy", "Allergic to Penicillin", "Allergies: Penicillin (hives)"
        patterns = [
            rf"\b{allergy}\b\s+allergy",
            rf"allergic\s+to\s+\b{allergy}\b",
            rf"allergy\s+(?:to\s+)?\b{allergy}\b"
        ]
        for pat in patterns:
            match = re.search(pat, text, re.IGNORECASE)
            if match:
                # Capture containing line for exact verbatim excerpt
                line_start = text.rfind("\n", 0, match.start())
                line_start = 0 if line_start == -1 else line_start + 1
                line_end = text.find("\n", match.end())
                line_end = len(text) if line_end == -1 else line_end
                raw_excerpt = text[line_start:line_end].strip() or match.group(0).strip()
                
                results.append({
                    "category": "ALLERGY",
                    "raw_statement": raw_excerpt,
                    "normalized_field": "Allergies",
                    "normalized_value": allergy.lower(),
                    "normalized_unit": None,
                    "normalized_frequency": None,
                    "status": "PRESENT",
                    "page_number": page_num,
                    "char_offset_start": match.start(),
                    "char_offset_end": match.end(),
                    "extraction_method": "DICTIONARY_PATTERN",
                    "extraction_confidence": 0.95
                })
                break

    return results

def extract_medications_from_text(text: str, page_num: Optional[int] = None) -> List[Dict[str, Any]]:
    results = []
    # Medication pattern: [Drug Name] [Dose] [Unit] [Frequency/Route]
    med_pattern = re.compile(
        r"\b([A-Za-z\-]+)\s+(\d+(?:\.\d+)?)\s*(mg|mcg|microgram|micrograms|g|gram|grams|ml|units?)\b\s*([A-Za-z0-9\s\.\/]+)?",
        re.IGNORECASE
    )
    
    for match in med_pattern.finditer(text):
        drug_raw = match.group(1).lower()
        norm_drug = normalize_medication_name(drug_raw)
        
        from backend.app.services.normalization import MEDICATION_MAP
        if norm_drug not in MEDICATION_MAP and drug_raw not in ["insulin", "gabapentin", "sertraline", "levothyroxine"]:
            continue
            
        dose_val = match.group(2)
        dose_unit = match.group(3)
        trailing_text = (match.group(4) or "").split("\n")[0].strip()
        
        # Determine status: discontinued vs active
        full_line = text[max(0, match.start()-30):min(len(text), match.end()+50)]
        is_disc = any(re.search(r"\b" + m + r"\b", full_line, re.IGNORECASE) for m in DISCONTINUATION_MARKERS)
        
        status = "DISCONTINUED" if is_disc else "PRESENT"
        norm_val, norm_unit = normalize_dose(dose_val, dose_unit)
        norm_freq = normalize_frequency(trailing_text)
        
        # Capture line excerpt for verbatim evidence
        line_start = text.rfind("\n", 0, match.start())
        line_start = 0 if line_start == -1 else line_start + 1
        line_end = text.find("\n", match.end())
        line_end = len(text) if line_end == -1 else line_end
        raw_excerpt = text[line_start:line_end].strip() or match.group(0).strip()
        
        results.append({
            "category": "MEDICATION",
            "raw_statement": raw_excerpt,
            "normalized_field": norm_drug,
            "normalized_value": f"{norm_val} {norm_unit}".strip() if norm_val is not None else dose_val,
            "normalized_unit": norm_unit,
            "normalized_frequency": norm_freq,
            "status": status,
            "page_number": page_num,
            "char_offset_start": match.start(),
            "char_offset_end": match.end(),
            "extraction_method": "STRUCTURED_MED_PARSER",
            "extraction_confidence": 0.94
        })
    return results

def extract_diagnoses_from_text(text: str, page_num: Optional[int] = None) -> List[Dict[str, Any]]:
    results = []
    for diag in COMMON_DIAGNOSES:
        pattern = rf"\b{re.escape(diag)}\b"
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            # Check negation
            preceding = text[max(0, match.start()-40):match.start()]
            is_neg = any(re.search(rf"\b{neg}\b", preceding, re.IGNORECASE) for neg in NEGATION_MARKERS)
            status = "NEGATED" if is_neg else "PRESENT"
            
            # Standardize field name with clinical precision
            diag_lower = diag.lower()
            if "type 1" in diag_lower or "t1dm" in diag_lower:
                canonical_diag = "Type 1 Diabetes Mellitus"
            elif "type 2" in diag_lower or "t2dm" in diag_lower or "diabetes" in diag_lower:
                canonical_diag = "Type 2 Diabetes Mellitus"
            elif "pulmonary" in diag_lower:
                canonical_diag = "Pulmonary Hypertension"
            elif "hypertension" in diag_lower or "htn" in diag_lower:
                canonical_diag = "Essential Hypertension"
            elif "coronary" in diag_lower or diag_lower == "cad":
                canonical_diag = "Coronary Artery Disease"
            elif "atrial fibrillation" in diag_lower or "afib" in diag_lower:
                canonical_diag = "Atrial Fibrillation"
            else:
                canonical_diag = diag.title()
            
            # Extract sentence or clean line containing the match
            line_start = text.rfind("\n", 0, match.start())
            line_start = 0 if line_start == -1 else line_start + 1
            line_end = text.find("\n", match.end())
            line_end = len(text) if line_end == -1 else line_end
            raw_sentence = text[line_start:line_end].strip()
            if not raw_sentence:
                raw_sentence = match.group(0).strip()
            
            results.append({
                "category": "DIAGNOSIS",
                "raw_statement": raw_sentence,
                "normalized_field": canonical_diag,
                "normalized_value": "PRESENT" if status == "PRESENT" else "ABSENT",
                "normalized_unit": None,
                "normalized_frequency": None,
                "status": status,
                "page_number": page_num,
                "char_offset_start": match.start(),
                "char_offset_end": match.end(),
                "extraction_method": "DIAGNOSIS_LEXICON",
                "extraction_confidence": 0.92
            })
    return results

def extract_labs_from_text(text: str, page_num: Optional[int] = None) -> List[Dict[str, Any]]:
    results = []
    # Lab tests: Hemoglobin, HbA1c, Potassium, Creatinine, Fasting Glucose
    lab_patterns = [
        (r"(?:Hemoglobin|Hgb)\s*:?\s*(\d+(?:\.\d+)?)\s*(g/dL|g/L)", "Hemoglobin"),
        (r"(?:HbA1c|Hemoglobin\s+A1c|Glycated\s+Hemoglobin)\s*:?\s*(\d+(?:\.\d+)?)\s*(%)", "HbA1c"),
        (r"(?:Potassium|K\+?)\s*:?\s*(\d+(?:\.\d+)?)\s*(mEq/L|mmol/L)", "Potassium"),
        (r"(?:Serum\s+Creatinine|Creatinine)\s*:?\s*(\d+(?:\.\d+)?)\s*(mg/dL|umol/L)", "Creatinine"),
        (r"(?:Fasting\s+Glucose|Blood\s+Glucose|Glucose)\s*:?\s*(\d+(?:\.\d+)?)\s*(mg/dL|mmol/L)", "Blood Glucose"),
    ]
    
    for pat, test_name in lab_patterns:
        match = re.search(pat, text, re.IGNORECASE)
        if match:
            raw_val = float(match.group(1))
            raw_unit = match.group(2)
            norm_val, norm_unit = normalize_lab_value(test_name, raw_val, raw_unit)
            
            # Verbatim line excerpt
            line_start = text.rfind("\n", 0, match.start())
            line_start = 0 if line_start == -1 else line_start + 1
            line_end = text.find("\n", match.end())
            line_end = len(text) if line_end == -1 else line_end
            raw_line = text[line_start:line_end].strip() or match.group(0)
            
            results.append({
                "category": "LAB_RESULT",
                "raw_statement": raw_line,
                "normalized_field": test_name,
                "normalized_value": str(norm_val),
                "normalized_unit": norm_unit,
                "normalized_frequency": None,
                "status": "PRESENT",
                "page_number": page_num,
                "char_offset_start": match.start(),
                "char_offset_end": match.end(),
                "extraction_method": "STRUCTURED_LAB_PARSER",
                "extraction_confidence": 0.95
            })
    return results

def extract_all_clinical_statements(text: str, page_num: Optional[int] = None) -> List[Dict[str, Any]]:
    statements = []
    statements.extend(extract_allergies_from_text(text, page_num))
    statements.extend(extract_medications_from_text(text, page_num))
    statements.extend(extract_diagnoses_from_text(text, page_num))
    statements.extend(extract_labs_from_text(text, page_num))
    return statements
