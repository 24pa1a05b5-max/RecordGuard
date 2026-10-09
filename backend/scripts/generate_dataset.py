import json
import random
from pathlib import Path
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, GroupShuffleSplit

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "synthetic"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

RANDOM_SEED = 42
random.seed(RANDOM_SEED)
np.random.seed(RANDOM_SEED)

ENCOUNTERS = [
    "Hospital Discharge Summary",
    "Outpatient Clinic Progress Note",
    "Emergency Department Record",
    "Inpatient Admission H&P",
    "Subspecialty Consultation Note",
    "Urgent Care Clinical Assessment",
    "Primary Care Annual Wellness Note",
    "Pre-operative Anesthesia Assessment",
    "Post-procedure Recovery Summary",
    "Telehealth Triage Documentation"
]

ALLERGIES = [
    ("penicillin", "severe anaphylactic shock with bronchospasm", "diffuse urticaria and pruritus"),
    ("amoxicillin", "facial angioedema and shortness of breath", "erythematous maculopapular rash"),
    ("sulfa", "Stevens-Johnson syndrome with mucosal involvement", "cutaneous bullous lesions"),
    ("ciprofloxacin", "tendonitis and throat tightness", "diffuse maculopapular eruption"),
    ("aspirin", "severe bronchospasm and facial swelling", "periorbital edema and urticaria"),
    ("ibuprofen", "dyspnea and generalized hives", "lip and tongue swelling"),
    ("morphine", "severe systemic hypotension and flushing", "generalized pruritus and wheals"),
    ("codeine", "bronchospasm with cutaneous flushing", "intense full-body itching"),
    ("latex", "contact urticaria and lip angioedema", "generalized erythema"),
    ("iodine", "anaphylactoid reaction following IV contrast", "acute flushing and dyspnea"),
    ("cephalexin", "pharyngeal edema and diffuse hives", "pruritic skin eruption"),
    ("doxycycline", "severe phototoxic dermatitis", "esophageal burning and rash"),
    ("clindamycin", "diffuse urticaria and facial flushing", "erythema multiforme"),
    ("lisinopril", "life-threatening angioedema of tongue and uvula", "oropharyngeal swelling"),
    ("heparin", "heparin-induced thrombocytopenia", "systemic acute reaction"),
    ("vancomycin", "hypotension and diffuse red man flushing", "erythematous reaction"),
    ("bactrim", "severe cutaneous drug eruption", "exfoliative dermatitis"),
    ("augmentin", "lip swelling and expiratory wheezing", "macular rash on torso"),
    ("naproxen", "bronchial hyperreactivity and urticaria", "periorbital swelling"),
    ("erythromycin", "severe abdominal cramps and urticaria", "cutaneous hives"),
]

MEDICATIONS = [
    ("Metformin", "Glucophage", ["500 mg", "850 mg", "1000 mg"], ["twice daily", "once daily with dinner", "every 12 hours"], "oral"),
    ("Lisinopril", "Zestril", ["5 mg", "10 mg", "20 mg", "40 mg"], ["daily every morning", "once daily", "every 24 hours"], "oral"),
    ("Atorvastatin", "Lipitor", ["10 mg", "20 mg", "40 mg", "80 mg"], ["at bedtime", "daily in evening", "once nightly"], "oral"),
    ("Levothyroxine", "Synthroid", ["25 mcg", "50 mcg", "75 mcg", "100 mcg", "125 mcg"], ["daily before breakfast", "every morning on empty stomach", "fasting daily"], "oral"),
    ("Amlodipine", "Norvasc", ["2.5 mg", "5 mg", "10 mg"], ["once daily", "daily every morning", "every 24 hours"], "oral"),
    ("Omeprazole", "Prilosec", ["20 mg", "40 mg"], ["daily 30 min before breakfast", "once daily in morning", "daily before first meal"], "oral"),
    ("Carvedilol", "Coreg", ["3.125 mg", "6.25 mg", "12.5 mg", "25 mg"], ["twice daily with meals", "every 12 hours", "BID with food"], "oral"),
    ("Furosemide", "Lasix", ["20 mg", "40 mg", "80 mg"], ["every morning", "twice daily at 8 AM and 2 PM", "daily with breakfast"], "oral"),
    ("Apixaban", "Eliquis", ["2.5 mg", "5 mg"], ["twice daily", "every 12 hours", "BID oral"], "oral"),
    ("Clopidogrel", "Plavix", ["75 mg"], ["once daily", "daily with breakfast", "every 24 hours"], "oral"),
    ("Sertraline", "Zoloft", ["25 mg", "50 mg", "100 mg"], ["daily in the morning", "once daily at breakfast", "daily QAM"], "oral"),
    ("Albuterol", "Ventolin", ["90 mcg", "180 mcg"], ["every 4 to 6 hours PRN for dyspnea", "2 puffs inhaled as needed", "PRN for wheezing"], "inhalation"),
    ("Losartan", "Cozaar", ["25 mg", "50 mg", "100 mg"], ["once daily", "daily in morning", "every 24 hours"], "oral"),
    ("Hydrochlorothiazide", "Microzide", ["12.5 mg", "25 mg", "50 mg"], ["daily every morning", "once daily with water", "daily QAM"], "oral"),
    ("Warfarin", "Coumadin", ["2 mg", "3 mg", "5 mg", "7.5 mg"], ["once daily in the evening as per INR", "daily at 6 PM", "nightly titrated"], "oral"),
    ("Insulin Glargine", "Lantus", ["15 units", "20 units", "30 units", "40 units"], ["subcutaneously at bedtime", "once daily at 9 PM", "nightly subQ"], "subcutaneous"),
    ("Empagliflozin", "Jardiance", ["10 mg", "25 mg"], ["daily every morning", "once daily with breakfast", "daily QAM"], "oral"),
    ("Gabapentin", "Neurontin", ["100 mg", "300 mg", "600 mg"], ["three times daily", "twice daily", "TID with meals"], "oral"),
    ("Pantoprazole", "Protonix", ["40 mg"], ["once daily before breakfast", "daily in morning", "fasting QAM"], "oral"),
    ("Rosuvastatin", "Crestor", ["5 mg", "10 mg", "20 mg", "40 mg"], ["once daily at bedtime", "daily in evening", "nightly"], "oral"),
    ("Montelukast", "Singulair", ["10 mg"], ["once daily in the evening", "nightly at bedtime"], "oral"),
    ("Duloxetine", "Cymbalta", ["30 mg", "60 mg"], ["daily with food", "once daily in morning"], "oral"),
    ("Metoprolol Tartrate", "Lopressor", ["25 mg", "50 mg", "100 mg"], ["twice daily with meals", "every 12 hours BID"], "oral"),
    ("Allopurinol", "Zyloprim", ["100 mg", "300 mg"], ["once daily after meals", "daily with full glass of water"], "oral"),
    ("Finasteride", "Proscar", ["5 mg"], ["once daily", "daily in morning"], "oral")
]

DIAGNOSES = [
    ("Type 2 Diabetes Mellitus", "ICD-10 E11.9", "glycemic monitoring", "chronic endocrine"),
    ("Essential Hypertension", "ICD-10 I10", "blood pressure management", "chronic vascular"),
    ("Atrial Fibrillation", "ICD-10 I48.91", "cardiac rhythm monitoring", "paroxysmal arrhythmia"),
    ("Persistent Asthma", "ICD-10 J45.40", "airway reactivity control", "moderate pulmonary"),
    ("Hyperlipidemia", "ICD-10 E78.5", "lipid panel surveillance", "metabolic dyslipidemia"),
    ("Primary Hypothyroidism", "ICD-10 E03.9", "thyroid replacement therapy", "autoimmune endocrine"),
    ("Chronic Kidney Disease Stage 3", "ICD-10 N18.3", "renal filtration assessment", "moderate nephropathy"),
    ("Congestive Heart Failure", "ICD-10 I50.9", "volume overload monitoring", "systolic dysfunction"),
    ("Chronic Obstructive Pulmonary Disease", "ICD-10 J44.9", "airflow limitation surveillance", "obstructive lung"),
    ("Major Depressive Disorder", "ICD-10 F32.9", "psychiatric pharmacotherapy", "affective mood disorder"),
    ("Deep Vein Thrombosis", "ICD-10 I82.40", "anticoagulation surveillance", "venous thromboembolism"),
    ("Gastroesophageal Reflux Disease", "ICD-10 K21.9", "acid suppression therapy", "gastrointestinal reflux"),
    ("Rheumatoid Arthritis", "ICD-10 M06.9", "immunosuppressive surveillance", "systemic autoimmune"),
    ("Osteoarthritis", "ICD-10 M19.90", "analgesic and mobility management", "degenerative articular"),
    ("Peripheral Artery Disease", "ICD-10 I73.9", "vascular claudication management", "peripheral occlusive"),
    ("Chronic Gout", "ICD-10 M10.0", "urate lowering surveillance", "crystal arthropathy"),
    ("Obstructive Sleep Apnea", "ICD-10 G47.33", "CPAP adherence check", "respiratory sleep disorder"),
    ("Benign Prostatic Hyperplasia", "ICD-10 N40.0", "urinary symptom relief", "urologic disorder"),
    ("Generalized Anxiety Disorder", "ICD-10 F41.1", "anxiolytic medication management", "psychiatric anxiety"),
    ("Osteoporosis", "ICD-10 M81.0", "bone density preservation", "metabolic bone disease")
]

LABS = [
    ("HbA1c", [5.4, 5.7, 6.2, 6.9, 7.6, 8.4, 9.2, 10.5], "%"),
    ("Fasting Blood Glucose", [85.0, 98.0, 115.0, 134.0, 162.0, 195.0, 240.0], "mg/dL"),
    ("Serum Creatinine", [0.7, 0.9, 1.1, 1.4, 1.8, 2.3, 3.1], "mg/dL"),
    ("Hemoglobin", [9.2, 10.5, 11.8, 13.5, 14.8, 16.2], "g/dL"),
    ("Serum Potassium", [3.2, 3.6, 4.1, 4.5, 5.0, 5.4, 6.1], "mEq/L"),
    ("Serum Sodium", [128.0, 132.0, 137.0, 140.0, 143.0, 148.0], "mEq/L"),
    ("Estimated GFR", [28.0, 42.0, 58.0, 72.0, 88.0, 105.0], "mL/min/1.73m2"),
    ("Total Cholesterol", [140.0, 175.0, 205.0, 235.0, 280.0], "mg/dL"),
    ("Platelet Count", [95.0, 140.0, 220.0, 285.0, 360.0, 480.0], "10^3/uL"),
    ("Alanine Aminotransferase (ALT)", [18.0, 28.0, 42.0, 68.0, 112.0, 185.0], "U/L"),
    ("Aspartate Aminotransferase (AST)", [16.0, 24.0, 38.0, 62.0, 98.0, 160.0], "U/L"),
    ("Thyroid Stimulating Hormone (TSH)", [0.2, 1.1, 2.4, 3.8, 5.9, 9.4, 14.2], "uIU/mL"),
    ("International Normalized Ratio (INR)", [1.0, 1.5, 2.1, 2.5, 3.2, 4.4], ""),
    ("Blood Urea Nitrogen (BUN)", [11.0, 16.0, 24.0, 36.0, 48.0, 65.0], "mg/dL"),
    ("White Blood Cell Count", [3.8, 5.5, 7.2, 9.8, 12.4, 16.5], "10^3/uL"),
    ("Serum Calcium", [8.4, 8.9, 9.4, 9.9, 10.4, 11.2], "mg/dL"),
    ("Serum Albumin", [2.8, 3.4, 3.9, 4.3, 4.7], "g/dL")
]

# ==============================================================================
# GENERATOR FUNCTIONS WITH HIGH COMBINATORIAL COVERAGE
# ==============================================================================

def build_all_allergy_pairs():
    pairs = []
    
    # 1. Contradiction: Positive Allergy vs NKDA Denial
    for allergy, rxn1, rxn2 in ALLERGIES:
        for enc_a in ENCOUNTERS[:6]:
            for enc_b in ENCOUNTERS[4:]:
                d_a = f"2026-0{random.randint(1,2)}-{random.randint(1,28):02d}"
                d_b = f"2026-0{random.randint(1,2)}-{random.randint(1,28):02d}"
                s_a = f"{enc_a}: Documented allergy to {allergy.title()} ({rxn1}). Strict avoidance ordered."
                s_b = f"{enc_b}: Allergy section records no known drug allergies (NKDA). Patient denies adverse reactions."
                pairs.append({
                    "template_family": "ALLERGY_POSITIVE_VS_DENIAL",
                    "category": "ALLERGY",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": allergy.lower(),
                    "normalized_value_a": allergy.lower(),
                    "normalized_value_b": "NO_KNOWN_ALLERGIES",
                    "date_a": d_a,
                    "date_b": d_b,
                    "label": "POTENTIAL_CONTRADICTION",
                    "explanation": f"Document A establishes {allergy} allergy whereas Document B documents no known allergies.",
                    "review_required": True
                })

    # 2. Consistent: Concordant allergy confirmations
    for allergy, rxn1, rxn2 in ALLERGIES:
        for enc_a in ENCOUNTERS[:4]:
            for enc_b in ENCOUNTERS[5:9]:
                d_a = f"2026-01-{random.randint(1,28):02d}"
                d_b = f"2026-02-{random.randint(1,28):02d}"
                s_a = f"{enc_a}: Confirmed {allergy.lower()} allergy with history of {rxn1}."
                s_b = f"{enc_b}: Problem list notes hypersensitivity to {allergy.title()} manifesting as {rxn2}."
                pairs.append({
                    "template_family": "ALLERGY_CONCORDANT_CONFIRMATION",
                    "category": "ALLERGY",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": allergy.lower(),
                    "normalized_value_a": allergy.lower(),
                    "normalized_value_b": allergy.lower(),
                    "date_a": d_a,
                    "date_b": d_b,
                    "label": "CONSISTENT",
                    "explanation": f"Both documents concordantly verify {allergy} hypersensitivity.",
                    "review_required": False
                })

    # 3. Consistent: Concordant NKDA
    for enc_a in ENCOUNTERS[:5]:
        for enc_b in ENCOUNTERS[5:]:
            for i in range(4):
                d_a = f"2026-01-{random.randint(1,28):02d}"
                d_b = f"2026-02-{random.randint(1,28):02d}"
                s_a = f"{enc_a}: Patient screened for drug allergies; no known drug allergies (NKDA) confirmed."
                s_b = f"{enc_b}: Review of systems negative for adverse pharmacological events; NKDA verified."
                pairs.append({
                    "template_family": "ALLERGY_CONCORDANT_DENIAL_NKDA",
                    "category": "ALLERGY",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": "allergies",
                    "normalized_value_a": "NO_KNOWN_ALLERGIES",
                    "normalized_value_b": "NO_KNOWN_ALLERGIES",
                    "date_a": d_a,
                    "date_b": d_b,
                    "label": "CONSISTENT",
                    "explanation": "Both documents establish absence of known drug allergies.",
                    "review_required": False
                })

    # 4. Insufficient Evidence: Omitted section
    for allergy, rxn1, rxn2 in ALLERGIES:
        for enc_a in ENCOUNTERS[:5]:
            d_a = f"2026-01-{random.randint(1,28):02d}"
            d_b = f"2026-03-{random.randint(1,28):02d}"
            s_a = f"{enc_a}: Allergy record lists {allergy.title()} ({rxn1})."
            s_b = f"Focused orthopedic encounter note records procedural details; systemic allergy reconciliation omitted."
            pairs.append({
                "template_family": "ALLERGY_OMITTED_SECTION",
                "category": "ALLERGY",
                "statement_a": s_a,
                "statement_b": s_b,
                "normalized_field": allergy.lower(),
                "normalized_value_a": allergy.lower(),
                "normalized_value_b": "UNMENTIONED",
                "date_a": d_a,
                "date_b": d_b,
                "label": "INSUFFICIENT_EVIDENCE",
                "explanation": "Receiving clinical record omits allergy review. Omission is not proof of absence.",
                "review_required": True
            })

    return pairs

def build_all_medication_pairs():
    pairs = []
    
    # 1. Consistent: Same Prescription across providers
    for med, brand, doses, freqs, route in MEDICATIONS:
        for dose in doses[:2]:
            for enc_a in ENCOUNTERS[:3]:
                for enc_b in ENCOUNTERS[4:7]:
                    d_a = f"2026-01-{random.randint(1,15):02d}"
                    d_b = f"2026-02-{random.randint(16,28):02d}"
                    f1 = freqs[0]
                    f2 = freqs[-1]
                    s_a = f"{enc_a}: Prescribed {med} {dose} {f1}."
                    s_b = f"{enc_b}: Ongoing medication confirmed as {med} {dose} {f2}."
                    pairs.append({
                        "template_family": "MED_CONCORDANT_SAME_PRESCRIPTION",
                        "category": "MEDICATION",
                        "statement_a": s_a,
                        "statement_b": s_b,
                        "normalized_field": med.lower(),
                        "normalized_value_a": f"{dose} {f1}",
                        "normalized_value_b": f"{dose} {f2}",
                        "date_a": d_a,
                        "date_b": d_b,
                        "label": "CONSISTENT",
                        "explanation": f"Medication {med} and dosage {dose} concordant across clinical records.",
                        "review_required": False
                    })

    # 2. Consistent: Brand/Generic Aliases
    for med, brand, doses, freqs, route in MEDICATIONS:
        dose = doses[0]
        for enc_a in ENCOUNTERS[:4]:
            for enc_b in ENCOUNTERS[5:8]:
                d_a = f"2026-01-{random.randint(1,28):02d}"
                d_b = f"2026-02-{random.randint(1,28):02d}"
                s_a = f"{enc_a}: Patient discharged on {med} {dose} {freqs[0]}."
                s_b = f"{enc_b}: Pharmacy dispensing record confirms brand {brand} {dose} {freqs[-1]}."
                pairs.append({
                    "template_family": "MED_BRAND_GENERIC_EQUIVALENCE",
                    "category": "MEDICATION",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": med.lower(),
                    "normalized_value_a": dose,
                    "normalized_value_b": dose,
                    "date_a": d_a,
                    "date_b": d_b,
                    "label": "CONSISTENT",
                    "explanation": f"Brand {brand} is pharmacologically equivalent to generic {med}.",
                    "review_required": False
                })

    # 3. Temporal Change: Discontinued over time
    for med, brand, doses, freqs, route in MEDICATIONS:
        dose = doses[0]
        for enc_a in ENCOUNTERS[:4]:
            for enc_b in ENCOUNTERS[5:8]:
                d_a = f"2026-01-{random.randint(1,15):02d}"
                d_b = f"2026-03-{random.randint(16,28):02d}"
                s_a = f"{enc_a} ({d_a}): Active prescription: {med} {dose} {freqs[0]}."
                s_b = f"{enc_b} ({d_b}): Therapy update: {med} was discontinued on {d_b} due to adverse clinical response."
                pairs.append({
                    "template_family": "MED_DISCONTINUATION_OVER_TIME",
                    "category": "MEDICATION",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": med.lower(),
                    "normalized_value_a": f"{dose} ACTIVE",
                    "normalized_value_b": f"{dose} DISCONTINUED",
                    "date_a": d_a,
                    "date_b": d_b,
                    "label": "TEMPORAL_CHANGE",
                    "explanation": f"{med} discontinued chronologically on a later date; reflects therapeutic management over time.",
                    "review_required": True
                })

    # 4. Temporal Change: Dose titration over time
    for med, brand, doses, freqs, route in MEDICATIONS:
        if len(doses) >= 2:
            d1, d2 = doses[0], doses[-1]
            for enc_a in ENCOUNTERS[:3]:
                for enc_b in ENCOUNTERS[5:7]:
                    d_a = f"2026-01-{random.randint(1,15):02d}"
                    d_b = f"2026-03-{random.randint(16,28):02d}"
                    s_a = f"{enc_a} ({d_a}): Initiated {med} at starter dose of {d1} daily."
                    # Varied clinical trajectory phrasing
                    phrasing_options = [
                        f"{enc_b} ({d_b}): Therapeutic monitoring: {med} titrated up to {d2} daily.",
                        f"{enc_b} ({d_b}): Follow-up visit: {med} increased to {d2} daily for clinical efficacy.",
                        f"{enc_b} ({d_b}): Interval adjustment: {med} dose adjusted from {d1} to {d2} daily.",
                        f"{enc_b} ({d_b}): Clinical modification: now taking {med} {d2} daily."
                    ]
                    for s_b in phrasing_options:
                        pairs.append({
                            "template_family": "MED_DOSE_TITRATION_CHRONOLOGICAL",
                            "category": "MEDICATION",
                            "statement_a": s_a,
                            "statement_b": s_b,
                            "normalized_field": med.lower(),
                            "normalized_value_a": d1,
                            "normalized_value_b": d2,
                            "date_a": d_a,
                            "date_b": d_b,
                            "label": "TEMPORAL_CHANGE",
                            "explanation": f"Sequential dosage change from {d1} to {d2} reflects intended clinical titration.",
                            "review_required": True
                        })

    # 5. Contradiction: Concurrent dose discrepancy
    for med, brand, doses, freqs, route in MEDICATIONS:
        if len(doses) >= 2:
            d1, d2 = doses[0], doses[-1]
            for enc_a in ENCOUNTERS[:4]:
                for enc_b in ENCOUNTERS[4:7]:
                    same_d = f"2026-02-{random.randint(10,18):02d}"
                    s_a = f"{enc_a} ({same_d}): Current order records {med} {d1} daily."
                    s_b = f"{enc_b} ({same_d}): Concurrent record documents {med} {d2} daily."
                    pairs.append({
                        "template_family": "MED_CONCURRENT_DOSE_CONFLICT",
                        "category": "MEDICATION",
                        "statement_a": s_a,
                        "statement_b": s_b,
                        "normalized_field": med.lower(),
                        "normalized_value_a": d1,
                        "normalized_value_b": d2,
                        "date_a": same_d,
                        "date_b": same_d,
                        "label": "POTENTIAL_CONTRADICTION",
                        "explanation": f"Conflicting concurrent doses ({d1} vs {d2}) ordered simultaneously on the same date.",
                        "review_required": True
                    })

    # 6. Insufficient: Omission in focused note
    for med, brand, doses, freqs, route in MEDICATIONS:
        dose = doses[0]
        for enc_a in ENCOUNTERS[:3]:
            for i in range(2):
                d_a = f"2026-01-{random.randint(1,28):02d}"
                d_b = f"2026-02-{random.randint(1,28):02d}"
                s_a = f"{enc_a}: Patient takes maintenance {med} {dose} {freqs[0]}."
                s_b = f"Specialty ENT surgical evaluation documents acute antibiotics only; chronic medications not recorded."
                pairs.append({
                    "template_family": "MED_OMISSION_ENCOUNTER_NOTE",
                    "category": "MEDICATION",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": med.lower(),
                    "normalized_value_a": dose,
                    "normalized_value_b": "UNMENTIONED",
                    "date_a": d_a,
                    "date_b": d_b,
                    "label": "INSUFFICIENT_EVIDENCE",
                    "explanation": "Focused clinical note omits maintenance pharmacotherapy; omission does not prove discontinuation.",
                    "review_required": True
                })

    return pairs

def build_all_diagnosis_pairs():
    pairs = []
    
    # 1. Consistent: Problem list agreement
    for diag, icd, context, sub in DIAGNOSES:
        for enc_a in ENCOUNTERS[:4]:
            for enc_b in ENCOUNTERS[5:9]:
                d_a = f"2026-01-{random.randint(1,28):02d}"
                d_b = f"2026-02-{random.randint(1,28):02d}"
                s_a = f"{enc_a}: Problem List includes {diag} ({icd}), under medical management."
                s_b = f"{enc_b}: Assessment notes history of {diag.lower()} ({sub})."
                pairs.append({
                    "template_family": "DX_CONCORDANT_PROBLEM_LIST",
                    "category": "DIAGNOSIS",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": diag.lower(),
                    "normalized_value_a": "PRESENT",
                    "normalized_value_b": "PRESENT",
                    "date_a": d_a,
                    "date_b": d_b,
                    "label": "CONSISTENT",
                    "explanation": f"Concordant documentation of {diag} across both encounters.",
                    "review_required": False
                })

    # 2. Contradiction: Confirmed vs Explicitly Ruled Out
    for diag, icd, context, sub in DIAGNOSES:
        for enc_a in ENCOUNTERS[:4]:
            for enc_b in ENCOUNTERS[4:8]:
                same_d = f"2026-02-{random.randint(1,20):02d}"
                s_a = f"{enc_a}: Definitive clinical impression confirms active {diag}."
                s_b = f"{enc_b}: Objective diagnostic workup completed; {diag.lower()} is definitively ruled out and excluded."
                pairs.append({
                    "template_family": "DX_CONFIRMED_VS_RULED_OUT",
                    "category": "DIAGNOSIS",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": diag.lower(),
                    "normalized_value_a": "PRESENT",
                    "normalized_value_b": "EXCLUDED",
                    "date_a": same_d,
                    "date_b": same_d,
                    "label": "POTENTIAL_CONTRADICTION",
                    "explanation": f"Direct conflict between active confirmation and explicit exclusion of {diag}.",
                    "review_required": True
                })

    # 3. Insufficient: Suspected / unconfirmed workup
    for diag, icd, context, sub in DIAGNOSES:
        for enc_a in ENCOUNTERS[:3]:
            d_a = f"2026-01-{random.randint(1,28):02d}"
            d_b = f"2026-02-{random.randint(1,28):02d}"
            s_a = f"{enc_a}: Suspected {diag.lower()} on clinical differential; pending diagnostic testing."
            s_b = f"Follow-up visit addressed orthopedic complaint; status of differential workup for {diag.lower()} unrecorded."
            pairs.append({
                "template_family": "DX_PRELIMINARY_WORKUP_INCOMPLETE",
                "category": "DIAGNOSIS",
                "statement_a": s_a,
                "statement_b": s_b,
                "normalized_field": diag.lower(),
                "normalized_value_a": "SUSPECTED",
                "normalized_value_b": "UNCONFIRMED",
                "date_a": d_a,
                "date_b": d_b,
                "label": "INSUFFICIENT_EVIDENCE",
                "explanation": f"Clinical workup for {diag} remains preliminary without definitive confirmation.",
                "review_required": True
            })

    return pairs

def build_all_lab_pairs():
    pairs = []
    
    # 1. Consistent: Repeat concordant verification
    for lab_name, values, unit in LABS:
        for val in values[:4]:
            for enc_a in ENCOUNTERS[:2]:
                for enc_b in ENCOUNTERS[4:6]:
                    d_a = "2026-01-14"
                    d_b = "2026-01-14"
                    s_a = f"{enc_a}: {lab_name} reported at {val} {unit}."
                    s_b = f"{enc_b}: Verified repeat testing confirmed {lab_name} at {val} {unit}."
                    pairs.append({
                        "template_family": "LAB_CONCORDANT_REPEAT",
                        "category": "LAB_RESULT",
                        "statement_a": s_a,
                        "statement_b": s_b,
                        "normalized_field": lab_name.lower(),
                        "normalized_value_a": f"{val} {unit}".strip(),
                        "normalized_value_b": f"{val} {unit}".strip(),
                        "date_a": d_a,
                        "date_b": d_b,
                        "label": "CONSISTENT",
                        "explanation": f"Concordant laboratory measurement for {lab_name} ({val} {unit}).",
                        "review_required": False
                    })

    # 2. Consistent: Unit conversion equivalents
    conversions = [
        ("Fasting Blood Glucose", 126.0, "mg/dL", 7.0, "mmol/L"),
        ("Fasting Blood Glucose", 180.0, "mg/dL", 10.0, "mmol/L"),
        ("Serum Creatinine", 1.0, "mg/dL", 88.4, "umol/L"),
        ("Serum Creatinine", 2.0, "mg/dL", 176.8, "umol/L"),
    ]
    for lab_name, v1, u1, v2, u2 in conversions:
        for enc_a in ENCOUNTERS[:5]:
            for enc_b in ENCOUNTERS[5:]:
                d = f"2026-02-{random.randint(1,20):02d}"
                s_a = f"{enc_a}: {lab_name} quantified at {v1} {u1}."
                s_b = f"{enc_b}: Reference panel reports {lab_name} as {v2} {u2}."
                pairs.append({
                    "template_family": "LAB_UNIT_CONVERSION_EQUIVALENT",
                    "category": "LAB_RESULT",
                    "statement_a": s_a,
                    "statement_b": s_b,
                    "normalized_field": lab_name.lower(),
                    "normalized_value_a": f"{v1} {u1}",
                    "normalized_value_b": f"{v2} {u2}",
                    "date_a": d,
                    "date_b": d,
                    "label": "CONSISTENT",
                    "explanation": f"Equivalent measurements normalized between {u1} and {u2}.",
                    "review_required": False
                })

    # 3. Temporal Change: Serial monitoring across dates
    for lab_name, values, unit in LABS:
        if len(values) >= 2:
            v1, v2 = values[0], values[-1]
            for enc_a in ENCOUNTERS[:3]:
                for enc_b in ENCOUNTERS[4:7]:
                    d_a = f"2026-01-{random.randint(1,15):02d}"
                    d_b = f"2026-03-{random.randint(16,28):02d}"
                    s_a = f"{enc_a} on {d_a}: Baseline {lab_name} {v1} {unit}."
                    s_b = f"{enc_b} on {d_b}: Surveillance {lab_name} demonstrates value of {v2} {unit}."
                    pairs.append({
                        "template_family": "LAB_SERIAL_PHYSIOLOGIC_MONITORING",
                        "category": "LAB_RESULT",
                        "statement_a": s_a,
                        "statement_b": s_b,
                        "normalized_field": lab_name.lower(),
                        "normalized_value_a": f"{v1} {unit}".strip(),
                        "normalized_value_b": f"{v2} {unit}".strip(),
                        "date_a": d_a,
                        "date_b": d_b,
                        "label": "TEMPORAL_CHANGE",
                        "explanation": f"Sequential measurements of {lab_name} across dates reflect expected temporal physiological changes.",
                        "review_required": False
                    })

    # 4. Contradiction: Concurrent draw discrepancy
    for lab_name, values, unit in LABS:
        if len(values) >= 2:
            v1, v2 = values[0], values[-1]
            for enc_a in ENCOUNTERS[:3]:
                for enc_b in ENCOUNTERS[4:7]:
                    same_d = f"2026-02-{random.randint(10,18):02d}"
                    s_a = f"{enc_a} ({same_d} 08:00 AM): {lab_name} reported as {v1} {unit}."
                    s_b = f"{enc_b} ({same_d} 08:20 AM): Same morning draw of {lab_name} returned {v2} {unit}."
                    pairs.append({
                        "template_family": "LAB_CONCURRENT_DIFFERENT_VALUES",
                        "category": "LAB_RESULT",
                        "statement_a": s_a,
                        "statement_b": s_b,
                        "normalized_field": lab_name.lower(),
                        "normalized_value_a": f"{v1} {unit}".strip(),
                        "normalized_value_b": f"{v2} {unit}".strip(),
                        "date_a": same_d,
                        "date_b": same_d,
                        "label": "POTENTIAL_CONTRADICTION",
                        "explanation": f"Simultaneous conflicting values for {lab_name} drawn on the same morning.",
                        "review_required": True
                    })

    return pairs

def build_unseen_benchmark_pairs():
    """
    Constructs an independent, out-of-distribution benchmark dataset (300+ examples)
    using clinical concepts, novel drugs, complex phrasing, and edge cases NEVER in training.
    """
    records = []
    
    novel_allergens = [
        ("Ceftriaxone", "third-generation cephalosporin", "anaphylaxis with laryngeal edema", "tolerated without any adverse symptoms"),
        ("Adalimumab", "TNF-inhibitor biologic", "severe facial angioedema and bronchospasm", "denies any allergic reaction to biologic agents"),
        ("Meropenem", "carbapenem antibiotic", "severe cutaneous adverse reaction with epidermal detachment", "all carbapenem agents tolerated well"),
        ("Gadolinium", "MRI contrast agent", "acute systemic anaphylactoid reaction", "no history of contrast reactions"),
        ("Pembrolizumab", "checkpoint inhibitor antibody", "immune-related acute pneumonitis and hypersensitivity", "patient denies immunotherapy adverse reactions"),
        ("Rituximab", "monoclonal anti-CD20 antibody", "severe rigors, hypotension and angioedema", "no known reaction to infusion therapy")
    ]
    for agent, cls_desc, rxn, tol in novel_allergens:
        for enc_a in ENCOUNTERS[:4]:
            for enc_b in ENCOUNTERS[5:9]:
                d1 = f"2026-0{random.randint(1,2)}-{random.randint(1,15):02d}"
                d2 = f"2026-0{random.randint(1,2)}-{random.randint(16,28):02d}"
                # Conflict
                records.append({
                    "template_family": "UNSEEN_ALLERGY_CONFLICT",
                    "category": "ALLERGY",
                    "statement_a": f"{enc_a}: Acute anaphylaxis ({rxn}) triggered by {agent}.",
                    "statement_b": f"{enc_b}: Allergy intake records no drug sensitivities; {agent} listed as {tol}.",
                    "normalized_field": agent.lower(),
                    "normalized_value_a": agent.lower(),
                    "normalized_value_b": "NO_KNOWN_ALLERGIES",
                    "date_a": d1,
                    "date_b": d2,
                    "label": "POTENTIAL_CONTRADICTION",
                    "explanation": f"Document A describes life-threatening {agent} reaction whereas Document B documents complete tolerance.",
                    "review_required": True
                })
                # Consistent
                records.append({
                    "template_family": "UNSEEN_ALLERGY_CONSISTENT",
                    "category": "ALLERGY",
                    "statement_a": f"{enc_a}: Life-threatening allergy to {agent} ({rxn}).",
                    "statement_b": f"{enc_b}: Specialist consultation confirms hypersensitivity to {agent} ({cls_desc}).",
                    "normalized_field": agent.lower(),
                    "normalized_value_a": agent.lower(),
                    "normalized_value_b": agent.lower(),
                    "date_a": d1,
                    "date_b": d2,
                    "label": "CONSISTENT",
                    "explanation": f"Concordant confirmation of {agent} hypersensitivity.",
                    "review_required": False
                })
                # Insufficient
                records.append({
                    "template_family": "UNSEEN_ALLERGY_OMISSION",
                    "category": "ALLERGY",
                    "statement_a": f"{enc_a}: Documented allergy to {agent} ({rxn}).",
                    "statement_b": f"{enc_b}: Focused clinical encounter; systemic allergy chart unreviewed.",
                    "normalized_field": agent.lower(),
                    "normalized_value_a": agent.lower(),
                    "normalized_value_b": "UNMENTIONED",
                    "date_a": d1,
                    "date_b": d2,
                    "label": "INSUFFICIENT_EVIDENCE",
                    "explanation": "Second record completely omits allergy documentation.",
                    "review_required": True
                })

    novel_meds = [
        ("Semaglutide", "Ozempic", "0.25 mg weekly", "1.0 mg weekly", "GLP-1 receptor agonist"),
        ("Dapagliflozin", "Farxiga", "5 mg daily", "10 mg daily", "SGLT2 inhibitor"),
        ("Entresto", "Sacubitril/Valsartan", "24/26 mg BID", "49/51 mg BID", "ARNI"),
        ("Spironolactone", "Aldactone", "25 mg daily", "50 mg daily", "mineralocorticoid antagonist"),
        ("Rivaroxaban", "Xarelto", "15 mg daily", "20 mg daily", "direct factor Xa inhibitor")
    ]
    for med, brand, low_dose, high_dose, cls_desc in novel_meds:
        for enc_a in ENCOUNTERS[:3]:
            for enc_b in ENCOUNTERS[5:8]:
                d1 = f"2026-01-{random.randint(1,15):02d}"
                d2 = f"2026-03-{random.randint(16,28):02d}"
                # Temporal titration
                records.append({
                    "template_family": "UNSEEN_MED_TEMPORAL",
                    "category": "MEDICATION",
                    "statement_a": f"{enc_a} on {d1}: Patient initiated on {med} at starter dose of {low_dose}.",
                    "statement_b": f"{enc_b} on {d2}: Dose of {med} successfully titrated up to {high_dose}.",
                    "normalized_field": med.lower(),
                    "normalized_value_a": low_dose,
                    "normalized_value_b": high_dose,
                    "date_a": d1,
                    "date_b": d2,
                    "label": "TEMPORAL_CHANGE",
                    "explanation": f"Sequential dosage modification from {low_dose} to {high_dose} over time.",
                    "review_required": True
                })
                # Concurrent dose conflict
                records.append({
                    "template_family": "UNSEEN_MED_CONFLICT",
                    "category": "MEDICATION",
                    "statement_a": f"{enc_a} from {d1}: Prescribed {med} {low_dose}.",
                    "statement_b": f"{enc_b} from {d1}: Documented order for {brand} {high_dose}.",
                    "normalized_field": med.lower(),
                    "normalized_value_a": low_dose,
                    "normalized_value_b": high_dose,
                    "date_a": d1,
                    "date_b": d1,
                    "label": "POTENTIAL_CONTRADICTION",
                    "explanation": f"Simultaneous conflicting dosage orders for {med} on the same transfer date.",
                    "review_required": True
                })
                # Brand generic agreement
                records.append({
                    "template_family": "UNSEEN_MED_CONSISTENT",
                    "category": "MEDICATION",
                    "statement_a": f"{enc_a}: Patient maintained on {med} {high_dose}.",
                    "statement_b": f"{enc_b}: Refill authorization confirmed for {brand} {high_dose}.",
                    "normalized_field": med.lower(),
                    "normalized_value_a": high_dose,
                    "normalized_value_b": high_dose,
                    "date_a": d1,
                    "date_b": d2,
                    "label": "CONSISTENT",
                    "explanation": f"Brand {brand} is concordant with generic {med}.",
                    "review_required": False
                })

    novel_labs = [
        ("Troponin I", 0.95, 0.02, "ng/mL"),
        ("Procalcitonin", 3.2, 0.1, "ng/mL"),
        ("Serum Ferritin", 950.0, 140.0, "ng/mL"),
        ("D-Dimer", 3500.0, 320.0, "ng/mL"),
        ("Brain Natriuretic Peptide (BNP)", 1450.0, 120.0, "pg/mL")
    ]
    for lab_name, v_high, v_low, unit in novel_labs:
        for enc_a in ENCOUNTERS[:3]:
            for enc_b in ENCOUNTERS[4:7]:
                d1 = f"2026-01-{random.randint(1,10):02d}"
                d2 = f"2026-01-{random.randint(15,25):02d}"
                # Temporal physiologic change
                records.append({
                    "template_family": "UNSEEN_LAB_TEMPORAL",
                    "category": "LAB_RESULT",
                    "statement_a": f"{enc_a} ({d1}): {lab_name} acutely elevated at {v_high} {unit}.",
                    "statement_b": f"{enc_b} ({d2}): {lab_name} normalized down to {v_low} {unit} post-treatment.",
                    "normalized_field": lab_name.lower(),
                    "normalized_value_a": f"{v_high} {unit}",
                    "normalized_value_b": f"{v_low} {unit}",
                    "date_a": d1,
                    "date_b": d2,
                    "label": "TEMPORAL_CHANGE",
                    "explanation": f"Sequential resolution of {lab_name} following therapy across time.",
                    "review_required": False
                })
                # Concurrent conflict
                records.append({
                    "template_family": "UNSEEN_LAB_CONFLICT",
                    "category": "LAB_RESULT",
                    "statement_a": f"{enc_a} (14:00): {lab_name} reported at {v_high} {unit}.",
                    "statement_b": f"{enc_b} (14:15): Repeat verification reported {lab_name} as {v_low} {unit}.",
                    "normalized_field": lab_name.lower(),
                    "normalized_value_a": f"{v_high} {unit}",
                    "normalized_value_b": f"{v_low} {unit}",
                    "date_a": d1,
                    "date_b": d1,
                    "label": "POTENTIAL_CONTRADICTION",
                    "explanation": f"Discrepant simultaneous measurements for {lab_name} drawn within minutes.",
                    "review_required": True
                })

    df = pd.DataFrame(records).drop_duplicates(subset=["statement_a", "statement_b"]).reset_index(drop=True)
    df["example_id"] = [f"UNSEEN-{i:04d}" for i in range(len(df))]
    return df

def generate_and_save():
    print("Building expanded clinical pools...")
    candidates = []
    candidates.extend(build_all_allergy_pairs())
    candidates.extend(build_all_medication_pairs())
    candidates.extend(build_all_diagnosis_pairs())
    candidates.extend(build_all_lab_pairs())

    df_raw = pd.DataFrame(candidates)
    print(f"Raw candidate pairs: {len(df_raw)}")
    
    # Strictly deduplicate statement pairs
    df_unique = df_raw.drop_duplicates(subset=["statement_a", "statement_b"]).copy().reset_index(drop=True)
    df_unique["example_id"] = [f"SYN-{i:05d}" for i in range(len(df_unique))]
    print(f"Unique statement pairs after deduplication: {len(df_unique)}")

    # Sample exactly 3,600 unique statement pairs
    target_count = min(3600, len(df_unique))
    df_in_dist = df_unique.sample(n=target_count, random_state=RANDOM_SEED).reset_index(drop=True)

    # 1. Stratified In-Distribution Split (70% Train, 15% Val, 15% Test)
    train_df, test_val_df = train_test_split(
        df_in_dist, test_size=0.30, random_state=RANDOM_SEED, stratify=df_in_dist["label"]
    )
    val_df, test_df = train_test_split(
        test_val_df, test_size=0.50, random_state=RANDOM_SEED, stratify=test_val_df["label"]
    )

    train_df = train_df.reset_index(drop=True)
    val_df = val_df.reset_index(drop=True)
    test_df = test_df.reset_index(drop=True)

    # Assert 0% exact duplicate overlap
    train_pairs = set(zip(train_df["statement_a"], train_df["statement_b"]))
    val_pairs = set(zip(val_df["statement_a"], val_df["statement_b"]))
    test_pairs = set(zip(test_df["statement_a"], test_df["statement_b"]))

    assert len(train_pairs.intersection(test_pairs)) == 0, "Leakage detected between train and test!"
    assert len(train_pairs.intersection(val_pairs)) == 0, "Leakage detected between train and val!"
    print("PASSED: 0.0% overlap between train and test pairs.")

    # 2. Group-Based Split (Disjoint Template Families)
    gss = GroupShuffleSplit(n_splits=1, test_size=0.20, random_state=RANDOM_SEED)
    train_idx, group_test_idx = next(gss.split(df_in_dist, df_in_dist["label"], groups=df_in_dist["template_family"]))
    group_train_df = df_in_dist.iloc[train_idx].reset_index(drop=True)
    group_test_df = df_in_dist.iloc[group_test_idx].reset_index(drop=True)

    # 3. Independent Unseen-Template Benchmark (Out-of-Distribution)
    df_unseen = build_unseen_benchmark_pairs()
    print(f"Generated unseen benchmark examples: {len(df_unseen)}")

    # 4. Save CSV files
    df_in_dist.to_csv(OUTPUT_DIR / "dataset_full.csv", index=False)
    train_df.to_csv(OUTPUT_DIR / "train.csv", index=False)
    val_df.to_csv(OUTPUT_DIR / "validation.csv", index=False)
    test_df.to_csv(OUTPUT_DIR / "test.csv", index=False)
    
    group_train_df.to_csv(OUTPUT_DIR / "train_group_split.csv", index=False)
    group_test_df.to_csv(OUTPUT_DIR / "test_group_disjoint.csv", index=False)
    df_unseen.to_csv(OUTPUT_DIR / "test_unseen_templates.csv", index=False)

    metadata = {
        "dataset_name": "RecordGuard Synthetic Clinical Contradiction Dataset (Audited Leak-Free v2)",
        "version": "2.0.0",
        "random_seed": RANDOM_SEED,
        "total_unique_in_distribution": len(df_in_dist),
        "splits": {
            "train": len(train_df),
            "validation": len(val_df),
            "test_stratified": len(test_df),
            "group_train": len(group_train_df),
            "group_test_disjoint": len(group_test_df),
            "unseen_template_benchmark": len(df_unseen)
        },
        "class_distribution_train": train_df["label"].value_counts().to_dict(),
        "class_distribution_test": test_df["label"].value_counts().to_dict(),
        "class_distribution_unseen": df_unseen["label"].value_counts().to_dict(),
        "template_families": sorted(df_in_dist["template_family"].unique().tolist()),
        "synthetic_disclosure": "ALL DATA IS SYNTHETICALLY GENERATED FOR CLINICAL RECORD CONTRADICTION BENCHMARKING. DOES NOT CONTAIN REAL PHI."
    }

    with open(OUTPUT_DIR / "DATASET_INFO.json", "w") as f:
        json.dump(metadata, f, indent=2)

    print("\nDataset generation and partitioning complete:")
    print(f"  Train: {len(train_df)} | Val: {len(val_df)} | Stratified Test: {len(test_df)}")
    print(f"  Group-Disjoint Test: {len(group_test_df)}")
    print(f"  Unseen Benchmark: {len(df_unseen)}")
    print(f"  Train classes: {metadata['class_distribution_train']}")

if __name__ == "__main__":
    generate_and_save()
