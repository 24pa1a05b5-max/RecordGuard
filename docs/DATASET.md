# RecordGuard AI — Audited Synthetic Clinical Dataset Specification (v2.0)

## 1. Overview and Ethical Disclosure

The RecordGuard synthetic clinical contradiction dataset was designed and deterministically generated to train and benchmark the machine-learning classification and reconciliation component of RecordGuard AI.

> **CRITICAL ETHICAL DISCLOSURE:**
> All dataset examples and seeded clinical scenarios are entirely synthetic and fictional. No Protected Health Information (PHI), real patient names, social security numbers, medical record numbers, or actual patient encounter notes were used or scraped.

---

## 2. Rigorous Dataset Audit & Leakage Remediation (v1.0 vs v2.0)

### Audit Findings on Original Dataset (v1.0)
An exhaustive mathematical and lexical audit of the legacy dataset revealed severe data leakage and synthetic artifacts that explained the previously claimed "100% accuracy":
1. **Near-Total Cross-Split Duplicate Overlap**: In v1.0, 477 out of 480 test examples (**99.38%**) were character-for-character duplicates of pairs present in the training set. Only 184 unique statement pairs existed across the 2,240 training samples (8.2% uniqueness). The model was evaluating memorized identical strings rather than generalizing.
2. **Deterministic Shortcut Features**: Engineered features in `ml_features.py` encoded the ground truth directly:
   - `same_val` (`normalized_value_a == normalized_value_b`) correlated 100% with `CONSISTENT`.
   - `missing_b` used synthetic artifact prefix `"[No "` to correlate 94.3% with `INSUFFICIENT_EVIDENCE`.
   - `diff_date` (`date_a != date_b`) perfectly separated `TEMPORAL_CHANGE` from `POTENTIAL_CONTRADICTION`.

### Remediation Implemented in v2.0
1. **Strict Deduplication & Zero Leakage**: All statement pairs are deduplicated across the clinical universe prior to partitioning. Cross-split overlap between train and test is verified by automated test assertions to be **strictly 0.0%**.
2. **Multi-Stratum Generalization Evaluation**:
   - **Stratified Held-Out Test Set**: Tests in-distribution generalization on completely disjoint unique statement pairs.
   - **Group-Based Disjoint Split**: Evaluates generalization when entire template families and clinical syntaxes are withheld from training.
   - **Independent Unseen-Template Benchmark**: An out-of-distribution benchmark generated with novel clinical rules, unseen drugs (Semaglutide, Entresto, Meropenem, Pembrolizumab, Rituximab), unseen lab panels (Troponin I, Procalcitonin, BNP, D-Dimer, Ferritin), and unseen chronic diagnoses (Multiple Sclerosis, Systemic Lupus Erythematosus).
3. **Robust Clinical Feature Union**: Eliminated all magic string shortcuts. Replaced with genuine linguistic negation mismatch, clinical omission lexicons, numeric divergence ratios, and calibrated logistic regression.

---

## 3. Dataset Schema

Each example contains the following structured attributes:

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `example_id` | String | Unique synthetic identifier (e.g. `SYN-00142`, `UNSEEN-0012`) |
| `template_family` | String | Template group identifier used for disjoint group splitting |
| `category` | String | Clinical domain (`ALLERGY`, `MEDICATION`, `DIAGNOSIS`, `LAB_RESULT`) |
| `statement_a` | String | Extracted text statement from Document A |
| `statement_b` | String | Extracted text statement from Document B |
| `normalized_field` | String | Standardized clinical entity (e.g. `metformin`, `penicillin`) |
| `normalized_value_a`| String | Extracted canonical value in statement A (e.g. `500 mg`, `PRESENT`) |
| `normalized_value_b`| String | Extracted canonical value in statement B (e.g. `1000 mg`, `DISCONTINUED`) |
| `date_a` | String | ISO-8601 encounter date for Document A |
| `date_b` | String | ISO-8601 encounter date for Document B |
| `label` | String | Target ground-truth classification label |
| `explanation` | String | Human-readable explanation of clinical reconciliation rationale |
| `review_required` | Boolean | Whether professional clinician verification is recommended |

---

## 4. Classification Taxonomy

The dataset models four primary clinical reconciliation labels:

1. **`CONSISTENT`**: The two records corroborate the clinical entity with concordant or equivalent representations (e.g., brand-generic equivalence `Lasix 20mg` vs `Furosemide 20mg`, or unit conversion `Serum Creatinine 1.2 mg/dL` vs `106.1 umol/L`).
2. **`POTENTIAL_CONTRADICTION`**: Direct conflict without chronological separation (e.g., positive allergy mention vs `NKDA`, or conflicting dosages prescribed on identical dates).
3. **`TEMPORAL_CHANGE`**: Valid chronological modification over elapsed encounter time (e.g., active medication in January followed by documented discontinuation in March, or serial HbA1c lab tests).
4. **`INSUFFICIENT_EVIDENCE`**: Incomplete transfer records where one record omits a section entirely, unreviewed documentation, or ambiguous preliminary findings.

---

## 5. Partitions and Actual Sizes

### In-Distribution Partitions (Deduplicated, 0.0% Train-Test Overlap)
- **Train Set (70%)**: 2,520 unique pairs
- **Validation Set (15%)**: 540 unique pairs
- **Held-Out Stratified Test Set (15%)**: 540 unique pairs

### Class Distribution (Train Split, n=2,520)
| Label | Count | Proportion |
| :--- | :--- | :--- |
| `CONSISTENT` | 989 | 39.2% |
| `POTENTIAL_CONTRADICTION` | 825 | 32.7% |
| `TEMPORAL_CHANGE` | 573 | 22.7% |
| `INSUFFICIENT_EVIDENCE` | 133 | 5.3% |
| **Total** | **2,520** | **100.0%** |

### Evaluation Benchmarks
- **Group-Disjoint Test Set**: 971 unique pairs (entire template families held out)
- **Unseen-Template Benchmark**: 513 unique pairs (novel drugs, labs, diagnoses, and syntaxes)

---

## 6. Dataset Regeneration & Audit Commands

To inspect the dataset audit:
```bash
python backend/scripts/audit_existing_dataset.py
```

To deterministically regenerate all dataset partitions:
```bash
python backend/scripts/generate_dataset.py
```

To run baseline comparison and generalization evaluations:
```bash
python backend/scripts/evaluate_models.py
```
