import re
from datetime import datetime
from typing import Optional, Tuple, Dict

# Medication mappings (generic to synonyms/brands)
MEDICATION_MAP = {
    "metformin": ["metformin", "glucophage", "fortamet", "glumetza"],
    "lisinopril": ["lisinopril", "prinivil", "zestril"],
    "levothyroxine": ["levothyroxine", "synthroid", "levoxyl", "tirosint"],
    "atorvastatin": ["atorvastatin", "lipitor"],
    "amlodipine": ["amlodipine", "norvasc"],
    "amoxicillin": ["amoxicillin", "amoxil"],
    "penicillin": ["penicillin", "pen-v", "penicillin v"],
    "aspirin": ["aspirin", "acetylsalicylic acid", "asa"],
    "warfarin": ["warfarin", "coumadin"],
    "omeprazole": ["omeprazole", "prilosec"],
    "hydrochlorothiazide": ["hydrochlorothiazide", "hctz"],
    "ibuprofen": ["ibuprofen", "advil", "motrin"],
    "furosemide": ["furosemide", "lasix"],
    "losartan": ["losartan", "cozaar"],
    "pantoprazole": ["pantoprazole", "protonix"],
    "gabapentin": ["gabapentin", "neurontin"],
    "sertraline": ["sertraline", "zoloft"],
    "carvedilol": ["carvedilol", "coreg"],
    "albuterol": ["albuterol", "proair", "ventolin"],
    "montelukast": ["montelukast", "singulair"],
    "clopidogrel": ["clopidogrel", "plavix"],
    "semaglutide": ["semaglutide", "ozempic", "wegovy", "rybelsus"],
    "sacubitril/valsartan": ["sacubitril/valsartan", "entresto", "sacubitril"],
    "meropenem": ["meropenem", "merrem"],
    "pembrolizumab": ["pembrolizumab", "keytruda"],
    "rituximab": ["rituximab", "rituxan"],
    "apixaban": ["apixaban", "eliquis"],
    "rivaroxaban": ["rivaroxaban", "xarelto"],
    "empagliflozin": ["empagliflozin", "jardiance"],
    "dapagliflozin": ["dapagliflozin", "farxiga"],
    "dulaglutide": ["dulaglutide", "trulicity"],
}

# Frequency normalization dictionary
FREQUENCY_MAP = {
    "once daily": ["once daily", "daily", "qd", "q.d.", "every day", "once a day", "1x daily", "q24h", "every morning", "qam"],
    "twice daily": ["twice daily", "bid", "b.i.d.", "2x daily", "two times a day", "every 12 hours", "q12h"],
    "three times daily": ["three times daily", "tid", "t.i.d.", "3x daily", "three times a day", "q8h"],
    "four times daily": ["four times daily", "qid", "q.i.d.", "4x daily", "q6h"],
    "as needed": ["as needed", "prn", "p.r.n.", "when required"],
    "at bedtime": ["at bedtime", "qhs", "q.h.s.", "nightly", "every night"],
}

# Allergy negation indicators
NO_KNOWN_ALLERGIES_PATTERNS = [
    r"no\s+known\s+(?:drug\s+)?allergies",
    r"nkda",
    r"nka",
    r"no\s+allergies",
    r"denies\s+(?:all\s+)?allergies",
    r"no\s+history\s+of\s+allergies",
    r"patient\s+denies\s+(?:drug\s+)?allergies"
]

def normalize_medication_name(name: str) -> str:
    cleaned = name.strip().lower()
    for standard_name, synonyms in MEDICATION_MAP.items():
        for syn in synonyms:
            if syn in cleaned:
                return standard_name
    return cleaned

def normalize_dose(value_str: Optional[str], unit_str: Optional[str]) -> Tuple[Optional[float], Optional[str]]:
    """Converts dose to a standardized base (e.g. mg)."""
    if not value_str:
        return None, unit_str
    try:
        val = float(value_str)
    except ValueError:
        return None, unit_str
    
    unit = (unit_str or "").strip().lower()
    if unit in ["mcg", "microgram", "micrograms", "ug"]:
        # Convert mcg to mg
        return val / 1000.0, "mg"
    elif unit in ["g", "gram", "grams"]:
        # Convert g to mg
        return val * 1000.0, "mg"
    elif unit in ["mg", "milligram", "milligrams"]:
        return val, "mg"
    return val, unit

def normalize_frequency(freq_str: Optional[str]) -> Optional[str]:
    if not freq_str:
        return None
    cleaned = freq_str.strip().lower()
    for norm, patterns in FREQUENCY_MAP.items():
        for p in patterns:
            if re.search(r"\b" + re.escape(p) + r"\b", cleaned):
                return norm
    return cleaned

def is_no_known_allergies(text: str) -> bool:
    cleaned = text.strip().lower()
    for pat in NO_KNOWN_ALLERGIES_PATTERNS:
        if re.search(pat, cleaned):
            return True
    return False

def parse_clinical_date(date_str: Optional[str]) -> Optional[datetime]:
    if not date_str:
        return None
    date_str = date_str.strip()
    formats = [
        "%Y-%m-%d",
        "%d %B %Y",
        "%d %b %Y",
        "%B %d, %Y",
        "%b %d, %Y",
        "%m/%d/%Y",
        "%d/%m/%Y",
        "%Y/%m/%d"
    ]
    for fmt in formats:
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    # Try finding regex date inside string
    match = re.search(r"(\d{1,2})\s+(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})", date_str, re.IGNORECASE)
    if match:
        s = f"{match.group(1)} {match.group(2)} {match.group(3)}"
        for fmt in ["%d %B %Y", "%d %b %Y"]:
            try:
                return datetime.strptime(s, fmt)
            except ValueError:
                pass
    match_iso = re.search(r"(\d{4})-(\d{2})-(\d{2})", date_str)
    if match_iso:
        try:
            return datetime.strptime(match_iso.group(0), "%Y-%m-%d")
        except ValueError:
            pass
    return None

def normalize_lab_value(test_name: str, value: float, unit: str) -> Tuple[float, str]:
    """Normalize lab units (e.g. glucose mmol/L to mg/dL, Hb g/L to g/dL, creatinine umol/L to mg/dL)."""
    test = test_name.strip().lower()
    unit = unit.strip().lower()
    
    if "glucose" in test:
        if unit in ["mmol/l", "mmol/litre"]:
            return round(value * 18.0182, 1), "mg/dL"
        return round(value, 1), "mg/dL"
    
    if "hemoglobin" in test or "hgb" in test:
        if unit in ["g/l", "gram/l"]:
            return round(value / 10.0, 1), "g/dL"
        return round(value, 1), "g/dL"
        
    if "creatinine" in test:
        if unit in ["umol/l", "µmol/l", "micromol/l"]:
            return round(value / 88.4, 2), "mg/dL"
        return round(value, 2), "mg/dL"

    if "bilirubin" in test:
        if unit in ["umol/l", "µmol/l", "micromol/l"]:
            return round(value / 17.1, 2), "mg/dL"
        return round(value, 2), "mg/dL"

    if "potassium" in test or "sodium" in test:
        if unit in ["mmol/l", "meq/l"]:
            return round(value, 1), "mEq/L"
        return round(value, 1), unit

    if "calcium" in test:
        if unit in ["mmol/l"]:
            return round(value * 4.0, 1), "mg/dL"
        return round(value, 1), "mg/dL"

    if "albumin" in test:
        if unit in ["g/l"]:
            return round(value / 10.0, 1), "g/dL"
        return round(value, 1), "g/dL"

    return value, unit
