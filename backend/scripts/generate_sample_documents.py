from pathlib import Path
import pymupdf

SAMPLE_DIR = Path(__file__).resolve().parent.parent.parent / "sample_documents"
SAMPLE_DIR.mkdir(parents=True, exist_ok=True)

def create_clinical_pdf(
    filename: str,
    clinic_header: str,
    patient_header: str,
    sections: list[tuple[str, str]],
    physician_footer: str
):
    doc = pymupdf.open()
    page = doc.new_page(width=595, height=842) # A4
    
    y = 50
    # Header
    page.insert_text((50, y), clinic_header, fontsize=14, fontname="helv", color=(0.05, 0.2, 0.4))
    y += 20
    page.draw_line(pymupdf.Point(50, y), pymupdf.Point(545, y), color=(0.7, 0.7, 0.7), width=1)
    y += 25
    
    # Patient Demographics
    page.insert_text((50, y), patient_header, fontsize=10, fontname="helv", color=(0.2, 0.2, 0.2))
    y += 25
    page.draw_line(pymupdf.Point(50, y), pymupdf.Point(545, y), color=(0.85, 0.85, 0.85), width=0.5)
    y += 20
    
    # Sections
    for title, content in sections:
        page.insert_text((50, y), title.upper(), fontsize=11, fontname="helv", color=(0.1, 0.3, 0.5))
        y += 16
        
        # Split content lines
        for line in content.split("\n"):
            page.insert_text((65, y), line, fontsize=10, fontname="helv", color=(0.15, 0.15, 0.15))
            y += 15
        y += 12
        
    y += 20
    page.draw_line(pymupdf.Point(50, y), pymupdf.Point(545, y), color=(0.7, 0.7, 0.7), width=1)
    y += 20
    page.insert_text((50, y), physician_footer, fontsize=10, fontname="helv", color=(0.3, 0.3, 0.3))
    
    out_path = SAMPLE_DIR / filename
    doc.save(str(out_path))
    doc.close()
    print(f"Generated sample PDF: {out_path}")

def generate_all_samples():
    # SCENARIO 1: ALLERGY CONFLICT
    # Doc 1A: Discharge Summary from Metro General
    create_clinical_pdf(
        filename="scenario1_docA_metro_discharge.pdf",
        clinic_header="METRO GENERAL HOSPITAL - INPATIENT DISCHARGE SUMMARY",
        patient_header="Patient: Eleanor Vance | MRN: SYN-88201 | DOB: 1968-04-12 | Encounter Date: 12 March 2026",
        sections=[
            ("Chief Complaint", "Admitted for acute exacerbation of chronic bronchitis. Treated with azithromycin."),
            ("Allergies", "Penicillin allergy (severe urticaria and facial swelling reported)."),
            ("Active Medications", "Azithromycin 250 mg daily for 5 days\nAlbuterol inhaler 90 mcg PRN as needed\nAtorvastatin 20 mg at bedtime"),
            ("Assessment & Plan", "Bronchitis resolving. Strictly avoid beta-lactam antibiotics due to documented penicillin allergy.")
        ],
        physician_footer="Dr. Raymond Vance, MD - Attending Hospitalist | Metro General Health"
    )

    # Doc 1B: Primary Care Intake from Pinecrest Medical
    create_clinical_pdf(
        filename="scenario1_docB_pinecrest_intake.pdf",
        clinic_header="PINECREST COMMUNITY CLINIC - ADULT INTAKE FORM",
        patient_header="Patient: Eleanor Vance | MRN: SYN-88201 | DOB: 1968-04-12 | Intake Date: 15 March 2026",
        sections=[
            ("Reason for Visit", "Routine follow-up following recent hospitalization for bronchitis."),
            ("Allergies", "Allergies: No known drug allergies (NKDA). Patient reports no adverse drug reactions."),
            ("Current Medications", "Atorvastatin 20 mg daily\nAlbuterol 90 mcg as needed"),
            ("Clinical Assessment", "Lungs clear bilaterally. Vitals stable.")
        ],
        physician_footer="Dr. Sarah Lin, MD - Primary Care Physician | Pinecrest Community Health"
    )

    # SCENARIO 2: MEDICATION DISCONTINUATION OVER TIME
    create_clinical_pdf(
        filename="scenario2_docA_endocrinology_jan.pdf",
        clinic_header="SUMMIT ENDOCRINOLOGY CENTER - CONSULTATION NOTE",
        patient_header="Patient: Arthur Pendelton | MRN: SYN-44910 | DOB: 1957-09-22 | Date: 10 January 2026",
        sections=[
            ("Assessment", "Type 2 Diabetes Mellitus with suboptimal glycemic control."),
            ("Medication Orders", "Metformin 500 mg twice daily with meals\nLisinopril 10 mg daily"),
            ("Plan", "Target fasting blood glucose < 130 mg/dL. Re-evaluate in 8 weeks.")
        ],
        physician_footer="Dr. Marcus Thorne, MD - Endocrinologist"
    )

    create_clinical_pdf(
        filename="scenario2_docB_cardiology_mar.pdf",
        clinic_header="HARBORVIEW CARDIOLOGY - ENCOUNTER SUMMARY",
        patient_header="Patient: Arthur Pendelton | MRN: SYN-44910 | DOB: 1957-09-22 | Date: 12 March 2026",
        sections=[
            ("Reason for Visit", "Hypertension and medication reconciliation follow-up."),
            ("Medication Updates", "Metformin discontinued on 28 February 2026 due to persistent GI distress.\nLisinopril 10 mg daily continued."),
            ("Assessment", "Blood pressure well controlled on lisinopril. Awaiting alternate oral hypoglycemic agent.")
        ],
        physician_footer="Dr. Elena Rostova, MD - Cardiovascular Medicine"
    )

    # SCENARIO 3: LABS OVER TIME
    create_clinical_pdf(
        filename="scenario3_docA_lab_january.pdf",
        clinic_header="QUEST CLINICAL LABS - HEMATOLOGY & DIABETIC PANEL",
        patient_header="Patient: Grace Hopper | MRN: SYN-11029 | Specimen Collection Date: 15 January 2026",
        sections=[
            ("Laboratory Findings", "HbA1c: 8.2 %\nFasting Glucose: 168 mg/dL\nSerum Creatinine: 1.1 mg/dL"),
            ("Comments", "Elevated HbA1c indicative of poorly controlled type 2 diabetes mellitus.")
        ],
        physician_footer="Verified by Clinical Pathology Laboratory Services"
    )

    create_clinical_pdf(
        filename="scenario3_docB_lab_march.pdf",
        clinic_header="QUEST CLINICAL LABS - HEMATOLOGY & DIABETIC PANEL",
        patient_header="Patient: Grace Hopper | MRN: SYN-11029 | Specimen Collection Date: 20 March 2026",
        sections=[
            ("Laboratory Findings", "HbA1c: 7.1 %\nFasting Glucose: 118 mg/dL\nSerum Creatinine: 1.0 mg/dL"),
            ("Comments", "HbA1c shows significant improvement following lifestyle and therapeutic intervention.")
        ],
        physician_footer="Verified by Clinical Pathology Laboratory Services"
    )

    # SCENARIO 4: MISSING ALLERGY OMISSION (TXT)
    txt_path_a = SAMPLE_DIR / "scenario4_docA_allergy_record.txt"
    with open(txt_path_a, "w") as f:
        f.write("""ST. JUDE REGIONAL CLINIC - PATIENT SUMMARY
Patient: Marcus Brody | MRN: SYN-99034 | Date: 05 February 2026

DOCUMENTED ALLERGIES:
Penicillin allergy (hives and wheezing).

ACTIVE MEDICATIONS:
Amlodipine 5 mg daily.
Hydrochlorothiazide 25 mg daily.

DIAGNOSIS:
Essential Hypertension.
""")

    txt_path_b = SAMPLE_DIR / "scenario4_docB_urgentcare_visit.txt"
    with open(txt_path_b, "w") as f:
        f.write("""WESTSIDE URGENT CARE ENCOUNTER
Patient: Marcus Brody | MRN: SYN-99034 | Date: 18 February 2026

CHIEF COMPLAINT:
Sprained right ankle following athletic activity.

PHYSICAL EXAMINATION:
Mild edema around lateral malleolus. No bony tenderness.
Lungs clear. Heart regular.

MEDICATIONS:
Amlodipine 5 mg daily.

PLAN:
RICE protocol. Ibuprofen 400 mg PRN. Follow up with PCP in 10 days.
""")

    # SCENARIO 5: EQUIVALENT REPRESENTATION (UNIT NORMALIZATION)
    create_clinical_pdf(
        filename="scenario5_docA_endocrinology.pdf",
        clinic_header="MIDWEST THYROID INSTITUTE - CLINIC NOTE",
        patient_header="Patient: Clara Oswald | MRN: SYN-33421 | Date: 02 February 2026",
        sections=[
            ("Diagnosis", "Hypothyroidism"),
            ("Prescription", "Levothyroxine 0.05 mg once daily every morning 30 minutes before breakfast.")
        ],
        physician_footer="Dr. David Song, MD - Endocrinology"
    )

    create_clinical_pdf(
        filename="scenario5_docB_pharmacy_dispense.pdf",
        clinic_header="HEALTHCARE PHARMACY NETWORK - DISPENSE RECORD",
        patient_header="Patient: Clara Oswald | MRN: SYN-33421 | Date: 04 February 2026",
        sections=[
            ("Medication Dispensed", "Synthroid 50 mcg QD every morning.\nQuantity: 90 tablets. Refills: 3."),
            ("Pharmacist Note", "Patient counseled on adherence.")
        ],
        physician_footer="Registered Pharmacist Verification - HealthCare Pharmacy"
    )

if __name__ == "__main__":
    generate_all_samples()
