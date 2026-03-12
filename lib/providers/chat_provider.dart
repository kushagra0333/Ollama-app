import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  List<ChatSession> _savedSessions = [];
  List<ChatSession> get savedSessions => _savedSessions;

  String? _currentSessionId;
  String? get currentSessionId => _currentSessionId;

  List<ChatMessage> get messages {
    if (_currentSessionId == null) return [];
    final session = _savedSessions.firstWhere((s) => s.id == _currentSessionId);
    return session.messages;
  }

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

  final Map<String, double> _downloadProgress = {};
  Map<String, double> get downloadProgress => _downloadProgress;

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
    await _loadSessions();
    
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

  // --- Chat History Management ---

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getStringList('chat_sessions') ?? [];
    
    _savedSessions = sessionsJson
        .map((s) => ChatSession.fromJson(jsonDecode(s)))
        .toList();
    
    if (_savedSessions.isEmpty) {
      createNewChat();
    } else {
      _currentSessionId = _savedSessions.first.id;
      _selectedModel = _savedSessions.first.model;
    }
    notifyListeners();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = _savedSessions.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('chat_sessions', sessionsJson);
  }

  void createNewChat() {
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Chat',
      model: _selectedModel,
      messages: [],
    );
    _savedSessions.insert(0, newSession);
    _currentSessionId = newSession.id;
    _saveSessions();
    notifyListeners();
  }

  void switchSession(String id) {
    if (_currentSessionId == id) return;
    _currentSessionId = id;
    final session = _savedSessions.firstWhere((s) => s.id == id);
    if (session.model != null && _models.contains(session.model)) {
      _selectedModel = session.model;
    }
    notifyListeners();
  }

  void deleteSession(String id) {
    _savedSessions.removeWhere((s) => s.id == id);
    if (_savedSessions.isEmpty) {
      createNewChat();
    } else if (_currentSessionId == id) {
      _currentSessionId = _savedSessions.first.id;
      _selectedModel = _savedSessions.first.model;
    }
    _saveSessions();
    notifyListeners();
  }

  void _updateSessionTitleAndModel(String firstMessage) {
    if (_currentSessionId == null) return;
    final session = _savedSessions.firstWhere((s) => s.id == _currentSessionId);
    if (session.messages.length <= 2) { // First message
      session.title = firstMessage.length > 30 ? '\${firstMessage.substring(0, 30)}...' : firstMessage;
    }
    session.model = _selectedModel;
    _saveSessions();
  }

  // --- End Chat History Management ---

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
      if (_currentSessionId != null) {
        final session = _savedSessions.firstWhere((s) => s.id == _currentSessionId);
        session.model = model;
        _saveSessions();
      }
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _selectedModel == null || _isGenerating || _currentSessionId == null) return;

    final session = _savedSessions.firstWhere((s) => s.id == _currentSessionId);

    session.messages.add(ChatMessage(text: text, isUser: true));
    
    final aiMessageIndex = session.messages.length;
    session.messages.add(ChatMessage(text: '', isUser: false));
    
    _isGenerating = true;
    _updateSessionTitleAndModel(text);
    notifyListeners();

    try {
      final stream = _ollamaService.generateResponse(_selectedModel!, text);
      
      String responseText = '';
      await for (final chunk in stream) {
        // If the user rapidly switches chats mid-generation, stop updating this specific message in UI
        if (_currentSessionId != session.id) continue;
        
        responseText += chunk;
        session.messages[aiMessageIndex] = ChatMessage(text: responseText, isUser: false);
        notifyListeners();
      }
      // Save full message to disk once done
      _saveSessions();
    } catch (e) {
      if (_currentSessionId == session.id) {
        session.messages[aiMessageIndex] = ChatMessage(
          text: 'Error connecting to Ollama: $e', 
          isUser: false
        );
      }
    } finally {
      if (_currentSessionId == session.id) {
        _isGenerating = false;
        notifyListeners();
      }
    }
  }
}
