import 'dart:math';

/// Liability classification for crash incidents
enum LiabilityClassification {
  striker,   // We caused the accident (frontal impact, negative Delta-V)
  victim,    // We were hit (rear-end, positive Delta-V while stationary)
  tbone,     // Side impact (lateral vector spike)
  unknown    // Insufficient data for classification
}

/// Acoustic signature data from crash
class AcousticSignature {
  final bool metalScreech;      // 2-4kHz metal-on-metal friction
  final bool glassShatter;      // High-frequency glass breaking
  final bool structuralCrunch;  // Broadband structural deformation
  final double peakFrequency;   // Hz
  final double signalStrength;  // dB
  
  const AcousticSignature({
    required this.metalScreech,
    required this.glassShatter,
    required this.structuralCrunch,
    required this.peakFrequency,
    required this.signalStrength,
  });
  
  Map<String, dynamic> toJson() => {
    'metal_screech': metalScreech,
    'glass_shatter': glassShatter,
    'structural_crunch': structuralCrunch,
    'peak_frequency': peakFrequency,
    'signal_strength': signalStrength,
  };
}

/// 3D vector for impact direction
class Vector3 {
  final double x;
  final double y;
  final double z;
  
  const Vector3(this.x, this.y, this.z);
  
  double get magnitude => sqrt(x * x + y * y + z * z);
  
  Vector3 normalize() {
    final mag = magnitude;
    if (mag == 0) return const Vector3(0, 0, 0);
    return Vector3(x / mag, y / mag, z / mag);
  }
  
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};
  
  @override
  String toString() => 'Vector3($x, $y, $z)';
}

/// Complete crash data with tri-sensor information
class CrashData {
  final double deltaV;                    // m/s - velocity change
  final Vector3 impactVector;             // Direction of impact
  final AcousticSignature? acoustic;      // Audio signature (if available)
  final LiabilityClassification classification;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedBefore;               // m/s
  final double headingBefore;             // degrees
  final List<Map<String, dynamic>> first50msData; // Raw data from first 50ms
  
  CrashData({
    required this.deltaV,
    required this.impactVector,
    this.acoustic,
    required this.classification,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedBefore,
    required this.headingBefore,
    required this.first50msData,
  });
  
  Map<String, dynamic> toJson() => {
    'delta_v': deltaV,
    'impact_vector': impactVector.toJson(),
    'acoustic_signature': acoustic?.toJson(),
    'classification': classification.name,
    'timestamp': timestamp.toIso8601String(),
    'location': {
      'lat': latitude,
      'lon': longitude,
    },
    'speed_before': speedBefore,
    'heading_before': headingBefore,
    'forensic_data': {
      'first_50ms': first50msData,
    },
  };
}

/// Classifier for determining crash liability
class CrashClassifier {
  /// Classify crash based on tri-sensor data
  static LiabilityClassification classify({
    required double deltaV,
    required Vector3 impactVector,
    AcousticSignature? acoustic,
    required double velocityBefore,
  }) {
    // Normalize impact vector
    final normalized = impactVector.normalize();
    
    // Negative Delta-V = Deceleration (we hit something)
    // Positive Delta-V = Acceleration (we got hit from behind)
    
    if (deltaV < -3.0) {
      // Strong deceleration - likely frontal impact (STRIKER)
      // Confirm with frontal vector and metal screech
      if (normalized.y < -0.5 && (acoustic?.metalScreech ?? false)) {
        return LiabilityClassification.striker;
      }
      return LiabilityClassification.striker;
    }
    
    if (deltaV > 3.0 && velocityBefore < 2.0) {
      // Strong acceleration while stationary/slow - rear-end (VICTIM)
      if (normalized.y > 0.5) {
        return LiabilityClassification.victim;
      }
    }
    
    // Lateral impact (T-bone) - check X-axis dominance
    if (normalized.x.abs() > 0.7 && (acoustic?.glassShatter ?? false)) {
      return LiabilityClassification.tbone;
    }
    
    return LiabilityClassification.unknown;
  }
}
