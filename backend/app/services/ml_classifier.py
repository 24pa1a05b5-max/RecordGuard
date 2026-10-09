import json
import logging
from pathlib import Path
from typing import Optional, Dict, Any, Tuple
import joblib
import numpy as np
import pandas as pd
from backend.app.core.config import settings

logger = logging.getLogger(__name__)

class MLClassifierService:
    _instance: Optional["MLClassifierService"] = None
    
    def __init__(self):
        self.model_data = None
        self.is_loaded = False
        self.metrics = {}
        self.load_model()
        
    def load_model(self):
        if settings.MODEL_PATH.exists():
            try:
                from backend.app.services.ml_features import StatementTextExtractor, ClinicalStructuredFeatures
                self.model_data = joblib.load(settings.MODEL_PATH)
                self.is_loaded = True
                logger.info(f"Loaded ML model from {settings.MODEL_PATH}")
            except Exception as e:
                logger.error(f"Failed to load ML model artifact: {e}")
                self.is_loaded = False
        else:
            logger.warning(f"Model artifact not found at {settings.MODEL_PATH}")
            self.is_loaded = False

        if settings.METRICS_PATH.exists():
            try:
                with open(settings.METRICS_PATH, "r") as f:
                    self.metrics = json.load(f)
            except Exception as e:
                logger.error(f"Failed to load metrics: {e}")

    def predict(
        self,
        category: str,
        statement_a: str,
        statement_b: str,
        norm_val_a: Optional[str] = None,
        norm_val_b: Optional[str] = None,
        date_a: Optional[str] = None,
        date_b: Optional[str] = None
    ) -> Tuple[Optional[str], Optional[float]]:
        """
        Runs ML prediction on statement pair.
        Returns (predicted_class, confidence_float).
        """
        res = self.predict_detailed(
            category=category,
            statement_a=statement_a,
            statement_b=statement_b,
            norm_val_a=norm_val_a,
            norm_val_b=norm_val_b,
            date_a=date_a,
            date_b=date_b
        )
        if not res:
            return None, None
        return res["predicted_class"], res["confidence"]

    def predict_detailed(
        self,
        category: str,
        statement_a: str,
        statement_b: str,
        norm_val_a: Optional[str] = None,
        norm_val_b: Optional[str] = None,
        date_a: Optional[str] = None,
        date_b: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Runs cautious probabilistic inference with calibrated confidence metrics.
        Returns detailed prediction dictionary or None on error.
        """
        if not self.is_loaded or not self.model_data:
            return None

        try:
            df = pd.DataFrame([{
                "category": category,
                "statement_a": statement_a,
                "statement_b": statement_b,
                "normalized_value_a": norm_val_a,
                "normalized_value_b": norm_val_b,
                "date_a": date_a,
                "date_b": date_b
            }])

            pipeline = self.model_data["pipeline"]
            classes = list(self.model_data["classes"])

            probs = pipeline.predict_proba(df)[0]
            sorted_indices = np.argsort(probs)[::-1]
            top_idx = int(sorted_indices[0])
            second_idx = int(sorted_indices[1]) if len(sorted_indices) > 1 else top_idx

            pred_class = classes[top_idx]
            conf = float(probs[top_idx])
            second_conf = float(probs[second_idx]) if len(sorted_indices) > 1 else 0.0
            margin = conf - second_conf

            is_uncertain = bool(conf < 0.65 or margin < 0.15)

            # Cautious fallback: if classifier is highly uncertain between contradiction and temporal/consistent,
            # surface this for human review rather than pretending certainty.
            return {
                "predicted_class": pred_class,
                "confidence": round(conf, 4),
                "margin": round(margin, 4),
                "is_uncertain": is_uncertain,
                "all_probabilities": {
                    classes[i]: round(float(probs[i]), 4) for i in range(len(classes))
                },
                "disclaimer": "Preliminary algorithmic prediction. Does not establish medical diagnosis or truth."
            }
        except Exception as e:
            logger.error(f"Inference error: {e}")
            return None

# Singleton accessor
ml_service = MLClassifierService()
