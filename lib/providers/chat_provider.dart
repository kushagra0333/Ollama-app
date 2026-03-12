import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/ollama_service.dart';
import '../services/system_service.dart';

class ModelInfo {
  final String name;
  final String parameters;
  final String description;

  ModelInfo(this.name, this.parameters, this.description);
}

class ChatProvider with ChangeNotifier {
  final OllamaService _ollamaService = OllamaService();
  final SystemService _systemService = SystemService();

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

  bool _isOllamaInstalled = true;
  bool get isOllamaInstalled => _isOllamaInstalled;

  bool _isInstallingEngine = false;
  bool get isInstallingEngine => _isInstallingEngine;

  // Downloading State Map
  // Key: model name, Value: download fractional progress (0.0 - 1.0)
  final Map<String, double> _downloadProgress = {};
  Map<String, double> get downloadProgress => _downloadProgress;

  // Predefined models for the downloader
  final List<ModelInfo> recommendedModels = [
    ModelInfo('llama3', '8B', 'Meta\'s powerful open model.'),
    ModelInfo('mistral', '7B', 'High-performance model by Mistral AI.'),
    ModelInfo('phi3', '3.8B', 'Microsoft\'s extremely lightweight model.'),
    ModelInfo('gemma2', '9B', 'Google\'s open model built from Gemini tech.'),
  ];

  ChatProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    _isOllamaInstalled = await _systemService.checkOllamaInstalled();
    if (!_isOllamaInstalled) {
      notifyListeners();
      return;
    }

    await checkOllamaStatus();
    if (_isOllamaRunning) {
      await fetchModels();
    }
  }

  Future<void> installOllamaEngine() async {
    _isInstallingEngine = true;
    notifyListeners();
    
    final success = await _systemService.installOllama();
    _isInstallingEngine = false;

    if (success) {
      _isOllamaInstalled = true;
      await checkOllamaStatus();
      if (_isOllamaRunning) await fetchModels();
    }
    notifyListeners();
  }

  Future<void> downloadModel(String modelName) async {
    if (_downloadProgress.containsKey(modelName)) return;

    _downloadProgress[modelName] = 0.0;
    notifyListeners();

    try {
      final stream = _ollamaService.pullModel(modelName);
      await for (final progress in stream) {
        if (progress == -1.0) {
          _downloadProgress.remove(modelName);
          notifyListeners();
          return;
        }
        _downloadProgress[modelName] = progress;
        notifyListeners();
      }
      
      // Successfully downloaded
      _downloadProgress.remove(modelName);
      await fetchModels();
      if (_selectedModel == null) selectModel(modelName);
      
    } catch (e) {
      _downloadProgress.remove(modelName);
    }
    notifyListeners();
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

    _messages.add(ChatMessage(text: text, isUser: true));
    
    final aiMessageIndex = _messages.length;
    _messages.add(ChatMessage(text: '', isUser: false));
    
    _isGenerating = true;
    notifyListeners();

    try {
      final stream = _ollamaService.generateResponse(_selectedModel!, text);
      
      String responseText = '';
      await for (final chunk in stream) {
        responseText += chunk;
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
