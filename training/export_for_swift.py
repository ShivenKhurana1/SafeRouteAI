#!/usr/bin/env python3
"""
Export trained model for Swift/iOS integration
Converts Python model to JSON format that Swift can use
"""

import pickle
import json
import numpy as np
from pathlib import Path
import argparse

def export_model_for_swift(model_path: str, output_dir: str = '../SafeRouteAI/AI/'):
    """
    Export trained model to JSON format for Swift integration
    
    Args:
        model_path: Path to trained .pkl model file
        output_dir: Directory to save exported files
    """
    print("=" * 60)
    print("Exporting Model for Swift/iOS")
    print("=" * 60)
    
    # Load model
    print(f"Loading model from {model_path}...")
    with open(model_path, 'rb') as f:
        model_data = pickle.load(f)
    
    model = model_data['model']
    scaler = model_data['scaler']
    feature_names = model_data['feature_names']
    
    # Extract model parameters
    if hasattr(model, 'n_estimators'):
        n_estimators = model.n_estimators
    else:
        n_estimators = None
    
    if hasattr(model, 'max_depth'):
        max_depth = model.max_depth
    else:
        max_depth = None
    
    # Get feature importances
    if hasattr(model, 'feature_importances_'):
        feature_importances = model.feature_importances_.tolist()
    else:
        feature_importances = []
    
    # Get scaler parameters
    scaler_mean = scaler.mean_.tolist() if hasattr(scaler, 'mean_') else []
    scaler_scale = scaler.scale_.tolist() if hasattr(scaler, 'scale_') else []
    
    # Get training history
    training_history = model_data.get('training_history', [])
    if training_history:
        latest = training_history[-1]
        test_r2 = latest.get('test_r2', None)
        train_r2 = latest.get('train_r2', None)
    else:
        test_r2 = None
        train_r2 = None
    
    # Create JSON export
    export_data = {
        "modelType": "randomForestRegressor",
        "version": "2.0",
        "description": "SafeRouteAI PathFinding Model - Enhanced with Real-time Data",
        "author": "SafeRouteAI Team",
        "license": "MIT",
        "exportDate": str(np.datetime64('now')),
        "features": feature_names,
        "target": "safety_score",
        "modelParams": {
            "n_estimators": n_estimators,
            "max_depth": max_depth
        },
        "featureImportances": dict(zip(feature_names, feature_importances)),
        "scaler": {
            "mean": scaler_mean,
            "scale": scaler_scale,
            "type": type(scaler).__name__
        },
        "performance": {
            "train_r2": train_r2,
            "test_r2": test_r2,
            "n_samples": len(training_history) if training_history else None
        },
        "trainingHistory": training_history[-10:] if len(training_history) > 10 else training_history
    }
    
    # Save to output directory
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    json_path = output_path / 'PathFindingModel.json'
    print(f"Saving model metadata to {json_path}...")
    with open(json_path, 'w') as f:
        json.dump(export_data, f, indent=2)
    
    print(f"✓ Model exported to {json_path}")
    
    # Also create a simplified version for quick reference
    simple_export = {
        "feature_names": feature_names,
        "n_estimators": n_estimators,
        "max_depth": max_depth,
        "feature_importances": feature_importances,
        "test_score": test_r2,
        "train_score": train_r2
    }
    
    simple_path = output_path / 'PathFindingModel_spec.json'
    with open(simple_path, 'w') as f:
        json.dump(simple_export, f, indent=2)
    
    print(f"✓ Simplified spec saved to {simple_path}")
    
    # Print summary
    print("\n" + "=" * 60)
    print("Export Summary:")
    print("=" * 60)
    print(f"  Model Type: {export_data['modelType']}")
    print(f"  Features: {len(feature_names)}")
    print(f"  Test R²: {test_r2:.4f}" if test_r2 else "  Test R²: N/A")
    print(f"  Train R²: {train_r2:.4f}" if train_r2 else "  Train R²: N/A")
    print(f"  Top Features:")
    sorted_importances = sorted(
        zip(feature_names, feature_importances),
        key=lambda x: x[1],
        reverse=True
    )[:5]
    for feature, importance in sorted_importances:
        print(f"    - {feature}: {importance:.4f}")
    print("=" * 60)
    
    return json_path

def main():
    parser = argparse.ArgumentParser(description='Export Model for Swift/iOS')
    parser.add_argument('--model', type=str, required=True, help='Path to trained model .pkl file')
    parser.add_argument('--output', type=str, default='../SafeRouteAI/AI/', help='Output directory')
    
    args = parser.parse_args()
    
    export_model_for_swift(args.model, args.output)

if __name__ == '__main__':
    main()


