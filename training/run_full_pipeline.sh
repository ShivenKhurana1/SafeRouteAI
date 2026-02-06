#!/bin/bash
# Full pipeline script: Train -> Visualize -> Export

set -e  # Exit on error

echo "=========================================="
echo "SafeRouteAI Model Training Pipeline"
echo "=========================================="

# Configuration
SAMPLES=10000
MODEL_NAME="pathfinding_model_enhanced"
USE_REALTIME=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --samples)
            SAMPLES="$2"
            shift 2
            ;;
        --realtime)
            USE_REALTIME=true
            shift
            ;;
        --model-name)
            MODEL_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

MODEL_PATH="${MODEL_NAME}.pkl"
DATA_PATH="training_data_enhanced.csv"

# Step 1: Train Model
echo ""
echo "Step 1: Training Model..."
echo "----------------------------------------"
if [ "$USE_REALTIME" = true ]; then
    python train_with_realtime.py --samples $SAMPLES --output $MODEL_PATH --realtime
else
    python train_with_realtime.py --samples $SAMPLES --output $MODEL_PATH
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model training failed!"
    exit 1
fi

echo "✓ Model trained successfully"

# Step 2: Visualize Results
echo ""
echo "Step 2: Generating Visualizations..."
echo "----------------------------------------"
if [ -f "$DATA_PATH" ]; then
    python visualize_training.py --model $MODEL_PATH --data $DATA_PATH
    echo "✓ Visualizations generated"
else
    echo "⚠ Training data file not found, skipping visualizations"
fi

# Step 3: Export for Swift
echo ""
echo "Step 3: Exporting for Swift/iOS..."
echo "----------------------------------------"
python export_for_swift.py --model $MODEL_PATH --output ../SafeRouteAI/AI/
echo "✓ Model exported for Swift"

# Summary
echo ""
echo "=========================================="
echo "Pipeline Complete!"
echo "=========================================="
echo "Model: $MODEL_PATH"
echo "Visualizations: training/visualizations/"
echo "Swift Export: ../SafeRouteAI/AI/PathFindingModel.json"
echo "=========================================="


