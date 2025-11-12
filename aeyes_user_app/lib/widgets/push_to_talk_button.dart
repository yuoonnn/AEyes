import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import '../services/bluetooth_service.dart';
import '../services/openai_service.dart';
import 'dart:typed_data';

/// Push-to-talk button for voice-controlled image analysis
/// User holds button, speaks a question, releases button, then image is captured and analyzed
class PushToTalkButton extends StatefulWidget {
  final SpeechService? speechService;
  final AppBluetoothService? bluetoothService;
  final OpenAIService? openAIService;
  final Function(String)? onAnalysisComplete;
  final Function(String)? onError;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? iconColor;
  final double? size;

  const PushToTalkButton({
    Key? key,
    required this.speechService,
    required this.bluetoothService,
    required this.openAIService,
    this.onAnalysisComplete,
    this.onError,
    this.backgroundColor,
    this.activeColor,
    this.iconColor,
    this.size = 80.0,
  }) : super(key: key);

  @override
  State<PushToTalkButton> createState() => _PushToTalkButtonState();
}

class _PushToTalkButtonState extends State<PushToTalkButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  bool _isProcessing = false;
  String? _capturedVoiceCommand;
  Uint8List? _capturedImage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Set up speech service callbacks
    widget.speechService?.onSpeechResult = (String text) {
      if (mounted && _isListening) {
        setState(() {
          _capturedVoiceCommand = text;
        });
      }
    };

    widget.speechService?.onError = (String error) {
      if (mounted) {
        widget.onError?.call('Speech error: $error');
        _resetState();
      }
    };

    // Note: Image capture is handled via a temporary callback override
    // The global callback in main.dart will still work for other cases
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _resetState() {
    setState(() {
      _isListening = false;
      _isProcessing = false;
      _capturedVoiceCommand = null;
      _capturedImage = null;
    });
    _pulseController.stop();
    _pulseController.reset();
  }

  Future<void> _onButtonPressStart() async {
    if (_isProcessing) return; // Don't allow new presses while processing

    if (widget.speechService == null) {
      widget.onError?.call('Voice control temporarily disabled - plugin compatibility issue. Use ESP32 button for voice commands.');
      return;
    }

    // Check permissions
    final hasPermission = await widget.speechService!.checkPermission();
    if (!hasPermission) {
      final granted = await widget.speechService!.requestPermission();
      if (!granted) {
        widget.onError?.call('Microphone permission required');
        return;
      }
    }

    // Start listening
    setState(() {
      _isListening = true;
      _capturedVoiceCommand = null;
    });
    _pulseController.repeat(reverse: true);

    try {
      await widget.speechService!.startListening(
        partialResults: false, // Only get final results
      );
    } catch (e) {
      widget.onError?.call('Failed to start listening: $e');
      _resetState();
    }
  }

  Future<void> _onButtonPressEnd() async {
    if (!_isListening) return;

    setState(() {
      _isListening = false;
      _isProcessing = true;
    });
    _pulseController.stop();
    _pulseController.reset();

    // Stop listening and get final result
    await widget.speechService!.stopListening();

    // Wait a moment for final speech result
    await Future.delayed(const Duration(milliseconds: 500));

    final voiceCommand = _capturedVoiceCommand?.trim() ?? '';

    if (voiceCommand.isEmpty) {
      widget.onError?.call('No voice command detected. Please try again.');
      _resetState();
      return;
    }

    // Check if ESP32 is connected
    if (widget.bluetoothService == null || !widget.bluetoothService!.isConnected) {
      widget.onError?.call('ESP32 not connected. Please connect to your device first.');
      _resetState();
      return;
    }

    // Request image capture from ESP32
    try {
      // Temporarily override the image callback to capture this specific image
      Function(Uint8List)? originalCallback = widget.bluetoothService!.onImageReceived;
      
      widget.bluetoothService!.onImageReceived = (Uint8List imageBytes) {
        if (mounted && _isProcessing) {
          setState(() {
            _capturedImage = imageBytes;
          });
          // Restore original callback
          widget.bluetoothService!.onImageReceived = originalCallback;
          _processVoiceAndImage();
        } else {
          // If not processing, pass to original callback
          originalCallback?.call(imageBytes);
        }
      };

      await widget.bluetoothService!.requestImageCapture();
      
      // Set a timeout in case image doesn't arrive
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && _isProcessing && _capturedImage == null) {
          widget.bluetoothService!.onImageReceived = originalCallback;
          widget.onError?.call('Image capture timeout. Please try again.');
          _resetState();
        }
      });
    } catch (e) {
      widget.onError?.call('Failed to request image: $e');
      _resetState();
    }
  }

  Future<void> _processVoiceAndImage() async {
    if (_capturedImage == null || widget.openAIService == null) {
      widget.onError?.call('Missing image or OpenAI service');
      _resetState();
      return;
    }

    final voiceCommand = _capturedVoiceCommand ?? '';

    try {
      // Analyze image with voice command as prompt
      final analysis = await widget.openAIService!.analyzeImageWithPrompt(
        _capturedImage!,
        customPrompt: voiceCommand.isNotEmpty
            ? "You are assisting a blind user. Answer this question about the image: $voiceCommand. Be clear, concise, and helpful."
            : null,
      );

      widget.onAnalysisComplete?.call(analysis);
    } catch (e) {
      widget.onError?.call('Analysis failed: $e');
    } finally {
      _resetState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isListening || _isProcessing;
    final buttonColor = isActive
        ? (widget.activeColor ?? Colors.red)
        : (widget.backgroundColor ?? Colors.blue);

    return GestureDetector(
      onTapDown: (_) => _onButtonPressStart(),
      onTapUp: (_) => _onButtonPressEnd(),
      onTapCancel: () => _onButtonPressEnd(),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: buttonColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withOpacity(isActive ? 0.5 : 0.3),
                    blurRadius: isActive ? 25 : 10,
                    spreadRadius: isActive ? 8 : 2,
                  ),
                ],
              ),
              child: Center(
                child: _isProcessing
                    ? SizedBox(
                        width: widget.size! * 0.4,
                        height: widget.size! * 0.4,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.iconColor ?? Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: widget.iconColor ?? Colors.white,
                        size: widget.size! * 0.5,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

