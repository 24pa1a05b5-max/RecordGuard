# RecordGuard AI — 3-Minute Hackathon Demo Script

This script guides evaluators through a demonstration of **RecordGuard AI (PS-11R3)** in approximately 3 minutes.

---

## Prerequisites
1. Start Backend:
   ```bash
   cd c:\Prototype
   $env:PYTHONPATH="."
   python -m uvicorn backend.app.main:app --reload --port 8000
   ```
2. Start Flutter App (Web or Windows):
   ```bash
   cd c:\Prototype\frontend
   flutter run -d chrome
   # Or: flutter run -d windows
   ```

---

## 3-Minute Live Presentation Script

### Minute 0:00 – 0:30: Introduction & Authentication
1. **Show Login Screen**:
   - Highlight: Clean clinical healthcare SaaS interface designed for attending clinicians.
   - Note the **Authorized Demonstration Mode** banner and synthetic disclosure.
   - Click **Enter Clinician Workspace** (pre-filled with `clinician.demo`).
2. **Key Talking Point**:
   > *"In modern healthcare, patients regularly receive care across multiple unaffiliated hospital systems and clinics. When medical records disagree—for example, on allergies or medications—the consequences can be life-threatening. RecordGuard AI is an evidence-provenance surveillance engine that flags cross-record contradictions without making opaque, ungrounded medical guesses."*

---

### Minute 0:30 – 1:15: Overview Dashboard & Review Queue
1. **Explore Dashboard**:
   - Point out real persisted counters: Patient Cohorts, Documents Ingested, Pending Discrepancies, and Resolved Findings.
   - Note the **Priority Review Queue** card highlighting active high-priority items.
2. **Navigate to Queue**:
   - Click **Review Queue** on the sidebar.
   - Observe transparent triage rationale:
     > *"Notice that RecordGuard explicitly explains WHY each finding was triaged to Priority Review (e.g. direct allergy safety conflict) rather than using a black-box risk score."*

---

### Minute 1:15 – 2:00: Live Document Comparison (Scenario 1)
1. **Navigate to Compare**:
   - Click **Compare** on the sidebar.
   - Select patient: `Eleanor Vance (PAT-88201)`.
   - Document A: `Metro General Hospital Discharge Summary` (PDF).
   - Document B: `Pinecrest Community Clinic Intake Form` (PDF).
2. **Click "Analyze & Compare"**:
   - The system executes deterministic extraction, unit/frequency normalization, contradiction rules, and ML classification.
   - View the generated finding: **Potential Allergy-Record Conflict (Penicillin vs NKDA)**.
3. **Inspect Evidence Modal**:
   - Click **Show Evidence**.
   - Show side-by-side evidence:
     - Document A, Page 1: *"Penicillin allergy (severe urticaria and facial swelling reported)."*
     - Document B, Page 1: *"Allergies: No known drug allergies (NKDA)."*
     - Point out **100% Traceability** and verbatim source verification.
   - **Key Talking Point**:
     > *"Notice our defining feature: 'Show me exactly why this was flagged, where the evidence came from, and what remains uncertain.' The system does not claim to know which doctor is right—it surfaces transparent evidence and recommends immediate clinical verification before beta-lactams are administered."*

---

### Minute 2:00 – 2:40: Human Verification & Persistent Audit Trail
1. **Perform Review**:
   - Click **Verify & Resolve**.
   - Select **Confirm Discrepancy**.
   - Enter mandatory decision reason:
     *"Spoke directly with patient; confirmed childhood penicillin anaphylaxis. Pinecrest intake was incorrectly recorded."*
   - Add clinical note: *"Updated hospital EHR allergy banner."*
   - Click **Save Verification**.
2. **Inspect Audit History**:
   - Open **Verify & Resolve** again to show the persistent audit log.
   - Point out that the previous status, new status, reviewer name (`Dr. Alex Rivera, MD`), decision reason, and timestamp are indelibly preserved.

---

### Minute 2:40 – 3:00: Model Transparency & Dataset Disclosure
1. **Navigate to Model Info**:
   - Click **Model Info** on the sidebar.
   - Review actual held-out test metrics:
     - Held-Out Test Accuracy & Macro F1.
     - 3,200 synthetic examples breakdown (2,240 Train, 480 Val, 480 Test).
     - Per-class precision, recall, and support table.
     - Documented limitations and responsible use disclosure.
2. **Closing Statement**:
   > *"RecordGuard AI bridges the gap between AI capability and clinical trust: rigorous deterministic extraction, transparent machine-learning assistance, verbatim provenance, and complete audit accountability."*
