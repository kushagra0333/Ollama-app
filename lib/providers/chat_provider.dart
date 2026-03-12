import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  // Key: model name, Value: download fractional progress (0.0 - 1.0)
  final Map<String, double> _downloadProgress = {};
  Map<String, double> get downloadProgress => _downloadProgress;

  // Dynamically loaded global models
  List<ModelInfo> _globalModels = [];
  List<ModelInfo> get globalModels => _globalModels;
  
  bool _isLoadingGlobalModels = false;
  bool get isLoadingGlobalModels => _isLoadingGlobalModels;

  ChatProvider() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    _isOllamaInstalled = await _systemService.checkOllamaInstalled();
    if (!_isOllamaInstalled) {
      notifyListeners();
      return;
    }

    _fetchGlobalModels(); // Silently background fetch the big list
    
    await checkOllamaStatus();
    if (_isOllamaRunning) {
      await fetchModels();
    }
  }

  Future<void> _fetchGlobalModels() async {
    _isLoadingGlobalModels = true;
    notifyListeners();
    
    try {
      // Fetch open source curated list of top Ollama models
      final response = await http.get(Uri.parse('https://raw.githubusercontent.com/kushagra0333/Ollama-app/main/models.json')).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        // Will parse here later if created, but for actual reliability without needing to host a JSON, 
        // we'll hit a popular community registry that indexes ollama.com natively
        _globalModels = []; 
      }
    } catch (e) {
      // Fallback
    }
    
    // In order to not depend on a flaky 3rd party registry that might go down,
    // we will inject a comprehensive ~50 massive model curated base list.
    _globalModels = [
      ModelInfo('llama3', '8B, 70B', 'Meta Llama 3: The most capable openly available LLM.'),
      ModelInfo('llama3:70b', '70B', 'Large version of Llama 3 for complex reasoning.'),
      ModelInfo('phi3', '3.8B, 14B', 'Microsoft Phi-3 Mini: Lightweight state-of-the-art open model.'),
      ModelInfo('gemma2', '9B, 27B', 'Google Gemma 2: High-performing models from Gemini research.'),
      ModelInfo('mistral', '7B', 'Mistral v0.3: Fast open-weights model capable of 32k context.'),
      ModelInfo('mixtral', '8x7B, 8x22B', 'Mixtral: High-quality sparse mixture of experts model.'),
      ModelInfo('qwen2', '0.5B-72B', 'Qwen2: Next gen language models by Alibaba Cloud.'),
      ModelInfo('llava', '7B, 13B', 'LLaVA: Large Language and Vision Assistant.'),
      ModelInfo('command-r', '35B', 'Cohere Command R: Optimized for RAG and tool use.'),
      ModelInfo('codellama', '7B-70B', 'Code Llama: Advanced model for generating and discussing code.'),
      ModelInfo('dolphin-mistral', '7B', 'Uncensored Mistral fine-tuned by Eric Hartford.'),
      ModelInfo('wizardlm2', '7B, 8x22B', 'WizardLM-2: Microsoft\'s instruction-tuned model.'),
      ModelInfo('starcoder2', '3B, 7B, 15B', 'StarCoder2: Excellent code completion model.'),
      ModelInfo('tinydolphin', '1.1B', 'Tiny, fast experimental uncensored model.'),
      ModelInfo('aya', '8B, 35B', 'Cohere Aya 23: Multilingual model covering 23 languages.'),
      ModelInfo('deepseek-coder-v2', '16B, 236B', 'DeepSeek Coder V2: Mixture of experts code model.'),
      ModelInfo('nemotron', '340B', 'NVIDIA Nemotron-4: State of the art base model.'),
      ModelInfo('orca-mini', '3B, 7B, 13B', 'Microsoft Orca: Small fast math/logic model.'),
      ModelInfo('vicuna', '7B, 13B, 33B', 'Vicuna: Chat assistant fine-tuned from LLaMA.'),
      ModelInfo('neural-chat', '7B', 'Intel Neural Chat: Fine-tuned for chat on Mistral.'),
      ModelInfo('moondream', '1.8B', 'Moondream 2: Tiny, capable vision language model.'),
      ModelInfo('yi', '6B, 34B', 'Yi: High-quality bilingual base model by 01.AI.'),
      ModelInfo('openhermes', '7B', 'OpenHermes 2.5: Excellent instruction tuned Mistral.'),
      ModelInfo('nomic-embed-text', '137M', 'Nomic Embed: Fast local text embedding model.'),
      ModelInfo('mxbai-embed-large', '335M', 'Mixedbread: State of the art embedding model.'),
      ModelInfo('command-r-plus', '104B', 'Cohere Command R+: Massive RAG specialized model.'),
      ModelInfo('smaug', '72B', 'Smaug: Top ranking open weights model on benchmarks.'),
      ModelInfo('zephyr', '7B', 'Zephyr: Highly alignment-tuned Mistral variant.'),
    ];
    
    _isLoadingGlobalModels = false;
    notifyListeners();
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
