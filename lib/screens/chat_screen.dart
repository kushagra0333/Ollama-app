import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        
        // Auto-scroll when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.isGenerating) {
            _scrollToBottom();
          }
        });

        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E), // Dark VS Code-like background
          appBar: AppBar(
            backgroundColor: const Color(0xFF252526),
            title: const Text('Ollama Desktop', style: TextStyle(color: Colors.white)),
            elevation: 0,
            actions: [
              if (!provider.isOllamaRunning)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Text('🔴 Ollama Offline', style: TextStyle(color: Colors.redAccent)),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Text('🟢 Ollama Connected', style: TextStyle(color: Colors.greenAccent)),
                  ),
                ),
            ],
          ),
          body: Row(
            children: [
              // Sidebar for Models
              Container(
                width: 250,
                color: const Color(0xFF252526),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'AVAILABLE MODELS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: provider.availableModels.isEmpty
                          ? const Center(
                              child: Text(
                                'No models found.\nRun `ollama run <model>`\nin your terminal.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: provider.availableModels.length,
                              itemBuilder: (context, index) {
                                final model = provider.availableModels[index];
                                final isSelected = provider.selectedModel == model;
                                
                                return ListTile(
                                  title: Text(
                                    model,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  tileColor: isSelected ? Colors.blueAccent.withOpacity(0.2) : null,
                                  onTap: () => provider.selectModel(model),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.withOpacity(0.2),
                          foregroundColor: Colors.blueAccent,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        onPressed: provider.clearChat,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Clear Chat'),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Vertical Divider
              Container(width: 1, color: Colors.black),
              
              // Chat Area
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: provider.messages.isEmpty
                          ? const Center(
                              child: Text(
                                'Select a model and start chatting!',
                                style: TextStyle(color: Colors.white54, fontSize: 18),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: provider.messages.length,
                              itemBuilder: (context, index) {
                                return MessageBubble(message: provider.messages[index]);
                              },
                            ),
                    ),
                    
                    // Input Area
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: const BoxDecoration(
                        color: Color(0xFF252526),
                        border: Border(top: BorderSide(color: Colors.black)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: provider.selectedModel != null
                                    ? 'Message ${provider.selectedModel}...'
                                    : 'Please wait for connection...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: const Color(0xFF3E3E42),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                              onSubmitted: (value) {
                                if (value.isNotEmpty && !provider.isGenerating) {
                                  provider.sendMessage(value);
                                  _textController.clear();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          CircleAvatar(
                            backgroundColor: provider.isGenerating || provider.selectedModel == null
                                ? Colors.grey
                                : Colors.blueAccent,
                            child: IconButton(
                              icon: provider.isGenerating 
                                  ? const SizedBox(
                                      width: 20, 
                                      height: 20, 
                                      child: CircularProgressIndicator(
                                        color: Colors.white, 
                                        strokeWidth: 2
                                      )
                                    )
                                  : const Icon(Icons.send, color: Colors.white),
                              onPressed: () {
                                if (_textController.text.isNotEmpty && !provider.isGenerating) {
                                  provider.sendMessage(_textController.text);
                                  _textController.clear();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
