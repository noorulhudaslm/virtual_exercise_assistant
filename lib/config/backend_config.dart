class BackendConfig {
  // Backend URLs - Update these with your actual backend endpoints
  static const String baseUrl = 'http://192.168.1.5:5000';
  static const String predictEndpoint = '$baseUrl/predict';
  static const String healthEndpoint = '$baseUrl/health';

  // WebSocket URL (if using WebSocket for real-time processing)
  static const String wsUrl = 'ws://192.168.1.195:8000';

  // API Configuration
  static const int requestTimeout = 10; // seconds
  static const int healthCheckTimeout = 5; // seconds

  // Available exercise names (must match your backend model)
  static const List<String> exerciseNames = [
    "Push-up",
    "Pull-up",
    "Squat",
    "Deadlift",
    "Bench Press",
    "Lat Pulldown",
    "Bicep Curl",
    "Tricep Pushdown",
  ];

  // Request headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Backend response format
  static const String predictionType = 'prediction';
  static const String dataKey = 'data';
  static const String classKey = 'class';
  static const String labelKey = 'label';
  static const String confidenceKey = 'confidence';
  static const String allPredictionsKey = 'all_predictions';
}
