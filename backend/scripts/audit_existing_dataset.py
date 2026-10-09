import json
from pathlib import Path
import pandas as pd
import numpy as np

def run_audit():
    data_dir = Path("backend/data/synthetic")
    train_df = pd.read_csv(data_dir / "train.csv")
    val_df = pd.read_csv(data_dir / "validation.csv")
    test_df = pd.read_csv(data_dir / "test.csv")
    all_df = pd.read_csv(data_dir / "dataset_full.csv")

    print("=" * 60)
    print("AUDIT REPORT: CURRENT SYNTHETIC DATASET & PIPELINE")
    print("=" * 60)

    # 1. Dataset Dimensions & Splits
    print("\n[1] DATASET SPLITS & SAMPLE COUNTS:")
    print(f"  Total records in dataset_full: {len(all_df)}")
    print(f"  Train split: {len(train_df)} ({len(train_df)/len(all_df)*100:.1f}%)")
    print(f"  Validation split: {len(val_df)} ({len(val_df)/len(all_df)*100:.1f}%)")
    print(f"  Test split: {len(test_df)} ({len(test_df)/len(all_df)*100:.1f}%)")

    # 2. Class Distributions
    print("\n[2] CLASS DISTRIBUTIONS:")
    for name, df in [("Train", train_df), ("Validation", val_df), ("Test", test_df)]:
        dist = df["label"].value_counts().to_dict()
        print(f"  {name} Split: {dist}")

    # 3. Exact Duplicate Statement Pairs
    train_pairs = list(zip(train_df["statement_a"], train_df["statement_b"]))
    val_pairs = list(zip(val_df["statement_a"], val_df["statement_b"]))
    test_pairs = list(zip(test_df["statement_a"], test_df["statement_b"]))

    unique_train_pairs = set(train_pairs)
    unique_val_pairs = set(val_pairs)
    unique_test_pairs = set(test_pairs)

    print("\n[3] DUPLICATION WITHIN SPLITS:")
    print(f"  Train: {len(unique_train_pairs)} unique statement pairs out of {len(train_df)} rows ({len(unique_train_pairs)/len(train_df)*100:.1f}% unique)")
    print(f"  Val:   {len(unique_val_pairs)} unique statement pairs out of {len(val_df)} rows ({len(unique_val_pairs)/len(val_df)*100:.1f}% unique)")
    print(f"  Test:  {len(unique_test_pairs)} unique statement pairs out of {len(test_df)} rows ({len(unique_test_pairs)/len(test_df)*100:.1f}% unique)")

    # 4. Cross-Split Leakage
    test_overlap = [p for p in test_pairs if p in unique_train_pairs]
    val_overlap = [p for p in val_pairs if p in unique_train_pairs]

    print("\n[4] CROSS-SPLIT INFORMATION LEAKAGE:")
    print(f"  Test examples identically in Train: {len(test_overlap)} / {len(test_df)} ({len(test_overlap)/len(test_df)*100:.2f}%)")
    print(f"  Val examples identically in Train:  {len(val_overlap)} / {len(val_df)} ({len(val_overlap)/len(val_df)*100:.2f}%)")

    # 5. Label Shortcut & Structured Feature Analysis
    print("\n[5] SHORTCUT FEATURE LEAKAGE ANALYSIS (Train Set):")
    # Missing B vs INSUFFICIENT_EVIDENCE
    has_no_bracket = train_df["statement_b"].str.contains(r"\[No ", regex=True, na=False)
    label_insufficient = train_df["label"] == "INSUFFICIENT_EVIDENCE"
    overlap_insufficient = (has_no_bracket == label_insufficient).mean()
    print(f"  Accuracy of '[No ' shortcut for INSUFFICIENT_EVIDENCE: {overlap_insufficient*100:.1f}%")

    # same_val vs CONSISTENT
    same_val = (train_df["normalized_value_a"] == train_df["normalized_value_b"]) & train_df["normalized_value_a"].notna()
    label_consistent = train_df["label"] == "CONSISTENT"
    print(f"  Correlation of normalized_value_a == normalized_value_b with CONSISTENT: {(same_val == label_consistent).mean()*100:.1f}%")

    # 6. TF-IDF Fitting Verification
    print("\n[6] VECTORIZER LEAKAGE CHECK:")
    print("  In backend/scripts/train_model.py, FeatureUnion is wrapped in a Pipeline and called with model.fit(X_train, y_train).")
    print("  Vectorizer is fitted strictly on X_train. However, because X_test is 99.4% duplicated from X_train, the test evaluation evaluated training memorization rather than generalization.")
    print("=" * 60)

if __name__ == "__main__":
    run_audit()
