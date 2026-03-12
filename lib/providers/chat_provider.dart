import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/ollama_service.dart';

class ChatProvider with ChangeNotifier {
  final OllamaService _ollamaService = OllamaService();

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  List<String> _models = [];
  List<String> get availableModels => _models;

  String? _selectedModel;
  String? get selectedModel => _selectedModel;

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  bool _isOllamaRunning = false;
  bool get isOllamaRunning => _isOllamaRunning;

  ChatProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    await checkOllamaStatus();
    if (_isOllamaRunning) {
      await fetchModels();
    }
  }

  Future<void> checkOllamaStatus() async {
    _isOllamaRunning = await _ollamaService.checkStatus();
    notifyListeners();
  }

  Future<void> fetchModels() async {
    _models = await _ollamaService.getModels();
    if (_models.isNotEmpty && _selectedModel == null) {
      _selectedModel = _models.first;
    }
    notifyListeners();
  }

  void selectModel(String model) {
    if (_models.contains(model)) {
      _selectedModel = model;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _selectedModel == null || _isGenerating) return;

    // Add user message
    _messages.add(ChatMessage(text: text, isUser: true));
    
    // Add empty assistant message to hold stream
    final aiMessageIndex = _messages.length;
    _messages.add(ChatMessage(text: '', isUser: false));
    
    _isGenerating = true;
    notifyListeners();

    try {
      final stream = _ollamaService.generateResponse(_selectedModel!, text);
      
      String responseText = '';
      await for (final chunk in stream) {
        responseText += chunk;
        
        // Update the last message (the AI's response)
        _messages[aiMessageIndex] = ChatMessage(text: responseText, isUser: false);
        notifyListeners();
      }
    } catch (e) {
      _messages[aiMessageIndex] = ChatMessage(
        text: 'Error connecting to Ollama: $e', 
        isUser: false
      );
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }
}
