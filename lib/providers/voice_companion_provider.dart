import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/chat_message.dart';
import '../services/ollama_service.dart';

class VoiceCompanionProvider with ChangeNotifier {
  final OllamaService _ollamaService = OllamaService();
  
  stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts _flutterTts = FlutterTts();

  bool _isListening = false;
  bool get isListening => _isListening;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  bool _isThinking = false;
  bool get isThinking => _isThinking;

  String _currentVoiceInput = '';
  String get currentVoiceInput => _currentVoiceInput;

  List<ChatMessage> _voiceMessages = [];
  List<ChatMessage> get voiceMessages => _voiceMessages;

  String? _selectedModel;
  String? get selectedModel => _selectedModel;

  VoiceCompanionProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Load Voice Memory
    await _loadVoiceMemory();
    
    // Initialize TTS
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    
    // Check available models from Ollama to pick a default
    try {
      final models = await _ollamaService.getModels();
      if (models.isNotEmpty) {
        _selectedModel = models.first;
      }
    } catch (_) {}
  }

  Future<void> _loadVoiceMemory() async {
    final prefs = await SharedPreferences.getInstance();
    final memoryJson = prefs.getStringList('voice_companion_memory') ?? [];
    
    _voiceMessages = memoryJson
        .map((m) => ChatMessage.fromJson(jsonDecode(m)))
        .toList();
    notifyListeners();
  }

  Future<void> _saveVoiceMemory() async {
    final prefs = await SharedPreferences.getInstance();
    final memoryJson = _voiceMessages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('voice_companion_memory', memoryJson);
  }

  void clearMemory() {
    _voiceMessages.clear();
    _saveVoiceMemory();
    notifyListeners();
  }

  void setModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (_isListening) {
      // Stop listening manually and trigger send
      await _speech.stop();
      _isListening = false;
      notifyListeners();
      
      if (_currentVoiceInput.isNotEmpty) {
        _handleUserInput(_currentVoiceInput);
      }
    } else {
      // Stop TTS if speaking
      if (_isSpeaking) {
        await _flutterTts.stop();
        _isSpeaking = false;
      }

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
            notifyListeners();
            if (_currentVoiceInput.isNotEmpty && !_isThinking) {
               _handleUserInput(_currentVoiceInput);
            }
          }
        },
        onError: (val) => print('STT Error: $val'),
      );
      
      if (available) {
        _isListening = true;
        _currentVoiceInput = '';
        notifyListeners();
        
        _speech.listen(
          onResult: (val) {
            _currentVoiceInput = val.recognizedWords;
            notifyListeners();
          },
        );
      } else {
        print("The user has denied the use of speech recognition.");
      }
    }
  }

  Future<void> _handleUserInput(String input) async {
    if (input.trim().isEmpty || _selectedModel == null) return;
    
    _currentVoiceInput = ''; // Clear temporary STT buffer
    
    _voiceMessages.add(ChatMessage(text: input, isUser: true));
    _isThinking = true;
    notifyListeners();

    // To provide conversation context to Ollama, we send the entire memory block as a prompt
    // For basic prompting we concatenate the history. In a real context window API, we'd pass roles.
    String promptContext = _buildPromptContext(input);

    try {
      final stream = _ollamaService.generateResponse(_selectedModel!, promptContext);
      
      String fullResponse = '';
      String currentSentenceBuffer = '';
      
      _voiceMessages.add(ChatMessage(text: '', isUser: false));
      final aiMessageIndex = _voiceMessages.length - 1;

      await for (final chunk in stream) {
        if (_isThinking) {
          _isThinking = false;
          _isSpeaking = true;
        }

        fullResponse += chunk;
        currentSentenceBuffer += chunk;
        
        _voiceMessages[aiMessageIndex] = ChatMessage(text: fullResponse, isUser: false);
        notifyListeners();

        // Very basic chunking by punctuation to read sentences fluidly while streaming
        if (chunk.contains('.') || chunk.contains('!') || chunk.contains('?')) {
          if (currentSentenceBuffer.trim().isNotEmpty) {
            await _flutterTts.speak(currentSentenceBuffer.trim());
            currentSentenceBuffer = '';
          }
        }
      }
      
      // Speak remainder
      if (currentSentenceBuffer.trim().isNotEmpty) {
         await _flutterTts.speak(currentSentenceBuffer.trim());
      }

      _saveVoiceMemory();
    } catch (e) {
      _voiceMessages.add(ChatMessage(text: "Error connecting to model: $e", isUser: false));
    } finally {
      _isThinking = false;
      // Note: _isSpeaking turns false via the TTS completion handler
      notifyListeners();
    }
  }

  String _buildPromptContext(String newInput) {
    // Basic context builder
    final buffer = StringBuffer();
    // Keep last 10 messages for context so we don't blow up context limit too fast
    final recentMemory = _voiceMessages.length > 20 
        ? _voiceMessages.sublist(_voiceMessages.length - 20) 
        : _voiceMessages;
        
    for (var msg in recentMemory) {
      if (msg.text.isNotEmpty) {
         buffer.writeln(msg.isUser ? "Human: ${msg.text}" : "Companion: ${msg.text}");
      }
    }
    
    buffer.writeln("Companion: "); // Prompt Ollama to answer as companion
    return buffer.toString();
  }
}
