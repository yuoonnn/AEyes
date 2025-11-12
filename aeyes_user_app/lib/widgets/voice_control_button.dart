import 'package:flutter/material.dart';
import '../services/speech_service.dart';

/// A reusable button widget for voice control
class VoiceControlButton extends StatefulWidget {
  final SpeechService? speechService;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;

  const VoiceControlButton({
    Key? key,
    required this.speechService,
    this.backgroundColor,
    this.iconColor,
    this.size = 60.0,
  }) : super(key: key);

  @override
  State<VoiceControlButton> createState() => _VoiceControlButtonState();
}

class _VoiceControlButtonState extends State<VoiceControlButton>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Listen to speech service status changes
    widget.speechService?.onListeningStatusChanged = (bool isListening) {
      if (mounted) {
        setState(() {
          _isListening = isListening;
        });
        if (isListening) {
          _animationController.repeat(reverse: true);
        } else {
          _animationController.stop();
          _animationController.reset();
        }
      }
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (widget.speechService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isListening) {
      await widget.speechService!.stopListening();
    } else {
      // Check permission first
      final hasPermission = await widget.speechService!.checkPermission();
      if (!hasPermission) {
        final granted = await widget.speechService!.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Microphone permission is required for voice control'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      await widget.speechService!.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _scaleAnimation.value : 1.0,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _isListening
                    ? (widget.backgroundColor ?? Colors.red)
                    : (widget.backgroundColor ?? Colors.blue),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isListening
                            ? (widget.backgroundColor ?? Colors.red)
                            : (widget.backgroundColor ?? Colors.blue))
                        .withOpacity(0.3),
                    blurRadius: _isListening ? 20 : 10,
                    spreadRadius: _isListening ? 5 : 2,
                  ),
                ],
              ),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: widget.iconColor ?? Colors.white,
                size: widget.size! * 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}

