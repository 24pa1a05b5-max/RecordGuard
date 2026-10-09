import re
from typing import List, Dict, Any, Optional
import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, TransformerMixin

from backend.app.services.normalization import parse_clinical_date

OMISSION_REGEX = re.compile(
    r"\b(unreviewed|omitted|omits|absent|not documented|unmentioned|incomplete|no record|no mention|not assessed|deferred|pending|not evaluated|section absent|focused clinical encounter|focused encounter|cannot be determined|unknown)\b",
    re.IGNORECASE
)

NEGATION_REGEX = re.compile(
    r"\b(no|denies|denied|nkda|nka|negative|discontinued|stopped|cessation|ruled out|free of|without|non-contributory)\b",
    re.IGNORECASE
)

TEMPORAL_REGEX = re.compile(
    r"\b(increased|decreased|titrated|adjusted|switched|transitioned|changed from|subsequent|follow-up|prior|previously|repeat|trended|now taking|newly prescribed|discontinued on|reduced to|normalized|elevated|post-treatment|recovery|resolved)\b",
    re.IGNORECASE
)

NUMBER_REGEX = re.compile(r"\b\d+(?:\.\d+)?\b")

class StatementTextExtractor(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None):
        return self
    def transform(self, X):
        return [
            f"Category: {cat} | Statement A: {a} | Statement B: {b}"
            for cat, a, b in zip(X["category"], X["statement_a"], X["statement_b"])
        ]

class ClinicalStructuredFeatures(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None):
        return self
    def transform(self, X):
        features = []
        for _, row in X.iterrows():
            stmt_a = str(row.get("statement_a", "")).lower()
            stmt_b = str(row.get("statement_b", "")).lower()
            val_a = str(row.get("normalized_value_a", "")).strip().lower()
            val_b = str(row.get("normalized_value_b", "")).strip().lower()
            cat = str(row.get("category", "")).upper()

            # 1. Omission & Evidence Insufficiency Signals
            omission_a = 1.0 if OMISSION_REGEX.search(stmt_a) or val_a in ["unmentioned", "unknown", "none", "nan", ""] else 0.0
            omission_b = 1.0 if OMISSION_REGEX.search(stmt_b) or val_b in ["unmentioned", "unknown", "none", "nan", ""] else 0.0
            either_omission = max(omission_a, omission_b)

            # 2. Negation Polarity & Mismatch
            neg_a = 1.0 if NEGATION_REGEX.search(stmt_a) else 0.0
            neg_b = 1.0 if NEGATION_REGEX.search(stmt_b) else 0.0
            neg_mismatch = 1.0 if (neg_a != neg_b) else 0.0
            both_neg = 1.0 if (neg_a == 1.0 and neg_b == 1.0) else 0.0

            # 3. Temporal Trajectory & Elapsed Time
            d_a = parse_clinical_date(str(row.get("date_a", "")))
            d_b = parse_clinical_date(str(row.get("date_b", "")))
            if d_a and d_b:
                days_gap = abs((d_b - d_a).days)
                log_days = float(np.log1p(days_gap))
                is_same_day = 1.0 if days_gap == 0 else 0.0
                is_multi_day = 1.0 if days_gap > 0 else 0.0
                is_large_gap = 1.0 if days_gap >= 14 else 0.0
            else:
                log_days = 0.0
                is_same_day = 0.0
                is_multi_day = 0.0
                is_large_gap = 0.0

            has_temp_word = 1.0 if TEMPORAL_REGEX.search(stmt_a) or TEMPORAL_REGEX.search(stmt_b) else 0.0

            # 4. Numeric Extraction & Divergence
            nums_a = [float(n) for n in NUMBER_REGEX.findall(stmt_a)]
            nums_b = [float(n) for n in NUMBER_REGEX.findall(stmt_b)]
            has_nums = 1.0 if (nums_a and nums_b) else 0.0
            if nums_a and nums_b:
                nums_equal = 1.0 if abs(nums_a[0] - nums_b[0]) < 1e-4 else 0.0
                ratio = min(nums_a[0], nums_b[0]) / max(max(nums_a[0], nums_b[0]), 1e-6)
            else:
                nums_equal = 0.0
                ratio = 1.0

            # 5. Lexical Overlap & Length Dynamics
            tokens_a = set(re.findall(r"\w+", stmt_a))
            tokens_b = set(re.findall(r"\w+", stmt_b))
            union_len = len(tokens_a | tokens_b)
            jaccard = len(tokens_a & tokens_b) / union_len if union_len > 0 else 0.0
            len_ratio = min(len(stmt_a), len(stmt_b)) / max(max(len(stmt_a), len(stmt_b)), 1)

            # 6. Normalized Value Equality
            valid_vals = 1.0 if (val_a not in ["unmentioned", "unknown", "nan", ""] and val_b not in ["unmentioned", "unknown", "nan", ""]) else 0.0
            same_val = 1.0 if (valid_vals == 1.0 and val_a == val_b) else 0.0

            # 7. Clinical Category One-Hot Flags
            is_allergy = 1.0 if cat == "ALLERGY" else 0.0
            is_med = 1.0 if cat == "MEDICATION" else 0.0
            is_diag = 1.0 if cat == "DIAGNOSIS" else 0.0
            is_lab = 1.0 if cat == "LAB_RESULT" else 0.0

            # 8. Clinical Cross-Feature Interactions
            temporal_numeric_shift = 1.0 if (is_multi_day == 1.0 and nums_equal == 0.0 and has_nums == 1.0 and neg_mismatch == 0.0) else 0.0
            same_day_numeric_conflict = 1.0 if (is_same_day == 1.0 and nums_equal == 0.0 and has_nums == 1.0 and neg_mismatch == 0.0) else 0.0
            temporal_value_shift = 1.0 if (is_multi_day == 1.0 and same_val == 0.0 and valid_vals == 1.0 and neg_mismatch == 0.0) else 0.0
            temporal_trajectory = 1.0 if (is_multi_day == 1.0 and has_temp_word == 1.0) else 0.0

            features.append([
                omission_a, omission_b, either_omission,
                neg_a, neg_b, neg_mismatch, both_neg,
                log_days, is_same_day, is_multi_day, is_large_gap, has_temp_word,
                has_nums, nums_equal, ratio,
                jaccard, len_ratio,
                valid_vals, same_val,
                is_allergy, is_med, is_diag, is_lab,
                temporal_numeric_shift, same_day_numeric_conflict, temporal_value_shift, temporal_trajectory
            ])
        return np.array(features)
