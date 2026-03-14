import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_companion_provider.dart';
import '../widgets/message_bubble.dart';

class VoiceCompanionScreen extends StatefulWidget {
  const VoiceCompanionScreen({super.key});

  @override
  State<VoiceCompanionScreen> createState() => _VoiceCompanionScreenState();
}

class _VoiceCompanionScreenState extends State<VoiceCompanionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceCompanionProvider>(
      builder: (context, provider, child) {
        
        bool isPulsating = provider.isListening || provider.isThinking || provider.isSpeaking;
        
        Color buttonColor = Colors.blueAccent;
        if (provider.isListening) buttonColor = Colors.redAccent;
        if (provider.isThinking) buttonColor = Colors.purpleAccent;
        if (provider.isSpeaking) buttonColor = Colors.greenAccent;

        IconData buttonIcon = Icons.mic_none;
        if (provider.isListening) buttonIcon = Icons.mic;
        if (provider.isThinking) buttonIcon = Icons.more_horiz;
        if (provider.isSpeaking) buttonIcon = Icons.volume_up;

        String statusText = "Tap to speak";
        if (provider.isListening) statusText = "Listening...";
        if (provider.isThinking) statusText = "Thinking...";
        if (provider.isSpeaking) statusText = "Speaking...";

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
             backgroundColor: const Color(0xFF252526),
             title: const Text('Voice Companion', style: TextStyle(color: Colors.white)),
             actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => provider.clearMemory(),
                  tooltip: 'Clear Memory',
                )
             ],
          ),
          body: Column(
            children: [
               // Live transcribe / Model indicator
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(16),
                 child: Text(
                   provider.selectedModel != null ? "Model: \${provider.selectedModel}" : "No model selected",
                   textAlign: TextAlign.center,
                   style: const TextStyle(color: Colors.white54),
                 ),
               ),
               
               // Chat view (so user can read past history too)
               Expanded(
                 child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.voiceMessages.length,
                    itemBuilder: (context, index) {
                       return MessageBubble(message: provider.voiceMessages[index]);
                    },
                 ),
               ),
               
               if (provider.currentVoiceInput.isNotEmpty)
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                   child: Text(
                     '"\${provider.currentVoiceInput}"',
                     style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 16),
                     textAlign: TextAlign.center,
                   ),
                 ),
               
               // Controls Block
               Container(
                 padding: const EdgeInsets.symmetric(vertical: 32),
                 child: Column(
                    children: [
                       AnimatedBuilder(
                         animation: _animationController,
                         builder: (context, child) {
                           return Transform.scale(
                              scale: isPulsating ? _scaleAnimation.value : 1.0,
                              child: GestureDetector(
                                onTap: () => provider.toggleListening(),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: buttonColor.withValues(alpha: 0.2),
                                    border: Border.all(color: buttonColor, width: 3),
                                    boxShadow: isPulsating ? [
                                      BoxShadow(color: buttonColor.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)
                                    ] : [],
                                  ),
                                  child: Icon(buttonIcon, size: 50, color: buttonColor),
                                ),
                              ),
                           );
                         },
                       ),
                       const SizedBox(height: 16),
                       Text(
                         statusText,
                         style: TextStyle(color: buttonColor, fontSize: 16, fontWeight: FontWeight.bold),
                       )
                    ]
                 ),
               ),
            ],
          ),
        );
      },
    );
  }
}
