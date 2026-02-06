#!/usr/bin/env python3
"""
Visualization script for model training trends and statistics
Generates comprehensive charts for training/testing metrics
"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend for PNG output
import matplotlib.pyplot as plt
import seaborn as sns
import json
import pickle
import os
from pathlib import Path
from typing import Optional, Dict, List
import argparse

# Set style and PNG format
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10
plt.rcParams['savefig.format'] = 'png'
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['savefig.bbox'] = 'tight'

class ModelVisualizer:
    """Creates comprehensive visualizations for model training"""
    
    def __init__(self, model_path: str, data_path: Optional[str] = None):
        self.model_path = model_path
        self.data_path = data_path
        self.model_data = None
        self.training_data = None
        self.output_dir = Path('training/visualizations')
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def load_model_data(self):
        """Load model and metadata"""
        # Load JSON metadata
        json_path = self.model_path.replace('.pkl', '.json')
        if os.path.exists(json_path):
            with open(json_path, 'r') as f:
                self.model_data = json.load(f)
        else:
            # Try loading from pickle
            with open(self.model_path, 'rb') as f:
                model_obj = pickle.load(f)
                if 'metadata' in model_obj:
                    self.model_data = model_obj['metadata']
                if 'training_history' in model_obj:
                    self.model_data = self.model_data or {}
                    self.model_data['training_history'] = model_obj['training_history']
    
    def load_training_data(self):
        """Load training dataset"""
        if self.data_path and os.path.exists(self.data_path):
            self.training_data = pd.read_csv(self.data_path)
        else:
            # Try default paths
            for path in ['training_data_enhanced.csv', 'training_data.csv']:
                if os.path.exists(path):
                    self.training_data = pd.read_csv(path)
                    break
    
    def plot_training_history(self):
        """Plot training and validation metrics over time"""
        if not self.model_data or 'training_history' not in self.model_data:
            print("No training history found")
            return
        
        history = pd.DataFrame(self.model_data['training_history'])
        
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        
        # MSE over epochs
        axes[0, 0].plot(history['epoch'], history['train_mse'], 'b-', label='Train MSE', linewidth=2)
        axes[0, 0].plot(history['epoch'], history['test_mse'], 'r-', label='Test MSE', linewidth=2)
        axes[0, 0].set_xlabel('Epoch')
        axes[0, 0].set_ylabel('Mean Squared Error')
        axes[0, 0].set_title('Training and Validation MSE Over Time')
        axes[0, 0].legend()
        axes[0, 0].grid(True, alpha=0.3)
        
        # R² over epochs
        axes[0, 1].plot(history['epoch'], history['train_r2'], 'b-', label='Train R²', linewidth=2)
        axes[0, 1].plot(history['epoch'], history['test_r2'], 'r-', label='Test R²', linewidth=2)
        axes[0, 1].set_xlabel('Epoch')
        axes[0, 1].set_ylabel('R² Score')
        axes[0, 1].set_title('Training and Validation R² Over Time')
        axes[0, 1].legend()
        axes[0, 1].grid(True, alpha=0.3)
        
        # Loss comparison
        axes[1, 0].bar(['Train MSE', 'Test MSE'], 
                      [history['train_mse'].iloc[-1], history['test_mse'].iloc[-1]],
                      color=['blue', 'red'], alpha=0.7)
        axes[1, 0].set_ylabel('MSE')
        axes[1, 0].set_title('Final MSE Comparison')
        axes[1, 0].grid(True, alpha=0.3, axis='y')
        
        # R² comparison
        axes[1, 1].bar(['Train R²', 'Test R²'], 
                      [history['train_r2'].iloc[-1], history['test_r2'].iloc[-1]],
                      color=['blue', 'red'], alpha=0.7)
        axes[1, 1].set_ylabel('R² Score')
        axes[1, 1].set_title('Final R² Comparison')
        axes[1, 1].set_ylim([0, 1])
        axes[1, 1].grid(True, alpha=0.3, axis='y')
        
        plt.tight_layout()
        output_path = self.output_dir / 'training_history.png'
        plt.savefig(output_path, format='png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved training history plot to {output_path}")
        plt.close()
    
    def plot_feature_importance(self):
        """Plot feature importance"""
        if not self.model_data or 'feature_importances' not in self.model_data:
            print("No feature importance data found")
            return
        
        importances = self.model_data['feature_importances']
        feature_names = self.model_data.get('feature_names', [f'Feature {i}' for i in range(len(importances))])
        
        df_importance = pd.DataFrame({
            'feature': feature_names,
            'importance': importances
        }).sort_values('importance', ascending=False)
        
        # Top 15 features
        top_features = df_importance.head(15)
        
        fig, ax = plt.subplots(figsize=(12, 8))
        colors = plt.cm.viridis(np.linspace(0, 1, len(top_features)))
        bars = ax.barh(range(len(top_features)), top_features['importance'], color=colors)
        ax.set_yticks(range(len(top_features)))
        ax.set_yticklabels(top_features['feature'])
        ax.set_xlabel('Importance Score')
        ax.set_title('Top 15 Feature Importances', fontsize=14, fontweight='bold')
        ax.grid(True, alpha=0.3, axis='x')
        
        # Add value labels
        for i, (idx, row) in enumerate(top_features.iterrows()):
            ax.text(row['importance'] + 0.01, i, f"{row['importance']:.4f}", 
                   va='center', fontsize=9)
        
        plt.tight_layout()
        output_path = self.output_dir / 'feature_importance.png'
        plt.savefig(output_path, format='png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved feature importance plot to {output_path}")
        plt.close()
    
    def plot_data_distributions(self):
        """Plot distributions of training data"""
        if self.training_data is None:
            print("No training data found")
            return
        
        # Select key features for visualization
        key_features = ['safety_score', 'lighting_level', 'weather_condition', 
                       'crime_index', 'incident_reports', 'traffic_density',
                       'visibility_score', 'infrastructure_quality']
        
        available_features = [f for f in key_features if f in self.training_data.columns]
        
        n_features = len(available_features)
        n_cols = 3
        n_rows = (n_features + n_cols - 1) // n_cols
        
        fig, axes = plt.subplots(n_rows, n_cols, figsize=(15, 5 * n_rows))
        axes = axes.flatten() if n_features > 1 else [axes]
        
        for i, feature in enumerate(available_features):
            ax = axes[i]
            data = self.training_data[feature].dropna()
            
            ax.hist(data, bins=50, alpha=0.7, color='steelblue', edgecolor='black')
            ax.set_xlabel(feature.replace('_', ' ').title())
            ax.set_ylabel('Frequency')
            ax.set_title(f'Distribution of {feature.replace("_", " ").title()}')
            ax.grid(True, alpha=0.3, axis='y')
            
            # Add statistics
            mean_val = data.mean()
            median_val = data.median()
            ax.axvline(mean_val, color='red', linestyle='--', linewidth=2, label=f'Mean: {mean_val:.3f}')
            ax.axvline(median_val, color='green', linestyle='--', linewidth=2, label=f'Median: {median_val:.3f}')
            ax.legend()
        
        # Hide unused subplots
        for i in range(n_features, len(axes)):
            axes[i].axis('off')
        
        plt.tight_layout()
        output_path = self.output_dir / 'data_distributions.png'
        plt.savefig(output_path, format='png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved data distributions plot to {output_path}")
        plt.close()
    
    def plot_correlation_matrix(self):
        """Plot correlation matrix of features"""
        if self.training_data is None:
            print("No training data found")
            return
        
        # Select numeric features
        numeric_cols = self.training_data.select_dtypes(include=[np.number]).columns.tolist()
        if 'safety_score' not in numeric_cols:
            return
        
        # Compute correlation
        corr_matrix = self.training_data[numeric_cols].corr()
        
        # Focus on safety_score correlations
        safety_corr = corr_matrix['safety_score'].sort_values(ascending=False)
        
        fig, axes = plt.subplots(1, 2, figsize=(20, 8))
        
        # Full correlation matrix heatmap
        sns.heatmap(corr_matrix, annot=False, cmap='coolwarm', center=0,
                   square=True, linewidths=0.5, cbar_kws={"shrink": 0.8}, ax=axes[0])
        axes[0].set_title('Feature Correlation Matrix', fontsize=14, fontweight='bold')
        
        # Safety score correlations
        top_corr = safety_corr.head(15)
        colors = ['red' if x < 0 else 'green' for x in top_corr.values]
        axes[1].barh(range(len(top_corr)), top_corr.values, color=colors, alpha=0.7)
        axes[1].set_yticks(range(len(top_corr)))
        axes[1].set_yticklabels(top_corr.index)
        axes[1].set_xlabel('Correlation with Safety Score')
        axes[1].set_title('Top 15 Features Correlated with Safety Score', fontsize=14, fontweight='bold')
        axes[1].grid(True, alpha=0.3, axis='x')
        axes[1].axvline(0, color='black', linewidth=1)
        
        plt.tight_layout()
        output_path = self.output_dir / 'correlation_matrix.png'
        plt.savefig(output_path, format='png', dpi=300, bbox_inches='tight')
        print(f"✓ Saved correlation matrix to {output_path}")
        plt.close()
    
    def plot_prediction_analysis(self):
        """Plot prediction vs actual analysis"""
        if self.training_data is None:
            print("No training data found")
            return
        
        # Load model and make predictions
        try:
            with open(self.model_path, 'rb') as f:
                model_obj = pickle.load(f)
                model = model_obj['model']
                scaler = model_obj['scaler']
                feature_names = model_obj['feature_names']
            
            X = self.training_data[feature_names]
            y_true = self.training_data['safety_score']
            
            X_scaled = scaler.transform(X)
            y_pred = model.predict(X_scaled)
            
            fig, axes = plt.subplots(2, 2, figsize=(15, 12))
            
            # Scatter plot: Predicted vs Actual
            axes[0, 0].scatter(y_true, y_pred, alpha=0.5, s=10)
            axes[0, 0].plot([y_true.min(), y_true.max()], [y_true.min(), y_true.max()], 
                           'r--', linewidth=2, label='Perfect Prediction')
            axes[0, 0].set_xlabel('Actual Safety Score')
            axes[0, 0].set_ylabel('Predicted Safety Score')
            axes[0, 0].set_title('Predicted vs Actual Safety Scores')
            axes[0, 0].legend()
            axes[0, 0].grid(True, alpha=0.3)
            
            # Residuals plot
            residuals = y_true - y_pred
            axes[0, 1].scatter(y_pred, residuals, alpha=0.5, s=10)
            axes[0, 1].axhline(y=0, color='r', linestyle='--', linewidth=2)
            axes[0, 1].set_xlabel('Predicted Safety Score')
            axes[0, 1].set_ylabel('Residuals (Actual - Predicted)')
            axes[0, 1].set_title('Residuals Plot')
            axes[0, 1].grid(True, alpha=0.3)
            
            # Error distribution
            axes[1, 0].hist(residuals, bins=50, alpha=0.7, color='steelblue', edgecolor='black')
            axes[1, 0].axvline(0, color='red', linestyle='--', linewidth=2)
            axes[1, 0].set_xlabel('Residuals')
            axes[1, 0].set_ylabel('Frequency')
            axes[1, 0].set_title('Distribution of Prediction Errors')
            axes[1, 0].grid(True, alpha=0.3, axis='y')
            
            # Prediction accuracy by safety score range
            score_ranges = ['Very Safe (0-0.2)', 'Safe (0.2-0.4)', 'Moderate (0.4-0.6)', 
                          'Risky (0.6-0.8)', 'Very Risky (0.8-1.0)']
            range_bins = [0, 0.2, 0.4, 0.6, 0.8, 1.0]
            mae_by_range = []
            
            for i in range(len(range_bins) - 1):
                mask = (y_true >= range_bins[i]) & (y_true < range_bins[i+1])
                if mask.sum() > 0:
                    mae = np.mean(np.abs(y_true[mask] - y_pred[mask]))
                    mae_by_range.append(mae)
                else:
                    mae_by_range.append(0)
            
            axes[1, 1].bar(score_ranges, mae_by_range, color='coral', alpha=0.7)
            axes[1, 1].set_ylabel('Mean Absolute Error')
            axes[1, 1].set_title('Prediction Error by Safety Score Range')
            axes[1, 1].tick_params(axis='x', rotation=45)
            axes[1, 1].grid(True, alpha=0.3, axis='y')
            
            plt.tight_layout()
            output_path = self.output_dir / 'prediction_analysis.png'
            plt.savefig(output_path, format='png', dpi=300, bbox_inches='tight')
            print(f"✓ Saved prediction analysis to {output_path}")
            plt.close()
            
        except Exception as e:
            print(f"Could not generate prediction analysis: {e}")
    
    def generate_all_plots(self):
        """Generate all visualization plots"""
        print("Generating model visualizations...")
        print("=" * 60)
        
        self.load_model_data()
        self.load_training_data()
        
        self.plot_training_history()
        self.plot_feature_importance()
        self.plot_data_distributions()
        self.plot_correlation_matrix()
        self.plot_prediction_analysis()
        
        print("=" * 60)
        print(f"✓ All visualizations saved to {self.output_dir}")

def main():
    parser = argparse.ArgumentParser(description='Visualize Model Training Results')
    parser.add_argument('--model', type=str, required=True, help='Path to model file (.pkl)')
    parser.add_argument('--data', type=str, help='Path to training data CSV')
    
    args = parser.parse_args()
    
    visualizer = ModelVisualizer(args.model, args.data)
    visualizer.generate_all_plots()

if __name__ == '__main__':
    main()

