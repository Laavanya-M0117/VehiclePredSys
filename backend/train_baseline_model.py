import os
import time
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.metrics import roc_auc_score, mean_absolute_error, r2_score, classification_report
from sklearn.inspection import permutation_importance

try:
    from dataset_generator import generate_obd_dataset
    from preprocessing import extract_ml_features, ML_FEATURE_COLS
except ImportError:
    from .dataset_generator import generate_obd_dataset
    from .preprocessing import extract_ml_features, ML_FEATURE_COLS

DEFAULT_MODELS_DIR = os.path.join(os.path.dirname(__file__), 'models')
DATA_DIR = os.path.join(os.path.dirname(__file__), '..', 'data')

def load_or_generate_dataset(data_path=None):
    if data_path is None:
        data_path = os.path.join(DATA_DIR, 're_classic350_physical_dataset.csv')
        
    if os.path.exists(data_path):
        print(f"[Training] Loading physical J-Series dataset from {data_path}...")
        df = pd.read_csv(data_path)
    else:
        print("[Training] Physical dataset not found on disk. Generating 10,000 J-Series records...")
        ds = generate_obd_dataset(n_samples=10000, random_seed=42)
        df = ds.to_pandas()
        os.makedirs(os.path.dirname(data_path), exist_ok=True)
        df.to_csv(data_path, index=False)
        print(f"[Training] Saved dataset to {data_path}")
        
    return df

def train_and_save_models(models_dir=None, data_path=None):
    if models_dir is None:
        models_dir = DEFAULT_MODELS_DIR
    os.makedirs(models_dir, exist_ok=True)
    
    start_time = time.time()
    raw_df = load_or_generate_dataset(data_path)
    
    print(f"[Training] Extracting domain-engineered diagnostic features (19 features)...")
    X = extract_ml_features(raw_df)
    y_class = raw_df['target_label'].values
    y_rul = raw_df['rul_hours'].values
    y_prob = raw_df['failure_probability'].values
    
    print(f"[Training] Dataset shape: X={X.shape}, Classes={np.bincount(y_class)}")
    
    # 80% Train, 20% Validation split (Stratified by fault class)
    X_train, X_val, y_c_train, y_c_val, y_r_train, y_r_val, y_p_train, y_p_val = train_test_split(
        X, y_class, y_rul, y_prob, test_size=0.2, random_state=42, stratify=y_class
    )
    
    # -------------------------------------------------------------
    # 1. Multi-Class Fault Classifier
    # -------------------------------------------------------------
    print("[Training] Fitting HistGradientBoostingClassifier (4 Classes)...")
    clf = HistGradientBoostingClassifier(
        max_iter=200,
        learning_rate=0.08,
        max_leaf_nodes=31,
        random_state=42
    )
    clf.fit(X_train, y_c_train)
    
    y_c_proba = clf.predict_proba(X_val)
    y_c_pred = clf.predict(X_val)
    auc_score = roc_auc_score(y_c_val, y_c_proba, multi_class='ovr')
    print(f"[Training] Classifier ROC-AUC Score: {auc_score:.4f}")
    
    class_names = ['NORMAL', 'OVERHEAT (P0217)', 'LEAN/MISFIRE (P0171)', 'ELECTRICAL (P0562)']
    report = classification_report(y_c_val, y_c_pred, target_names=class_names, output_dict=True)
    print("\n--- Classification Performance Report ---")
    for name in class_names:
        stats = report[name]
        print(f"  {name:<22}: Precision={stats['precision']:.3f}, Recall={stats['recall']:.3f}, F1={stats['f1-score']:.3f}")
    
    # -------------------------------------------------------------
    # 2. Remaining Useful Life (RUL) Regressor
    # -------------------------------------------------------------
    print("\n[Training] Fitting HistGradientBoostingRegressor for RUL estimation...")
    reg_rul = HistGradientBoostingRegressor(
        max_iter=200,
        learning_rate=0.08,
        max_leaf_nodes=31,
        random_state=42
    )
    reg_rul.fit(X_train, y_r_train)
    y_r_pred = reg_rul.predict(X_val)
    rul_mae = mean_absolute_error(y_r_val, y_r_pred)
    rul_r2 = r2_score(y_r_val, y_r_pred)
    print(f"[Training] RUL Regressor MAE: {rul_mae:.2f} hours (R2: {rul_r2:.4f})")
    
    # -------------------------------------------------------------
    # 3. Continuous Failure Probability Regressor
    # -------------------------------------------------------------
    print("[Training] Fitting HistGradientBoostingRegressor for Failure Probability...")
    reg_prob = HistGradientBoostingRegressor(
        max_iter=200,
        learning_rate=0.08,
        max_leaf_nodes=31,
        random_state=42
    )
    reg_prob.fit(X_train, y_p_train)
    y_p_pred = reg_prob.predict(X_val)
    prob_mae = mean_absolute_error(y_p_val, y_p_pred)
    prob_r2 = r2_score(y_p_val, y_p_pred)
    print(f"[Training] Failure Probability MAE: {prob_mae:.4f} (R2: {prob_r2:.4f})")
    
    # -------------------------------------------------------------
    # 4. Permutation Feature Importances
    # -------------------------------------------------------------
    print("[Training] Computing permutation feature importances on validation set...")
    perm_res = permutation_importance(clf, X_val, y_c_val, n_repeats=5, random_state=42)
    importances = {}
    for i, col in enumerate(ML_FEATURE_COLS):
        importances[col] = float(perm_res.importances_mean[i])
        
    top_features = sorted(importances.items(), key=lambda x: x[1], reverse=True)[:6]
    print("  Top 6 Diagnostic Features by Importance:")
    for feat, imp in top_features:
        print(f"    - {feat:<25}: {imp:.4f}")
        
    # Save artifacts to models directory
    joblib.dump(clf, os.path.join(models_dir, 'triage_classifier.joblib'))
    joblib.dump(reg_rul, os.path.join(models_dir, 'rul_regressor.joblib'))
    joblib.dump(reg_prob, os.path.join(models_dir, 'prob_regressor.joblib'))
    
    metadata = {
        'trained_at': time.strftime('%Y-%m-%d %H:%M:%S'),
        'val_auc': float(auc_score),
        'rul_mae': float(rul_mae),
        'rul_r2': float(rul_r2),
        'prob_mae': float(prob_mae),
        'prob_r2': float(prob_r2),
        'features': ML_FEATURE_COLS,
        'feature_importances': importances,
        'training_duration_sec': round(time.time() - start_time, 2)
    }
    joblib.dump(metadata, os.path.join(models_dir, 'model_metadata.joblib'))
    print(f"\n[Training] [SUCCESS] All 3 models and metadata successfully saved to {models_dir}/")
    return metadata

if __name__ == '__main__':
    train_and_save_models()
