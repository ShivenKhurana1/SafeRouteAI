#!/usr/bin/env python3
"""
Fine-tuning script for the Path Finding Model
Incrementally updates the model with new data
"""

import pandas as pd
import numpy as np
import pickle
import json
import os
from datetime import datetime
from pathlib import Path
import argparse
from train_with_realtime import EnhancedPathFindingTrainer

def fine_tune_model(
    existing_model_path: str,
    new_data_path: str,
    output_path: str,
    learning_rate: float = 0.1,
    epochs: int = 5
):
    """
    Fine-tune an existing model with new data
    
    Args:
        existing_model_path: Path to existing trained model
        new_data_path: Path to new training data CSV
        output_path: Path to save fine-tuned model
        learning_rate: Learning rate for fine-tuning (for gradient boosting)
        epochs: Number of fine-tuning iterations
    """
    print("=" * 60)
    print("Fine-tuning Path Finding Model")
    print("=" * 60)
    
    # Load existing model
    if not os.path.exists(existing_model_path):
        raise FileNotFoundError(f"Model not found: {existing_model_path}")
    
    print(f"Loading existing model from {existing_model_path}...")
    with open(existing_model_path, 'rb') as f:
        model_data = pickle.load(f)
    
    existing_model = model_data['model']
    existing_scaler = model_data['scaler']
    feature_names = model_data['feature_names']
    
    # Load new data
    print(f"Loading new training data from {new_data_path}...")
    new_data = pd.read_csv(new_data_path)
    
    # Validate columns
    required_cols = feature_names + ['safety_score']
    missing_cols = set(required_cols) - set(new_data.columns)
    if missing_cols:
        raise ValueError(f"Missing required columns: {missing_cols}")
    
    print(f"Loaded {len(new_data)} new samples")
    
    # Prepare data
    X_new = new_data[feature_names]
    y_new = new_data['safety_score']
    
    # Scale using existing scaler (important for consistency)
    X_new_scaled = existing_scaler.transform(X_new)
    
    # Fine-tune model
    print(f"\nFine-tuning model for {epochs} epochs...")
    
    trainer = EnhancedPathFindingTrainer(use_realtime=False)
    trainer.model = existing_model
    trainer.scaler = existing_scaler
    trainer.feature_names = feature_names
    
    # For RandomForest, we can't directly fine-tune, so we'll retrain with combined data
    # For GradientBoosting, we can use warm_start
    if hasattr(existing_model, 'warm_start'):
        # Gradient Boosting - can fine-tune
        existing_model.warm_start = True
        existing_model.n_estimators += epochs * 10  # Add more trees
        existing_model.learning_rate = learning_rate
        
        for epoch in range(epochs):
            existing_model.fit(X_new_scaled, y_new)
            pred = existing_model.predict(X_new_scaled)
            mse = np.mean((y_new - pred) ** 2)
            r2 = 1 - np.sum((y_new - pred) ** 2) / np.sum((y_new - np.mean(y_new)) ** 2)
            print(f"  Epoch {epoch + 1}/{epochs}: MSE={mse:.4f}, R²={r2:.4f}")
    else:
        # RandomForest - retrain with combined approach
        print("  RandomForest detected - using incremental learning approach...")
        
        # Get predictions from existing model
        existing_pred = existing_model.predict(X_new_scaled)
        
        # Calculate residuals (what the model got wrong)
        residuals = y_new - existing_pred
        
        # Train a new model on the residuals (error correction)
        from sklearn.ensemble import RandomForestRegressor
        correction_model = RandomForestRegressor(
            n_estimators=50,
            max_depth=10,
            random_state=42,
            n_jobs=-1
        )
        correction_model.fit(X_new_scaled, residuals)
        
        # Combine models (ensemble approach)
        class FineTunedModel:
            def __init__(self, base_model, correction_model):
                self.base_model = base_model
                self.correction_model = correction_model
            
            def predict(self, X):
                base_pred = self.base_model.predict(X)
                correction = self.correction_model.predict(X)
                return base_pred + correction * 0.5  # Weighted correction
        
        trainer.model = FineTunedModel(existing_model, correction_model)
        print("  ✓ Fine-tuned using ensemble approach")
    
    # Evaluate fine-tuned model
    print("\nEvaluating fine-tuned model...")
    pred = trainer.model.predict(X_new_scaled)
    mse = np.mean((y_new - pred) ** 2)
    mae = np.mean(np.abs(y_new - pred))
    r2 = 1 - np.sum((y_new - pred) ** 2) / np.sum((y_new - np.mean(y_new)) ** 2)
    
    print(f"  Fine-tuned Model Performance:")
    print(f"    MSE: {mse:.4f}")
    print(f"    MAE: {mae:.4f}")
    print(f"    R²: {r2:.4f}")
    
    # Update training history
    if 'training_history' in model_data:
        history = model_data['training_history']
    else:
        history = []
    
    history.append({
        'epoch': len(history),
        'type': 'fine_tune',
        'train_mse': mse,
        'test_mse': mse,  # Using same data for simplicity
        'train_r2': r2,
        'test_r2': r2,
        'timestamp': datetime.now().isoformat(),
        'n_new_samples': len(new_data)
    })
    
    # Save fine-tuned model
    print(f"\nSaving fine-tuned model to {output_path}...")
    model_data['model'] = trainer.model
    model_data['training_history'] = history
    model_data['metadata']['last_fine_tune'] = datetime.now().isoformat()
    model_data['metadata']['fine_tune_samples'] = len(new_data)
    
    with open(output_path, 'wb') as f:
        pickle.dump(model_data, f)
    
    # Update JSON metadata
    json_path = output_path.replace('.pkl', '.json')
    if os.path.exists(json_path):
        with open(json_path, 'r') as f:
            json_data = json.load(f)
    else:
        json_data = {}
    
    json_data['last_fine_tune'] = datetime.now().isoformat()
    json_data['fine_tune_samples'] = len(new_data)
    json_data['fine_tune_performance'] = {
        'mse': float(mse),
        'mae': float(mae),
        'r2': float(r2)
    }
    json_data['training_history'] = history
    
    with open(json_path, 'w') as f:
        json.dump(json_data, f, indent=2)
    
    print("=" * 60)
    print("Fine-tuning Complete!")
    print(f"Fine-tuned model saved to: {output_path}")
    print("=" * 60)
    
    return trainer.model

def main():
    parser = argparse.ArgumentParser(description='Fine-tune Path Finding Model')
    parser.add_argument('--model', type=str, required=True, help='Path to existing model')
    parser.add_argument('--data', type=str, required=True, help='Path to new training data')
    parser.add_argument('--output', type=str, required=True, help='Output path for fine-tuned model')
    parser.add_argument('--epochs', type=int, default=5, help='Number of fine-tuning epochs')
    parser.add_argument('--lr', type=float, default=0.1, help='Learning rate')
    
    args = parser.parse_args()
    
    fine_tune_model(
        existing_model_path=args.model,
        new_data_path=args.data,
        output_path=args.output,
        learning_rate=args.lr,
        epochs=args.epochs
    )

if __name__ == '__main__':
    main()


