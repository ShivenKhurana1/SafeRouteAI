#!/usr/bin/env python3
# Run with: python3 train_pathfinding_model.py
"""
Path Finding AI Training Script for SafeRouteAI
Trains a RandomForest model to predict route safety scores using street and walking hazard data
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_squared_error, r2_score
import json
import os
from datetime import datetime

# Set random seed for reproducibility
np.random.seed(42)

class PathFindingTrainer:
    """Trains a path finding AI model using street and hazard data"""
    
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.feature_names = [
            'latitude', 'longitude',
            'lighting_level', 'time_of_day', 'weather_condition',
            'crowd_density', 'incident_reports', 'day_of_week',
            'distance_to_emergency', 'infrastructure_quality',
            'street_type', 'sidewalk_quality', 'crosswalk_available',
            'traffic_density', 'hazard_count', 'crime_index',
            'pedestrian_fatalities', 'bike_lane_available', 'street_width',
            'visibility_score', 'time_since_last_incident'
        ]
        
    def load_real_data(self, data_file='training_data.csv'):
        """
        Load real training data from processed datasets
        Expected format: CSV with 21 feature columns + safety_score column
        """
        print(f"Loading real training data from {data_file}...")
        df = pd.read_csv(data_file)
        
        # Validate required columns
        required_cols = self.feature_names + ['safety_score']
        missing_cols = set(required_cols) - set(df.columns)
        if missing_cols:
            raise ValueError(f"Missing required columns: {missing_cols}")
        
        print(f"Loaded {len(df)} samples from real data")
        return df
    
    def generate_training_data(self, num_samples=10000):
        """
        Generate synthetic training data based on real-world patterns
        In production, use load_real_data() to load from actual street/hazard databases
        """
        print(f"Generating {num_samples} training samples...")
        
        data = []
        
        for i in range(num_samples):
            # Geographic coordinates (simulating NYC area)
            lat = np.random.uniform(40.7, 40.8)
            lon = np.random.uniform(-74.0, -73.9)
            
            # Time features
            hour = np.random.randint(0, 24)
            time_of_day = hour / 24.0
            day_of_week = np.random.randint(0, 7) / 7.0
            
            # Lighting (better during day, varies at night)
            if 6 <= hour <= 18:
                lighting_level = np.random.uniform(0.7, 1.0)
            else:
                lighting_level = np.random.uniform(0.1, 0.6)
            
            # Weather (mostly clear, some variation)
            weather_condition = np.random.choice([0.2, 0.4, 0.6, 0.8, 1.0], 
                                                 p=[0.05, 0.1, 0.15, 0.3, 0.4])
            
            # Street characteristics
            street_type = np.random.choice([0.0, 0.33, 0.66, 1.0], 
                                          p=[0.2, 0.3, 0.3, 0.2])  # Residential, Commercial, Major, Highway
            
            sidewalk_quality = np.random.uniform(0.3, 1.0)
            crosswalk_available = np.random.choice([0.0, 1.0], p=[0.3, 0.7])
            bike_lane_available = np.random.choice([0.0, 1.0], p=[0.6, 0.4])
            street_width = np.random.uniform(0.4, 1.0)  # Normalized
            
            # Traffic and density
            if 7 <= hour <= 9 or 17 <= hour <= 19:  # Rush hours
                traffic_density = np.random.uniform(0.7, 1.0)
                crowd_density = np.random.uniform(0.6, 1.0)
            else:
                traffic_density = np.random.uniform(0.2, 0.7)
                crowd_density = np.random.uniform(0.2, 0.6)
            
            # Hazard data (correlated with location and time)
            base_hazard = abs(lat - 40.75) + abs(lon + 73.95)  # Distance from center
            hazard_count = max(0, int(np.random.poisson(base_hazard * 2)))
            hazard_count = min(hazard_count, 10) / 10.0  # Normalize
            
            # Incident reports (higher in certain areas and times)
            incident_base = base_hazard * 0.5
            if hour < 6 or hour > 22:  # Late night
                incident_base *= 1.5
            incident_reports = min(1.0, incident_base + np.random.uniform(0, 0.3))
            
            # Crime index (correlated with incidents and lighting)
            crime_index = (1.0 - lighting_level) * 0.4 + incident_reports * 0.4 + np.random.uniform(0, 0.2)
            crime_index = min(1.0, crime_index)
            
            # Pedestrian fatalities (rare but important)
            pedestrian_fatalities = np.random.choice([0.0, 0.5, 1.0], p=[0.95, 0.04, 0.01])
            
            # Infrastructure
            infrastructure_quality = (sidewalk_quality * 0.4 + 
                                     crosswalk_available * 0.2 + 
                                     bike_lane_available * 0.1 +
                                     street_width * 0.3)
            
            # Emergency services (closer in urban areas)
            distance_to_emergency = 1.0 - (base_hazard * 0.3 + np.random.uniform(0, 0.4))
            distance_to_emergency = max(0.0, min(1.0, distance_to_emergency))
            
            # Visibility (affected by lighting, weather, time)
            visibility_score = (lighting_level * 0.5 + 
                              weather_condition * 0.3 + 
                              (1.0 if 6 <= hour <= 18 else 0.3) * 0.2)
            
            # Time since last incident (inverse relationship with safety)
            time_since_last_incident = np.random.exponential(30)  # Days
            time_since_last_incident = min(1.0, time_since_last_incident / 90.0)  # Normalize to 90 days
            
            # Calculate target safety score (0.0 = very safe, 1.0 = very unsafe)
            # This is the "ground truth" we want the model to learn
            safety_score = (
                (1.0 - lighting_level) * 0.20 +
                (1.0 - crowd_density) * 0.15 +
                incident_reports * 0.25 +
                (1.0 - weather_condition) * 0.10 +
                (1.0 - infrastructure_quality) * 0.10 +
                crime_index * 0.10 +
                hazard_count * 0.05 +
                (1.0 - distance_to_emergency) * 0.05
            )
            
            # Add some noise
            safety_score += np.random.normal(0, 0.05)
            safety_score = max(0.0, min(1.0, safety_score))
            
            data.append({
                'latitude': lat,
                'longitude': lon,
                'lighting_level': lighting_level,
                'time_of_day': time_of_day,
                'weather_condition': weather_condition,
                'crowd_density': crowd_density,
                'incident_reports': incident_reports,
                'day_of_week': day_of_week,
                'distance_to_emergency': distance_to_emergency,
                'infrastructure_quality': infrastructure_quality,
                'street_type': street_type,
                'sidewalk_quality': sidewalk_quality,
                'crosswalk_available': crosswalk_available,
                'traffic_density': traffic_density,
                'hazard_count': hazard_count,
                'crime_index': crime_index,
                'pedestrian_fatalities': pedestrian_fatalities,
                'bike_lane_available': bike_lane_available,
                'street_width': street_width,
                'visibility_score': visibility_score,
                'time_since_last_incident': time_since_last_incident,
                'safety_score': safety_score
            })
        
        df = pd.DataFrame(data)
        print(f"Generated {len(df)} samples")
        return df
    
    def train_model(self, df, model_type='random_forest'):
        """Train the path finding model"""
        print(f"\nTraining {model_type} model...")
        
        # Prepare features and target
        X = df[self.feature_names]
        y = df['safety_score']
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42
        )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Train model
        if model_type == 'random_forest':
            self.model = RandomForestRegressor(
                n_estimators=100,
                max_depth=15,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=42,
                n_jobs=-1
            )
        elif model_type == 'gradient_boosting':
            self.model = GradientBoostingRegressor(
                n_estimators=100,
                max_depth=10,
                learning_rate=0.1,
                random_state=42
            )
        else:
            raise ValueError(f"Unknown model type: {model_type}")
        
        self.model.fit(X_train_scaled, y_train)
        
        # Evaluate
        train_pred = self.model.predict(X_train_scaled)
        test_pred = self.model.predict(X_test_scaled)
        
        train_mse = mean_squared_error(y_train, train_pred)
        test_mse = mean_squared_error(y_test, test_pred)
        train_r2 = r2_score(y_train, train_pred)
        test_r2 = r2_score(y_test, test_pred)
        
        print(f"\nModel Performance:")
        print(f"  Train MSE: {train_mse:.4f}, R²: {train_r2:.4f}")
        print(f"  Test MSE: {test_mse:.4f}, R²: {test_r2:.4f}")
        
        # Feature importance
        feature_importances = None
        if hasattr(self.model, 'feature_importances_'):
            importances = pd.DataFrame({
                'feature': self.feature_names,
                'importance': self.model.feature_importances_
            }).sort_values('importance', ascending=False)
            print(f"\nTop 10 Most Important Features:")
            print(importances.head(10).to_string(index=False))
            feature_importances = self.model.feature_importances_.tolist()
        
        # Store metrics for saving
        self.train_metrics = {
            'train_mse': train_mse,
            'test_mse': test_mse,
            'train_r2': train_r2,
            'test_r2': test_r2,
            'feature_importances': feature_importances
        }
        
        return self.model
    
    def save_model(self, output_path='pathfinding_model.pkl'):
        """Save trained model to pickle file with metadata"""
        print(f"\nSaving model to: {output_path}")
        
        import pickle
        
        # Get metrics if available
        metrics = getattr(self, 'train_metrics', {})
        
        model_data = {
            'model': self.model,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'metadata': {
                'model_type': 'RandomForest',
                'n_features': len(self.feature_names),
                'training_date': datetime.now().isoformat(),
                'train_mse': metrics.get('train_mse'),
                'test_mse': metrics.get('test_mse'),
                'train_r2': metrics.get('train_r2'),
                'test_r2': metrics.get('test_r2'),
                'feature_importances': metrics.get('feature_importances', []),
                'feature_names': self.feature_names
            }
        }
        
        with open(output_path, 'wb') as f:
            pickle.dump(model_data, f)
        
        # Also save JSON metadata for visualization script
        json_path = output_path.replace('.pkl', '.json')
        json_metadata = {
            'model_type': 'RandomForest',
            'n_features': len(self.feature_names),
            'training_date': datetime.now().isoformat(),
            'train_mse': metrics.get('train_mse'),
            'test_mse': metrics.get('test_mse'),
            'train_r2': metrics.get('train_r2'),
            'test_r2': metrics.get('test_r2'),
            'feature_importances': metrics.get('feature_importances', []),
            'feature_names': self.feature_names
        }
        
        with open(json_path, 'w') as f:
            json.dump(json_metadata, f, indent=2)
        
        print(f"✓ Model saved to {output_path}")
        print(f"✓ Metadata saved to {json_path}")
        return True

def main():
    """Main training pipeline"""
    print("=" * 60)
    print("SafeRouteAI Path Finding Model Training")
    print("=" * 60)
    
    trainer = PathFindingTrainer()
    
    # Generate or load training data
    data_file = 'training_data.csv'
    real_data_file = 'real_training_data.csv'  # Use this for real datasets
    
    if os.path.exists(real_data_file):
        print(f"Loading real training data from {real_data_file}...")
        df = trainer.load_real_data(real_data_file)
    elif os.path.exists(data_file):
        print(f"Loading training data from {data_file}...")
        df = pd.read_csv(data_file)
    else:
        print("Generating synthetic training data...")
        print("  (To use real data, process datasets and save as 'real_training_data.csv')")
        df = trainer.generate_training_data(num_samples=10000)
        df.to_csv(data_file, index=False)
        print(f"✓ Saved training data to {data_file}")
    
    # Train model
    model = trainer.train_model(df, model_type='random_forest')
    
    # Save model (pickle format instead of CoreML)
    output_path = 'pathfinding_model.pkl'
    success = trainer.save_model(output_path)
    
    if success:
        print("\n" + "=" * 60)
        print("Training Complete!")
        print(f"Model saved to: {output_path}")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("Training Failed!")
        print("=" * 60)

if __name__ == '__main__':
    main()

