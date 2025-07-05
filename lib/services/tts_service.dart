import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class TtsService {
  FlutterTts? _flutterTts;
  bool _isEnabled = true;
  String _lastSpokenMessage = '';
  DateTime _lastSpeechTime = DateTime.now();
  static const Duration _speechCooldown = Duration(seconds: 3);

  TtsService() {
    _initialize();
  }

  bool get isEnabled => _isEnabled;

  Future<void> _initialize() async {
    if (!_isEnabled) return;
    
    try {
      _flutterTts = FlutterTts();
      await _flutterTts?.setLanguage("en-US");
      await _flutterTts?.setSpeechRate(0.6);
      await _flutterTts?.setVolume(0.8);
      await _flutterTts?.setPitch(1.0);
    } catch (e) {
      print("Failed to initialize TTS: $e");
    }
  }

  Future<void> speak(String message) async {
    if (!_isEnabled || _flutterTts == null) return;
    
    final now = DateTime.now();
    if (_lastSpokenMessage == message && 
        now.difference(_lastSpeechTime) < _speechCooldown) {
      return;
    }
    
    _lastSpokenMessage = message;
    _lastSpeechTime = now;
    
    try {
      await _flutterTts?.stop();
      await _flutterTts?.speak(message);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  void toggleVoice() {
    _isEnabled = !_isEnabled;
    if (!_isEnabled) {
      stop();
    } else {
      _initialize();
    }
  }

  void stop() {
    _flutterTts?.stop();
  }

  void dispose() {
    _flutterTts?.stop();
    _flutterTts = null;
  }
}