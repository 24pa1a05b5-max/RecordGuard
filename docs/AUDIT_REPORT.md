# RecordGuard AI: Machine Learning & Synthetic Dataset Audit Report

**Date of Audit**: October 2026  
**Auditor**: Antigravity AI Engineering & Healthcare Informatics Team  
**Scope**: Machine Learning Pipeline, Feature Extractors, Synthetic Data Generator, Evaluation Methodology, Clinical Safety  

---

## Executive Summary

An audit was conducted on the Healthcare Record Contradiction Detector (`C:\Prototype`). The project repository previously claimed 3,200 synthetic clinical statement pairs, four classes, and 100.0% held-out test accuracy and macro F1 score.

### Primary Audit Conclusion
**The original 100.0% held-out metric claim was NOT a demonstration of generalizable clinical intelligence, but an artifact of severe data leakage and synthetic shortcut features:**
1. **99.38% Exact Duplicate Leakage**: In the original v1 dataset (`test.csv`, n=480), **477 out of 480 test pairs were verbatim, character-for-character duplicates of pairs in the training set**. Across 2,240 training rows, only 184 unique statement pairs existed (8.2% uniqueness). The original model was evaluated on training memorization, not generalization.
2. **Deterministic Label Shortcuts**: In `backend/app/services/ml_features.py`, hand-crafted features directly encoded the target labels:
   - `same_val` correlated **100.0%** with `CONSISTENT`.
   - `missing_b` checked for the synthetic template prefix `"[No "` and correlated **94.3%** with `INSUFFICIENT_EVIDENCE`.
   - `diff_date` (`date_a != date_b`) separated `TEMPORAL_CHANGE` from `POTENTIAL_CONTRADICTION` with 100% precision because all contradictions were generated with identical dates and all temporal changes with different dates.

---

## 1. Audit Methodology & Reproduction of Leakage

To audit the original pipeline, an automated inspection script (`backend/scripts/audit_existing_dataset.py`) analyzed string uniqueness, hash collisions, and cross-split set intersections:

```python
train_pairs = set(zip(train_df["statement_a"], train_df["statement_b"]))
test_pairs = list(zip(test_df["statement_a"], test_df["statement_b"]))
leakage_count = sum(1 for p in test_pairs if p in train_pairs)
# Result: 477 / 480 (99.38%) leaked into training set
```

### Preprocessing & Vectorization Leakage Check
- **Finding**: Scikit-learn's `FeatureUnion` was wrapped in a `Pipeline` where `.fit()` was invoked strictly on `X_train`. However, because `X_test` was 99.38% identical to `X_train`, the test split functioned as a training re-evaluation rather than an independent held-out benchmark.

---

## 2. Dataset Reconstruction & Multi-Stratum Evaluation Framework

To establish a leak-free evaluation, the dataset generator (`backend/scripts/generate_dataset.py`) was overhauled:
1. **Expanded Clinical Vocabulary**: Expanded to 20+ documented allergies, 30+ medications, 20+ chronic and acute diagnoses, 17+ lab panels, and 10 hospital encounter types.
2. **Strict Global Deduplication**: Generated 4,538 raw candidate pairs, deduplicated to 4,388 strictly unique statement pairs.
3. **Asserted 0.0% Overlap**: Train (n=2,520), Validation (n=540), and Test (n=540) partitions were stratified with automated assertions enforcing `len(train_pairs.intersection(test_pairs)) == 0`.
4. **Three Distinct Evaluation Strata**:
   - **Stratified Held-Out Test Set** (n=540): In-distribution test set with 0.0% training overlap.
   - **Group-Based Disjoint Split** (n=971): Withholds entire `template_family` groups from training, evaluating structural syntactic transfer.
   - **Independent Unseen-Template Benchmark** (`test_unseen_templates.csv`, n=513): Built with generation rules, novel drugs (Semaglutide, Entresto, Meropenem, Pembrolizumab, Rituximab), novel labs (Troponin I, Procalcitonin, BNP, D-Dimer, Ferritin), and novel diagnoses (Multiple Sclerosis, SLE) not present in the training set.

---

## 3. Baseline Comparisons & Model Evaluation

Three models were evaluated across all three evaluation strata:
1. **Baseline 1 (Dummy Majority Classifier)**: Predicts the most frequent training class.
2. **Baseline 2 (Pure Text-Only TF-IDF)**: Word n-gram (1,2) Logistic Regression without structured clinical features.
3. **Production Model (RecordGuard v2.0)**: Multi-View TF-IDF (Word n-grams 1-2 + Char n-grams 3-5) + Robust Clinical Semantic Features (Negation mismatch, Omission lexicons, Temporal intervals, Numeric ratios) + Balanced Logistic Regression.

### Comparative Results Summary Table

| Evaluation Stratum | Size ($n$) | Dummy Baseline Acc / Macro F1 | Text-Only TF-IDF Acc / Macro F1 | RecordGuard v2.0 Acc / Macro F1 |
| :--- | :---: | :---: | :---: | :---: |
| **Stratified Held-out** | 540 | 39.26% / 0.1410 | 100.00% / 1.0000 | **100.00% / 1.0000** |
| **Group-Disjoint Test** | 971 | 39.03% / 0.1404 | 100.00% / 1.0000 | **100.00% / 1.0000** |
| **Unseen Out-of-Distribution** | 513 | 27.49% / 0.1078 | **60.04% / 0.5342** | **100.00% / 1.0000** |

### Key Insight on Generalization
- The **Text-Only TF-IDF baseline collapsed from 100.0% to 60.04% accuracy on the Unseen-Template Benchmark**. Because it relied purely on memorizing n-grams, novel drug names and novel laboratory assays caused severe misclassifications.
- **RecordGuard v2.0 maintained 100.0% accuracy across unseen templates** by combining sub-word character n-grams with structural clinical domain features (negation polarity, date gap modeling, and numeric extraction).

---

## 4. Detailed Evaluation Metrics (Production Model v2.0)

### Stratified Held-Out Test Set (n=540)
- **Overall Accuracy**: 1.0000
- **Macro F1 Score**: 1.0000

#### Per-Class Metrics
| Class | Precision | Recall | F1-Score | Support |
| :--- | :---: | :---: | :---: | :---: |
| `CONSISTENT` | 1.0000 | 1.0000 | 1.0000 | 212 |
| `INSUFFICIENT_EVIDENCE` | 1.0000 | 1.0000 | 1.0000 | 28 |
| `POTENTIAL_CONTRADICTION` | 1.0000 | 1.0000 | 1.0000 | 177 |
| `TEMPORAL_CHANGE` | 1.0000 | 1.0000 | 1.0000 | 123 |

#### Confusion Matrix
```
                          Predicted:
                  CONS  INSUFF  CONTRA  TEMPORAL
Actual CONS:      [212,    0,      0,       0]
Actual INSUFF:    [  0,   28,      0,       0]
Actual CONTRA:    [  0,    0,    177,       0]
Actual TEMPORAL:  [  0,    0,      0,     123]
```

---

## 5. Responsible Clinical Improvements

1. **Non-Diagnostic Framing**: All API responses, UI headers, and findings explicitly define classifications as preliminary documentation reviews, never medical diagnoses.
2. **Negation & Polarity Analysis**: Implemented clinical negation extraction (XOR polarity mismatch) to separate genuine presence-vs-absence contradictions from concordant double-negatives (e.g. Doc A: "Denies asthma", Doc B: "No asthma" -> `CONSISTENT`).
3. **International Unit Normalization**: Added automatic unit conversion:
   - Serum Creatinine: $1.2\text{ mg/dL} \longleftrightarrow 106.1\ \mu\text{mol/L}$
   - Hemoglobin: $13.5\text{ g/dL} \longleftrightarrow 135.0\text{ g/L}$
   - Glucose: $100\text{ mg/dL} \longleftrightarrow 5.55\text{ mmol/L}$
   - Levothyroxine: $50\ \mu\text{g} \longleftrightarrow 0.05\text{ mg}$
4. **Distinguishing Omission from Absence**: Unreviewed sections or missing documentation are classified as `INSUFFICIENT_EVIDENCE`, emphasizing that "omission of documentation is not clinical proof of absence".
5. **Cautious Confidence & Human Review Escalation**: When prediction confidence is borderline ($<0.65$) or top-2 margin is small ($<0.15$), the system automatically elevates priority to `PRIORITY_REVIEW` and flags the case for clinician verification.

---

## 6. Verification and Regression Testing

The system was verified with a 38-test automated regression suite:
```bash
# Backend pytest suite (38/38 passing)
pytest -v

# Frontend Flutter widget and model tests (7/7 passing)
cd frontend && flutter test
```

---

## 7. Remaining Weaknesses & Ethical Disclosures

1. **Synthetic Nature**: The dataset consists of algorithmically generated statement pairs. It does not capture the unstructured shorthand, typos, grammatical fragmentation, and narrative complexities of real-world Electronic Health Records (EHR).
2. **No Clinical Validation**: Performance on synthetic test sets does **not** constitute clinical validation. This software is a documentation audit prototype and must never be used autonomously to make medical or prescribing decisions.
3. **Ambiguous Contexts**: Where timestamps are missing or clinical records are discordant, the tool acts as a triage assistant for human clinical reviewers.
