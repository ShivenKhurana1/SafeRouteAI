#!/usr/bin/env python3
"""
Enhanced Path Finding Model Training with Real-time Data Integration
Trains and fine-tunes the model using real-time data sources
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.model_selection import train_test_split, TimeSeriesSplit
from sklearn.preprocessing import StandardScaler, RobustScaler
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
import json
import os
import pickle
from datetime import datetime, timedelta
import requests
import logging
from typing import Optional, Dict, List
import matplotlib.pyplot as plt
import seaborn as sns

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class RealtimeDataFetcher:
    """Fetches real-time data from various sources"""
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'SafeRouteAI/1.0'
        })
    
    def fetch_weather_data(self, lat: float, lon: float, days: int = 7) -> pd.DataFrame:
        """Fetch real-time weather data (mock implementation - replace with real API)"""
        logger.info(f"Fetching weather data for ({lat}, {lon})")
        # In production, use OpenWeatherMap API or similar
        # For now, generate realistic weather data
        dates = pd.date_range(end=datetime.now(), periods=days, freq='D')
        data = []
        for date in dates:
            data.append({
                'date': date,
                'precipitation_mm': np.random.exponential(2.0),
                'wind_speed_max': np.random.gamma(2, 5),
                'temperature': np.random.normal(20, 5),
                'weather_condition': np.random.choice([0.2, 0.4, 0.6, 0.8, 1.0], 
                                                      p=[0.05, 0.1, 0.15, 0.3, 0.4])
            })
        return pd.DataFrame(data)
    
    def fetch_crime_data(self, lat: float, lon: float, radius_km: float = 1.0) -> pd.DataFrame:
        """Fetch crime/incident data (mock - replace with real API)"""
        logger.info(f"Fetching crime data for ({lat}, {lon})")
        # In production, use city open data APIs
        n_incidents = np.random.poisson(5)
        data = []
        for _ in range(n_incidents):
            data.append({
                'date': datetime.now() - timedelta(days=np.random.randint(0, 30)),
                'lat': lat + np.random.normal(0, 0.01),
                'lon': lon + np.random.normal(0, 0.01),
                'severity': np.random.choice(['low', 'medium', 'high'], p=[0.7, 0.25, 0.05]),
                'type': np.random.choice(['theft', 'assault', 'vandalism', 'other'])
            })
        return pd.DataFrame(data)
    
    def fetch_traffic_data(self, lat: float, lon: float) -> Dict:
        """Fetch real-time traffic data"""
        logger.info(f"Fetching traffic data for ({lat}, {lon})")
        # Mock implementation
        return {
            'traffic_density': np.random.uniform(0.2, 1.0),
            'accidents_last_30d': np.random.poisson(3),
            'road_conditions': np.random.choice(['good', 'fair', 'poor'], p=[0.6, 0.3, 0.1])
        }

class EnhancedPathFindingTrainer:
    """Enhanced trainer with real-time data integration and fine-tuning"""
    
    def __init__(self, use_realtime: bool = True):
        self.model = None
        self.scaler = RobustScaler()  # More robust to outliers
        self.use_realtime = use_realtime
        self.data_fetcher = RealtimeDataFetcher() if use_realtime else None
        self.training_history = []
        
        self.feature_names = [
            'latitude', 'longitude',
            'lighting_level', 'time_of_day', 'weather_condition',
            'crowd_density', 'incident_reports', 'day_of_week',
            'distance_to_emergency', 'infrastructure_quality',
            'street_type', 'sidewalk_quality', 'crosswalk_available',
            'traffic_density', 'hazard_count', 'crime_index',
            'pedestrian_fatalities', 'bike_lane_available', 'street_width',
            'visibility_score', 'time_since_last_incident',
            'road_surface_quality', 'road_markings', 'road_lighting'
        ]
    
    def enrich_with_realtime_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Enrich training data with real-time sources"""
        if not self.use_realtime or self.data_fetcher is None:
            return df
        
        logger.info("Enriching data with real-time sources...")
        enriched_data = []
        
        for idx, row in df.iterrows():
            lat, lon = row['latitude'], row['longitude']
            
            # Fetch real-time weather
            weather_df = self.data_fetcher.fetch_weather_data(lat, lon, days=7)
            avg_weather = weather_df['weather_condition'].mean()
            max_wind = weather_df['wind_speed_max'].max()
            
            # Fetch crime data
            crime_df = self.data_fetcher.fetch_crime_data(lat, lon)
            recent_crimes = len(crime_df[crime_df['date'] > datetime.now() - timedelta(days=30)])
            crime_index = min(1.0, recent_crimes / 10.0)
            
            # Fetch traffic data
            traffic = self.data_fetcher.fetch_traffic_data(lat, lon)
            
            # Update row with real-time data
            row_dict = row.to_dict()
            row_dict['weather_condition'] = avg_weather
            row_dict['incident_reports'] = min(1.0, row_dict.get('incident_reports', 0) + recent_crimes / 20.0)
            row_dict['crime_index'] = max(row_dict.get('crime_index', 0), crime_index)
            row_dict['traffic_density'] = traffic['traffic_density']
            
            enriched_data.append(row_dict)
        
        return pd.DataFrame(enriched_data)
    
    def generate_training_data(self, num_samples: int = 10000, use_realtime: bool = False) -> pd.DataFrame:
        """Generate training data with optional real-time enrichment"""
        logger.info(f"Generating {num_samples} training samples...")
        
        data = []
        for i in range(num_samples):
            # Geographic coordinates
            lat = np.random.uniform(40.7, 40.8)
            lon = np.random.uniform(-74.0, -73.9)
            
            # Time features
            hour = np.random.randint(0, 24)
            time_of_day = hour / 24.0
            day_of_week = np.random.randint(0, 7) / 7.0
            
            # Lighting
            if 6 <= hour <= 18:
                lighting_level = np.random.uniform(0.7, 1.0)
            else:
                lighting_level = np.random.uniform(0.1, 0.6)
            
            # Weather
            weather_condition = np.random.choice([0.2, 0.4, 0.6, 0.8, 1.0], 
                                                 p=[0.05, 0.1, 0.15, 0.3, 0.4])
            
            # Street characteristics
            street_type = np.random.choice([0.0, 0.33, 0.66, 1.0], 
                                          p=[0.2, 0.3, 0.3, 0.2])
            
            sidewalk_quality = np.random.uniform(0.3, 1.0)
            crosswalk_available = np.random.choice([0.0, 1.0], p=[0.3, 0.7])
            bike_lane_available = np.random.choice([0.0, 1.0], p=[0.6, 0.4])
            street_width = np.random.uniform(0.4, 1.0)
            
            # Traffic and density
            if 7 <= hour <= 9 or 17 <= hour <= 19:
                traffic_density = np.random.uniform(0.7, 1.0)
                crowd_density = np.random.uniform(0.6, 1.0)
            else:
                traffic_density = np.random.uniform(0.2, 0.7)
                crowd_density = np.random.uniform(0.2, 0.6)
            
            # Hazard data
            base_hazard = abs(lat - 40.75) + abs(lon + 73.95)
            hazard_count = min(1.0, np.random.poisson(base_hazard * 2) / 10.0)
            
            # Incident reports
            incident_base = base_hazard * 0.5
            if hour < 6 or hour > 22:
                incident_base *= 1.5
            incident_reports = min(1.0, incident_base + np.random.uniform(0, 0.3))
            
            # Crime index
            crime_index = (1.0 - lighting_level) * 0.4 + incident_reports * 0.4 + np.random.uniform(0, 0.2)
            crime_index = min(1.0, crime_index)
            
            # Pedestrian fatalities
            pedestrian_fatalities = np.random.choice([0.0, 0.5, 1.0], p=[0.95, 0.04, 0.01])
            
            # Infrastructure
            infrastructure_quality = (sidewalk_quality * 0.4 + 
                                     crosswalk_available * 0.2 + 
                                     bike_lane_available * 0.1 +
                                     street_width * 0.3)
            
            # Emergency services
            distance_to_emergency = max(0.0, min(1.0, 1.0 - (base_hazard * 0.3 + np.random.uniform(0, 0.4))))
            
            # Visibility
            visibility_score = (lighting_level * 0.5 + 
                              weather_condition * 0.3 + 
                              (1.0 if 6 <= hour <= 18 else 0.3) * 0.2)
            
            # Time since last incident
            time_since_last_incident = min(1.0, np.random.exponential(30) / 90.0)
            
            # Road quality factors
            road_surface_quality = np.random.uniform(0.5, 1.0)
            road_markings = np.random.uniform(0.4, 1.0)
            road_lighting = lighting_level
            
            # Calculate target safety score
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
                'road_surface_quality': road_surface_quality,
                'road_markings': road_markings,
                'road_lighting': road_lighting,
                'safety_score': safety_score
            })
        
        df = pd.DataFrame(data)
        
        # Enrich with real-time data if requested
        if use_realtime:
            df = self.enrich_with_realtime_data(df)
        
        logger.info(f"Generated {len(df)} samples")
        return df
    
    def train_model(self, df: pd.DataFrame, model_type: str = 'random_forest', 
                   fine_tune: bool = False, existing_model_path: Optional[str] = None):
        """Train or fine-tune the model"""
        logger.info(f"Training {model_type} model (fine_tune={fine_tune})...")
        
        # Prepare features and target
        X = df[self.feature_names]
        y = df['safety_score']
        
        # Time-aware split for fine-tuning
        if fine_tune and 'date' in df.columns:
            split_idx = int(len(df) * 0.8)
            X_train, X_test = X.iloc[:split_idx], X.iloc[split_idx:]
            y_train, y_test = y.iloc[:split_idx], y.iloc[split_idx:]
        else:
            X_train, X_test, y_train, y_test = train_test_split(
                X, y, test_size=0.2, random_state=42
            )
        
        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)
        
        # Load existing model for fine-tuning
        if fine_tune and existing_model_path and os.path.exists(existing_model_path):
            logger.info(f"Loading existing model from {existing_model_path} for fine-tuning...")
            with open(existing_model_path, 'rb') as f:
                model_data = pickle.load(f)
                self.model = model_data['model']
                # Continue training (warm start)
                if hasattr(self.model, 'warm_start'):
                    self.model.warm_start = True
        else:
            # Train new model
            if model_type == 'random_forest':
                self.model = RandomForestRegressor(
                    n_estimators=200,  # Increased for better performance
                    max_depth=20,
                    min_samples_split=3,
                    min_samples_leaf=1,
                    random_state=42,
                    n_jobs=-1
                )
            elif model_type == 'gradient_boosting':
                self.model = GradientBoostingRegressor(
                    n_estimators=200,
                    max_depth=10,
                    learning_rate=0.05,
                    random_state=42
                )
            else:
                raise ValueError(f"Unknown model type: {model_type}")
        
        # Train
        self.model.fit(X_train_scaled, y_train)
        
        # Evaluate
        train_pred = self.model.predict(X_train_scaled)
        test_pred = self.model.predict(X_test_scaled)
        
        train_mse = mean_squared_error(y_train, train_pred)
        test_mse = mean_squared_error(y_test, test_pred)
        train_mae = mean_absolute_error(y_train, train_pred)
        test_mae = mean_absolute_error(y_test, test_pred)
        train_r2 = r2_score(y_train, train_pred)
        test_r2 = r2_score(y_test, test_pred)
        
        logger.info(f"\nModel Performance:")
        logger.info(f"  Train - MSE: {train_mse:.4f}, MAE: {train_mae:.4f}, R²: {train_r2:.4f}")
        logger.info(f"  Test  - MSE: {test_mse:.4f}, MAE: {test_mae:.4f}, R²: {test_r2:.4f}")
        
        # Store training history
        self.training_history.append({
            'epoch': len(self.training_history),
            'train_mse': train_mse,
            'test_mse': test_mse,
            'train_r2': train_r2,
            'test_r2': test_r2,
            'timestamp': datetime.now().isoformat()
        })
        
        # Feature importance
        if hasattr(self.model, 'feature_importances_'):
            importances = pd.DataFrame({
                'feature': self.feature_names,
                'importance': self.model.feature_importances_
            }).sort_values('importance', ascending=False)
            logger.info(f"\nTop 10 Most Important Features:")
            logger.info(importances.head(10).to_string(index=False))
        
        return self.model
    
    def save_model(self, output_path: str = 'pathfinding_model_enhanced.pkl'):
        """Save trained model and metadata"""
        logger.info(f"Saving model to: {output_path}")
        
        model_data = {
            'model': self.model,
            'scaler': self.scaler,
            'feature_names': self.feature_names,
            'training_history': self.training_history,
            'metadata': {
                'model_type': type(self.model).__name__,
                'n_features': len(self.feature_names),
                'training_date': datetime.now().isoformat(),
                'use_realtime': self.use_realtime
            }
        }
        
        with open(output_path, 'wb') as f:
            pickle.dump(model_data, f)
        
        # Also save JSON metadata
        json_path = output_path.replace('.pkl', '.json')
        json_data = {
            'feature_names': self.feature_names,
            'n_estimators': getattr(self.model, 'n_estimators', None),
            'max_depth': getattr(self.model, 'max_depth', None),
            'feature_importances': self.model.feature_importances_.tolist() if hasattr(self.model, 'feature_importances_') else [],
            'test_score': self.training_history[-1]['test_r2'] if self.training_history else None,
            'train_score': self.training_history[-1]['train_r2'] if self.training_history else None,
            'training_history': self.training_history
        }
        
        with open(json_path, 'w') as f:
            json.dump(json_data, f, indent=2)
        
        logger.info(f"✓ Model saved to {output_path}")
        logger.info(f"✓ Metadata saved to {json_path}")
        return True

def main():
    """Main training pipeline"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Train Path Finding Model with Real-time Data')
    parser.add_argument('--realtime', action='store_true', help='Use real-time data sources')
    parser.add_argument('--fine-tune', action='store_true', help='Fine-tune existing model')
    parser.add_argument('--model-path', type=str, help='Path to existing model for fine-tuning')
    parser.add_argument('--samples', type=int, default=10000, help='Number of training samples')
    parser.add_argument('--output', type=str, default='pathfinding_model_enhanced.pkl', help='Output model path')
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("SafeRouteAI Enhanced Path Finding Model Training")
    print("=" * 60)
    
    trainer = EnhancedPathFindingTrainer(use_realtime=args.realtime)
    
    # Generate or load training data
    data_file = 'training_data_enhanced.csv'
    
    if os.path.exists(data_file):
        logger.info(f"Loading training data from {data_file}...")
        df = pd.read_csv(data_file)
    else:
        logger.info("Generating training data...")
        df = trainer.generate_training_data(num_samples=args.samples, use_realtime=args.realtime)
        df.to_csv(data_file, index=False)
        logger.info(f"✓ Saved training data to {data_file}")
    
    # Train model
    model = trainer.train_model(df, model_type='random_forest', 
                                fine_tune=args.fine_tune, 
                                existing_model_path=args.model_path)
    
    # Save model
    success = trainer.save_model(args.output)
    
    if success:
        print("\n" + "=" * 60)
        print("Training Complete!")
        print(f"Model saved to: {args.output}")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("Training Failed!")
        print("=" * 60)

if __name__ == '__main__':
    main()


