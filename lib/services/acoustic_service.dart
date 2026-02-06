import 'dart:async';
import 'dart:math';
import 'package:record/record.dart';
import 'package:fft/fft.dart';
import 'package:cruze_mobile/models/crash_classification.dart';

/// Acoustic signature detector for crash sounds
class AcousticService {
  static final AcousticService _instance = AcousticService._internal();
  static AcousticService get instance => _instance;
  AcousticService._internal();
  
  final AudioRecorder _recorder = AudioRecorder();
  bool _isListening = false;
  StreamSubscription? _audioSubscription;
  
  // Frequency ranges for crash sounds
  static const double metalScreechMin = 2000.0;  // 2 kHz
  static const double metalScreechMax = 4000.0;  // 4 kHz
  static const double glassShatterMin = 5000.0;  // 5 kHz
  static const double glassShatterMax = 15000.0; // 15 kHz
  
  // Threshold for detection (dB)
  static const double detectionThreshold = 70.0;
  
  Future<void> startListening() async {
    if (_isListening) return;
    
    try {
      // Request microphone permission
      if (await _recorder.hasPermission()) {
        print('🎤 Acoustic Fingerprinting Started');
        print('   Listening for: Metal screech (2-4kHz), Glass shatter (5-15kHz)');
        
        _isListening = true;
        
        // Start recording in streaming mode
        // Note: This is a simplified version
        // In production, you'd use a streaming audio capture
        // For now, we'll implement crash sound detection on-demand
        
      } else {
        print('❌ Microphone permission denied');
      }
    } catch (e) {
      print('Error starting acoustic detection: $e');
    }
  }
  
  /// Analyze audio buffer for crash signatures
  /// Returns acoustic signature if crash detected, null otherwise
  Future<AcousticSignature?> analyzeCrashSound(List<double> audioSamples) async {
    if (audioSamples.isEmpty) return null;
    
    try {
      // Apply FFT to get frequency spectrum
      final spectrum = FFT().Transform(audioSamples);
      
      // Calculate power spectrum
      final powerSpectrum = <double>[];
      for (var complex in spectrum) {
        final power = sqrt(complex.real * complex.real + complex.imaginary * complex.imaginary);
        powerSpectrum.add(power);
      }
      
      // Find peak frequency and power
      double peakPower = 0.0;
      int peakIndex = 0;
      for (int i = 0; i < powerSpectrum.length; i++) {
        if (powerSpectrum[i] > peakPower) {
          peakPower = powerSpectrum[i];
          peakIndex = i;
        }
      }
      
      // Convert index to frequency (assuming 44.1kHz sample rate)
      const sampleRate = 44100.0;
      final peakFrequency = (peakIndex * sampleRate) / powerSpectrum.length;
      
      // Detect metal screech (2-4kHz)
      final metalScreechPower = _calculateBandPower(
        powerSpectrum, 
        metalScreechMin, 
        metalScreechMax, 
        sampleRate
      );
      
      // Detect glass shatter (5-15kHz)
      final glassShatterPower = _calculateBandPower(
        powerSpectrum,
        glassShatterMin,
        glassShatterMax,
        sampleRate
      );
      
      // Calculate broadband energy (structural crunch)
      final broadbandPower = powerSpectrum.reduce((a, b) => a + b) / powerSpectrum.length;
      
      // Determine if this is a crash sound
      final metalScreech = metalScreechPower > detectionThreshold;
      final glassShatter = glassShatterPower > detectionThreshold;
      final structuralCrunch = broadbandPower > detectionThreshold;
      
      // If any acoustic signature is detected, return it
      if (metalScreech || glassShatter || structuralCrunch) {
        return AcousticSignature(
          metalScreech: metalScreech,
          glassShatter: glassShatter,
          structuralCrunch: structuralCrunch,
          peakFrequency: peakFrequency,
          signalStrength: peakPower,
        );
      }
      
      return null;
    } catch (e) {
      print('Error analyzing audio: $e');
      return null;
    }
  }
  
  /// Calculate power in a specific frequency band
  double _calculateBandPower(
    List<double> powerSpectrum,
    double minFreq,
    double maxFreq,
    double sampleRate,
  ) {
    final minIndex = ((minFreq * powerSpectrum.length) / sampleRate).floor();
    final maxIndex = ((maxFreq * powerSpectrum.length) / sampleRate).ceil();
    
    double bandPower = 0.0;
    int count = 0;
    
    for (int i = minIndex; i < maxIndex && i < powerSpectrum.length; i++) {
      bandPower += powerSpectrum[i];
      count++;
    }
    
    return count > 0 ? bandPower / count : 0.0;
  }
  
  /// Trigger crash sound detection
  /// This would be called when accelerometer detects high G-force
  Future<AcousticSignature?> detectCrashSound() async {
    try {
      // In production, analyze the last ~500ms of audio buffer
      // For now, return null (no acoustic detection yet)
      // This will be fully implemented when we add continuous audio streaming
      
      print('🎤 Analyzing audio for crash signatures...');
      
      // Placeholder: would analyze real audio buffer here
      return null;
    } catch (e) {
      print('Error detecting crash sound: $e');
      return null;
    }
  }
  
  void stopListening() {
    _audioSubscription?.cancel();
    _isListening = false;
    print('🎤 Acoustic Fingerprinting Stopped');
  }
}
