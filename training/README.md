# SafeRouteAI Model Training Guide

Complete guide for training, fine-tuning, and visualizing the Path Finding AI model.

## Quick Start

### 1. Install Dependencies
```bash
cd training
pip install -r requirements.txt
```

### 2. Train Model
```bash
python train_pathfinding_model.py
```

### 3. Visualize Results
```bash
python visualize_training.py --model pathfinding_model.pkl --data training_data.csv
```

### 4. Export for Swift
```bash
python export_for_swift.py --model pathfinding_model.pkl --output ../SafeRouteAI/AI/
```

## Model Architecture

- **Algorithm**: Random Forest Regressor
- **Trees**: 100
- **Features**: 21 safety factors
- **Target**: Safety Score (0.0 = very safe, 1.0 = very unsafe)

### Input Features

**Street Characteristics:**
- Street type, sidewalk quality, crosswalk availability
- Bike lane availability, street width, traffic density

**Hazard Data:**
- Incident reports, crime index, pedestrian fatalities
- Hazard count, time since last incident

**Environmental:**
- Lighting level, weather condition, time of day
- Day of week, crowd density, visibility score

**Infrastructure:**
- Infrastructure quality, distance to emergency services
- Road surface quality, road markings, road lighting

## Training Process

1. **Data Generation**: Creates 10,000 synthetic samples based on real-world patterns
2. **Model Training**: Trains Random Forest with 100 trees
3. **Evaluation**: Calculates MSE and R² scores
4. **Export**: Saves model as `.pkl` and metadata as `.json`

## Expected Performance

- **Train R²**: ~0.94-0.96
- **Test R²**: ~0.73-0.92
- **Inference Speed**: <10ms per prediction
- **Model Size**: ~500KB-2MB

## Feature Importance

Top 10 Most Important Features:
1. **visibility_score** (60.5%) - Most critical
2. **crowd_density** (10.5%)
3. **incident_reports** (7.4%)
4. **crime_index** (3.2%)
5. **infrastructure_quality** (3.1%)
6. **traffic_density** (2.4%)
7. **distance_to_emergency** (1.7%)
8. **lighting_level** (1.7%)
9. **street_width** (1.5%)
10. **time_since_last_incident** (1.5%)

## Visualization

After training, visualizations are saved to `training/visualizations/`:
- `feature_importance.png` - Top 15 features
- `data_distributions.png` - Training data distributions
- `correlation_matrix.png` - Feature correlations
- `prediction_analysis.png` - Model accuracy analysis

## Fine-Tuning

Update existing model with new data:
```bash
python fine_tune_model.py --model pathfinding_model.pkl --data new_data.csv --output updated_model.pkl
```

## Using Real Data

1. Format CSV with required columns (see `train_pathfinding_model.py`)
2. Update training script to load your CSV
3. Train model: `python train_pathfinding_model.py`
4. Export for Swift: `python export_for_swift.py`

## Troubleshooting

**Low Test R² Score:**
- Increase training samples: `--samples 20000`
- Add more diverse data
- Check data quality

**Model Not Loading:**
- Verify `.pkl` file exists
- Check file permissions
- Ensure model file is not corrupted

**Slow Performance:**
- Reduce sampling frequency
- Use background queue for predictions
- Cache predictions for common routes

## Files

- `train_pathfinding_model.py` - Main training script
- `train_with_realtime.py` - Enhanced training with real-time data
- `visualize_training.py` - Generate visualization graphs
- `export_for_swift.py` - Export model for iOS
- `fine_tune_model.py` - Fine-tune existing model
- `run_full_pipeline.sh` - Complete training pipeline
