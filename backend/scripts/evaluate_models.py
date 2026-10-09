import json
import sys
from pathlib import Path
import joblib
import numpy as np
import pandas as pd
from sklearn.dummy import DummyClassifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, f1_score
from sklearn.pipeline import FeatureUnion, Pipeline

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backend.app.services.ml_features import StatementTextExtractor, ClinicalStructuredFeatures

DATA_DIR = Path("backend/data/synthetic")
MODEL_DIR = Path("backend/models")

def evaluate_predictions(y_true, y_pred, labels):
    acc = float(accuracy_score(y_true, y_pred))
    macro_f1 = float(f1_score(y_true, y_pred, average="macro", zero_division=0))
    rep = classification_report(y_true, y_pred, labels=labels, output_dict=True, zero_division=0)
    cm = confusion_matrix(y_true, y_pred, labels=labels).tolist()
    return {
        "accuracy": round(acc, 4),
        "macro_f1": round(macro_f1, 4),
        "report": rep,
        "confusion_matrix": cm
    }

def run_evaluation_suite():
    train_df = pd.read_csv(DATA_DIR / "train.csv")
    val_df = pd.read_csv(DATA_DIR / "validation.csv")
    test_strat_df = pd.read_csv(DATA_DIR / "test.csv")
    test_group_df = pd.read_csv(DATA_DIR / "test_group_disjoint.csv")
    test_unseen_df = pd.read_csv(DATA_DIR / "test_unseen_templates.csv")

    cols = ["category", "statement_a", "statement_b", "normalized_value_a", "normalized_value_b", "date_a", "date_b"]
    X_train = train_df[cols]
    y_train = train_df["label"]

    labels = sorted(list(y_train.unique()))
    print(f"Classes ({len(labels)}): {labels}")
    print(f"Train size: {len(train_df)}, Val size: {len(val_df)}")
    print(f"Test Stratified: {len(test_strat_df)}, Test Group-Disjoint: {len(test_group_df)}, Test Unseen: {len(test_unseen_df)}")

    # 1. Baseline 1: Dummy Majority Classifier
    print("\n" + "=" * 60)
    print("BASELINE 1: DUMMY MAJORITY CLASSIFIER")
    print("=" * 60)
    dummy = DummyClassifier(strategy="most_frequent")
    dummy.fit(X_train, y_train)

    for name, df in [("Stratified Held-out", test_strat_df), ("Group Disjoint", test_group_df), ("Unseen Benchmark", test_unseen_df)]:
        y_test = df["label"]
        preds = dummy.predict(df[cols])
        res = evaluate_predictions(y_test, preds, labels)
        print(f"  [{name}] Accuracy: {res['accuracy']:.4f} | Macro F1: {res['macro_f1']:.4f}")

    # 2. Baseline 2: Pure Text-Only TF-IDF (No clinical features, word 1-2 ngrams)
    print("\n" + "=" * 60)
    print("BASELINE 2: TEXT-ONLY TF-IDF LOGISTIC REGRESSION")
    print("=" * 60)
    tfidf_baseline = Pipeline([
        ("extractor", StatementTextExtractor()),
        ("tfidf", TfidfVectorizer(ngram_range=(1, 2), max_features=2500)),
        ("clf", LogisticRegression(max_iter=500, class_weight="balanced", random_state=42))
    ])
    tfidf_baseline.fit(X_train, y_train)

    for name, df in [("Stratified Held-out", test_strat_df), ("Group Disjoint", test_group_df), ("Unseen Benchmark", test_unseen_df)]:
        y_test = df["label"]
        preds = tfidf_baseline.predict(df[cols])
        res = evaluate_predictions(y_test, preds, labels)
        print(f"  [{name}] Accuracy: {res['accuracy']:.4f} | Macro F1: {res['macro_f1']:.4f}")

    # 3. Existing Model Artifact Evaluation
    print("\n" + "=" * 60)
    print("EXISTING MODEL (FROM ARTIFACT)")
    print("=" * 60)
    existing_artifact = joblib.load(MODEL_DIR / "contradiction_classifier.joblib")
    existing_pipeline = existing_artifact["pipeline"]

    for name, df in [("Stratified Held-out", test_strat_df), ("Group Disjoint", test_group_df), ("Unseen Benchmark", test_unseen_df)]:
        y_test = df["label"]
        preds = existing_pipeline.predict(df[cols])
        res = evaluate_predictions(y_test, preds, labels)
        print(f"\n--- [{name}] (n={len(df)}) ---")
        print(f"Accuracy: {res['accuracy']:.4f} | Macro F1: {res['macro_f1']:.4f}")
        print("Confusion Matrix:")
        print("  Labels:", labels)
        for row_label, row_vals in zip(labels, res["confusion_matrix"]):
            print(f"  {row_label:25s}: {row_vals}")
        print("Per-class Metrics:")
        for lbl in labels:
            m = res["report"].get(lbl, {})
            print(f"  {lbl:25s} P: {m.get('precision', 0):.4f} | R: {m.get('recall', 0):.4f} | F1: {m.get('f1-score', 0):.4f} | Support: {m.get('support', 0)}")

    # Error Inspection on Unseen Benchmark
    df_eval = test_unseen_df.copy()
    df_eval["pred"] = existing_pipeline.predict(df_eval[cols])
    errors = df_eval[df_eval["label"] != df_eval["pred"]]
    print(f"\n" + "=" * 60)
    print(f"UNSEEN BENCHMARK ERROR ANALYSIS (Total Errors: {len(errors)} / {len(df_eval)})")
    print("=" * 60)
    for idx, r in errors.iterrows():
        print(f"[{r['example_id']}] True: {r['label']} | Predicted: {r['pred']}")
        print(f"  Template: {r['template_family']} | Category: {r['category']}")
        print(f"  Statement A: {r['statement_a']}")
        print(f"  Statement B: {r['statement_b']}")
        print(f"  Dates: A={r['date_a']}, B={r['date_b']} | Values: A='{r['normalized_value_a']}', B='{r['normalized_value_b']}'")
        print()

if __name__ == "__main__":
    run_evaluation_suite()
