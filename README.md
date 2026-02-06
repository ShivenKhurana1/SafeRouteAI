# SafeRouteAI

**AI-Powered Route Safety for the U.S. Presidential AI Challenge**

SafeRouteAI is an iOS application that helps users find the safest walking and biking routes using AI-powered safety predictions. The app analyzes lighting, weather, crowd density, incident data, and infrastructure quality to recommend optimal routes.

## Mission

SafeRouteAI promotes safety, equity, and trust in technology—aligned with the values of the U.S. President's administration. The app demonstrates ethical AI use to improve community safety and accessibility.

##  Features

### Core Functionality
- **AI-Recommended Safe Routes** with color-coded safety levels (Green: Safe, Yellow: Moderate, Red: Risky)
- **Real-time Location Services** using CoreLocation
- **Route Planning** with multiple route options
- **Travel Mode Selection** (Walking, Biking, Wheelchair)
- **Community Safety Reports** and annotations
- **AI Insights Dashboard** with safety analytics and predictions

### Technical Stack
- **SwiftUI** - Modern, declarative UI
- **MapKit** - Route visualization and map interactions
- **CoreLocation** - Real-time positioning
- **CoreML** - AI safety prediction model
- **MVVM Architecture** - Clean separation of concerns

## Quick Start

1. **Open Project**
   ```bash
   open SafeRouteAI.xcodeproj
   ```

2. **Build & Run**
   - Select iPhone simulator or device
   - Build (⌘B) and Run (⌘R)
   - Grant location permissions when prompted

3. **Requirements**
   - iOS 14.0+
   - Xcode 14.0+
   - Swift 5.0+

## AI Model

### Path Finding Model
- **Algorithm**: Random Forest Regressor
- **Features**: 21 safety factors (lighting, weather, incidents, infrastructure, etc.)
- **Performance**: Test R² = 0.74, Train R² = 0.94
- **Output**: Safety score (0.0 = safe, 1.0 = risky) with confidence levels

### Key Features Analyzed
1. **Visibility Score** (60.5% importance) - Most critical factor
2. **Crowd Density** (10.5%)
3. **Incident Reports** (7.4%)
4. **Crime Index** (3.2%)
5. **Infrastructure Quality** (3.1%)

### Model Training
See `training/README.md` for detailed training instructions.

## Project Structure

```
SafeRouteAI/
├── SafeRouteAI/           # iOS app source code
│   ├── AI/                # AI models and services
│   ├── Views/             # SwiftUI views
│   ├── Managers/          # Location and data managers
│   └── Models/            # Data models
├── training/              # Model training scripts
│   ├── train_pathfinding_model.py
│   ├── visualize_training.py
│   └── visualizations/   # Training graphs
└── README.md             # This file
```

## Privacy & Security

- **On-Device Processing** - All location data stays on device
- **No Data Collection** - User location never transmitted
- **Transparent AI** - Safety scores include confidence levels and explanations
- **Privacy-First** - User control over location services

## Model Performance

- **Train R²**: 0.9429 (94.29% variance explained)
- **Test R²**: 0.7355 (73.55% variance explained)
- **Inference Speed**: <10ms per prediction
- **Model Size**: ~500KB-2MB

## Design

- **Glass-morphism UI** with modern aesthetics
- **Dark Mode** support
- **Accessibility** - VoiceOver, Dynamic Type, high contrast
- **SF Symbols** for consistent iconography

## Documentation

- **Training Guide**: `training/README.md`
- **API Guide**: See code comments for API integrations
- **Model Details**: `training/visualizations/` for training graphs

## Testing

Run tests with ⌘U in Xcode. The project includes:
- Unit Tests (`SafeRouteAITests`)
- UI Tests (`SafeRouteAIUITests`)

## License

Created for the U.S. Presidential AI Challenge (Track II) demonstrating best practices in AI development, community engagement, and ethical technology use.

---

**Made with ❤️ for safer communities**
