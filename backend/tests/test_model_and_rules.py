import pytest
from backend.app.services.ml_classifier import ml_service
from backend.app.services.contradiction_rules import evaluate_statement_pair, check_missing_information_findings
from backend.app.services.normalization import normalize_lab_value, normalize_dose, normalize_medication_name

# =====================================================================
# 1. NEGATION TESTS
# =====================================================================
def test_allergy_presence_vs_negation():
    """Allergy present in one record and explicitly negated in another."""
    stmt_a = {
        "category": "ALLERGY",
        "normalized_field": "penicillin",
        "normalized_value": "penicillin",
        "status": "PRESENT",
        "raw_statement": "Documented penicillin allergy with history of anaphylaxis."
    }
    stmt_b = {
        "category": "ALLERGY",
        "normalized_field": "penicillin",
        "normalized_value": "penicillin",
        "status": "NEGATED",
        "raw_statement": "Patient denies any known drug allergies (NKDA)."
    }
    meta_a = {"document_date": "2026-01-10"}
    meta_b = {"document_date": "2026-01-10"}

    rule_res = evaluate_statement_pair(stmt_a, stmt_b, meta_a, meta_b)
    assert rule_res is not None
    assert rule_res["classification"] == "POTENTIAL_CONTRADICTION"
    assert rule_res["priority_level"] == "PRIORITY_REVIEW"

    # ML Classifier check
    pred, conf = ml_service.predict(
        category="ALLERGY",
        statement_a=stmt_a["raw_statement"],
        statement_b=stmt_b["raw_statement"],
        norm_val_a="penicillin",
        norm_val_b="penicillin",
        date_a="2026-01-10",
        date_b="2026-01-10"
    )
    assert pred == "POTENTIAL_CONTRADICTION"
    assert conf > 0.50

def test_concordant_negations():
    """Both documents confirm no known allergies."""
    stmt_a = {
        "category": "ALLERGY",
        "normalized_field": "penicillin",
        "normalized_value": "penicillin",
        "status": "NEGATED",
        "raw_statement": "Allergies: No known drug allergies."
    }
    stmt_b = {
        "category": "ALLERGY",
        "normalized_field": "penicillin",
        "normalized_value": "penicillin",
        "status": "NEGATED",
        "raw_statement": "Patient confirms NKDA upon admission."
    }
    meta_a = {"document_date": "2026-01-10"}
    meta_b = {"document_date": "2026-02-10"}

    rule_res = evaluate_statement_pair(stmt_a, stmt_b, meta_a, meta_b)
    assert rule_res is not None
    assert rule_res["classification"] == "NO_CONTRADICTION"

def test_chronic_diagnosis_presence_vs_denial():
    """Chronic diagnosis affirmed in Doc A and denied in Doc B."""
    stmt_a = {
        "category": "DIAGNOSIS",
        "normalized_field": "type 2 diabetes",
        "normalized_value": "PRESENT",
        "status": "PRESENT",
        "raw_statement": "Assessment: Type 2 Diabetes Mellitus with peripheral neuropathy."
    }
    stmt_b = {
        "category": "DIAGNOSIS",
        "normalized_field": "type 2 diabetes",
        "normalized_value": "NEGATED",
        "status": "NEGATED",
        "raw_statement": "Denies history of diabetes mellitus or hyperglycemia."
    }
    meta_a = {"document_date": "2026-01-10"}
    meta_b = {"document_date": "2026-01-10"}

    rule_res = evaluate_statement_pair(stmt_a, stmt_b, meta_a, meta_b)
    assert rule_res is not None
    assert rule_res["classification"] == "POTENTIAL_CONTRADICTION"

# =====================================================================
# 2. DATES & TEMPORAL CONTEXT TESTS
# =====================================================================
def test_medication_discontinuation_over_time():
    """Medication active in earlier encounter, discontinued in subsequent note."""
    stmt_a = {
        "category": "MEDICATION",
        "normalized_field": "lisinopril",
        "normalized_value": "10 mg",
        "status": "PRESENT",
        "raw_statement": "Prescribed Lisinopril 10 mg daily for blood pressure."
    }
    stmt_b = {
        "category": "MEDICATION",
        "normalized_field": "lisinopril",
        "normalized_value": "10 mg",
        "status": "DISCONTINUED",
        "raw_statement": "Lisinopril discontinued due to persistent dry cough."
    }
    meta_a = {"document_date": "2026-01-05"}
    meta_b = {"document_date": "2026-02-20"} # 46 days later

    rule_res = evaluate_statement_pair(stmt_a, stmt_b, meta_a, meta_b)
    assert rule_res is not None
    assert rule_res["classification"] == "TEMPORAL_CHANGE"

def test_medication_dosage_titration_over_time():
    """Dose adjustment across separate encounters is a temporal progression, not contradiction."""
    stmt_a = {
        "category": "MEDICATION",
        "normalized_field": "metformin",
        "normalized_value": "500 mg",
        "status": "PRESENT",
        "raw_statement": "Emergency Department Record (2026-01-05): Initiated Metformin at starter dose of 500 mg daily."
    }
    stmt_b = {
        "category": "MEDICATION",
        "normalized_field": "metformin",
        "normalized_value": "1000 mg",
        "status": "PRESENT",
        "raw_statement": "Primary Care Annual Wellness Note (2026-02-15): Therapeutic monitoring: Metformin titrated up to 1000 mg daily."
    }
    meta_a = {"document_date": "2026-01-05"}
    meta_b = {"document_date": "2026-02-15"} # 41 days later

    rule_res = evaluate_statement_pair(stmt_a, stmt_b, meta_a, meta_b)
    assert rule_res is not None
    assert rule_res["classification"] == "TEMPORAL_CHANGE"

    # ML Classifier check on standard chronological record
    pred, conf = ml_service.predict(
        category="MEDICATION",
        statement_a=stmt_a["raw_statement"],
        statement_b=stmt_b["raw_statement"],
        norm_val_a="500 mg",
        norm_val_b="1000 mg",
        date_a="2026-01-05",
        date_b="2026-02-15"
    )
    assert pred == "TEMPORAL_CHANGE"
    assert conf > 0.80

    # Borderline phrasing check: verifies that low-margin cases are correctly flagged as uncertain
    res_borderline = ml_service.predict_detailed(
        category="MEDICATION",
        statement_a="Metformin 500 mg daily.",
        statement_b="Metformin increased to 1000 mg daily.",
        norm_val_a="500 mg",
        norm_val_b="1000 mg",
        date_a="2026-01-05",
        date_b="2026-02-15"
    )
    assert res_borderline is not None
    assert "is_uncertain" in res_borderline

def test_same_day_unexplained_dosage_discrepancy():
    """Conflicting orders on the same day without chronological rationale."""
    stmt_a = {
        "category": "MEDICATION",
        "normalized_field": "metformin",
        "normalized_value": "500 mg",
        "status": "PRESENT",
        "raw_statement": "Clinic Note: Continue Metformin 500 mg daily."
    }
    stmt_b = {
        "category": "MEDICATION",
        "normalized_field": "metformin",
        "normalized_value": "1000 mg",
        "status": "PRESENT",
        "raw_statement": "Consult Note: Current order is Metformin 1000 mg daily."
    }
    meta_a = {"document_date": "2026-01-15"}
    meta_b = {"document_date": "2026-01-15"} # Same day

    rule_res = evaluate_statement_pair(stmt_a, stmt_b, meta_a, meta_b)
    assert rule_res is not None
    assert rule_res["classification"] == "POTENTIAL_CONTRADICTION"

# =====================================================================
# 3. UNITS & CONVERSIONS TESTS
# =====================================================================
def test_creatinine_unit_conversion():
    """Serum Creatinine 1.2 mg/dL is equivalent to 106.1 umol/L."""
    norm_mg, u_mg = normalize_lab_value("serum creatinine", 1.2, "mg/dL")
    norm_umol, u_umol = normalize_lab_value("serum creatinine", 106.08, "umol/L")
    assert u_mg == "mg/dL"
    assert u_umol == "mg/dL"
    assert abs(norm_mg - norm_umol) < 0.05

    stmt_a = {
        "category": "LAB_RESULT",
        "normalized_field": "serum creatinine",
        "normalized_value": "1.2",
        "normalized_unit": "mg/dL",
        "raw_statement": "Serum Creatinine: 1.2 mg/dL."
    }
    stmt_b = {
        "category": "LAB_RESULT",
        "normalized_field": "serum creatinine",
        "normalized_value": "106.1",
        "normalized_unit": "umol/L",
        "raw_statement": "Serum Creatinine: 106.1 umol/L."
    }
    rule_res = evaluate_statement_pair(stmt_a, stmt_b, {"document_date": "2026-01-10"}, {"document_date": "2026-01-10"})
    assert rule_res is not None
    assert rule_res["classification"] == "NO_CONTRADICTION"

def test_hemoglobin_unit_conversion():
    """Hemoglobin 13.5 g/dL is equivalent to 135.0 g/L."""
    norm_a, u_a = normalize_lab_value("hemoglobin", 13.5, "g/dL")
    norm_b, u_b = normalize_lab_value("hemoglobin", 135.0, "g/L")
    assert norm_a == norm_b == 13.5
    assert u_a == u_b == "g/dL"

def test_dose_mcg_to_mg_conversion():
    """Levothyroxine 50 mcg is equivalent to 0.05 mg."""
    dose_a, u_a = normalize_dose("50", "mcg")
    dose_b, u_b = normalize_dose("0.05", "mg")
    assert abs(dose_a - dose_b) < 1e-4
    assert u_a == u_b == "mg"

# =====================================================================
# 4. SYNONYMS & BRAND/GENERIC TESTS
# =====================================================================
def test_brand_generic_equivalence():
    """Lasix and Furosemide are the same drug."""
    assert normalize_medication_name("Lasix") == "furosemide"
    assert normalize_medication_name("Furosemide") == "furosemide"
    assert normalize_medication_name("Entresto") == "sacubitril/valsartan"
    assert normalize_medication_name("Lipitor") == "atorvastatin"

def test_brand_generic_reconciliation():
    """Discharge on Furosemide 20mg vs Dispensed Lasix 20mg is concordant."""
    stmt_a = {
        "category": "MEDICATION",
        "normalized_field": "furosemide",
        "normalized_value": "20",
        "normalized_unit": "mg",
        "raw_statement": "Discharged on Furosemide 20 mg daily."
    }
    stmt_b = {
        "category": "MEDICATION",
        "normalized_field": "lasix",
        "normalized_value": "20",
        "normalized_unit": "mg",
        "raw_statement": "Pharmacy record shows Lasix 20 mg daily."
    }
    rule_res = evaluate_statement_pair(stmt_a, stmt_b, {"document_date": "2026-01-10"}, {"document_date": "2026-01-10"})
    assert rule_res is not None
    assert rule_res["classification"] == "NO_CONTRADICTION"

# =====================================================================
# 5. CLINICALLY COMPATIBLE STATEMENTS (FALSE ALARM PREVENTION)
# =====================================================================
def test_distinct_allergies_are_not_contradictory():
    """Having Penicillin allergy and Sulfa allergy are compatible; neither contradicts the other."""
    stmt_a = {
        "category": "ALLERGY",
        "normalized_field": "penicillin",
        "normalized_value": "penicillin",
        "status": "PRESENT",
        "raw_statement": "Known allergy to Penicillin."
    }
    stmt_b = {
        "category": "ALLERGY",
        "normalized_field": "sulfa",
        "normalized_value": "sulfa",
        "status": "PRESENT",
        "raw_statement": "Known allergy to Sulfa drugs."
    }
    # When evaluated together, distinct allergies should NOT trigger a contradiction finding!
    rule_res = evaluate_statement_pair(stmt_a, stmt_b, {"document_date": "2026-01-10"}, {"document_date": "2026-01-10"})
    assert rule_res is None # No contradiction between distinct allergies

# =====================================================================
# 6. INSUFFICIENT EVIDENCE & OMISSION TESTS
# =====================================================================
def test_omission_is_insufficient_evidence():
    """Unreviewed or omitted section must return INSUFFICIENT_EVIDENCE."""
    stmt_a = {
        "category": "ALLERGY",
        "normalized_field": "penicillin",
        "normalized_value": "penicillin",
        "status": "PRESENT",
        "raw_statement": "Confirmed Penicillin allergy."
    }
    stmt_b = {
        "category": "ALLERGY",
        "normalized_field": "penicillin",
        "normalized_value": "UNMENTIONED",
        "status": "PRESENT",
        "raw_statement": "Focused orthopedic encounter; allergy section unreviewed."
    }
    rule_res = evaluate_statement_pair(stmt_a, stmt_b, {"document_date": "2026-01-10"}, {"document_date": "2026-01-10"})
    assert rule_res is not None
    assert rule_res["classification"] == "INSUFFICIENT_EVIDENCE"
    assert rule_res["priority_level"] == "AWAITING_EVIDENCE"

def test_missing_information_helper():
    """Doc A has allergies, Doc B omits allergy section completely."""
    doc_a_stmts = [{
        "category": "ALLERGY",
        "status": "PRESENT",
        "raw_statement": "Penicillin allergy documented.",
        "page_number": 1
    }]
    doc_b_stmts = [] # Completely omitted in Doc B
    findings = check_missing_information_findings(doc_a_stmts, doc_b_stmts, {}, {})
    assert len(findings) == 1
    assert findings[0]["classification"] == "INSUFFICIENT_EVIDENCE"
    assert "omission" in findings[0]["explanation"].lower()

# =====================================================================
# 7. CAUTIOUS CONFIDENCE & HUMAN REVIEW FLAGGING
# =====================================================================
def test_cautious_confidence_on_uncertain_prediction():
    """ML detailed prediction exposes uncertainty margin and non-diagnostic disclaimer."""
    res = ml_service.predict_detailed(
        category="MEDICATION",
        statement_a="Patient prescribed unknown compound daily.",
        statement_b="Medication list unclear; pending reconciliation.",
        date_a=None,
        date_b=None
    )
    assert res is not None
    assert "disclaimer" in res
    assert "confidence" in res
    assert "all_probabilities" in res
