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

  void _showDownloadDialog(BuildContext context, ChatProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF252526),
          title: const Text('Download Models', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView.builder(
              itemCount: provider.recommendedModels.length,
              itemBuilder: (context, index) {
                final ref = provider.recommendedModels[index];
                
                // Track progress live utilizing Provider inside the dialog
                return Consumer<ChatProvider>(
                  builder: (context, liveProvider, child) {
                    final isDownloading = liveProvider.downloadProgress.containsKey(ref.name);
                    final progress = liveProvider.downloadProgress[ref.name] ?? 0.0;
                    final isInstalled = liveProvider.availableModels.contains(ref.name);

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${ref.name.toUpperCase()}  (${ref.parameters})', 
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                                ),
                                if (isInstalled)
                                  const Icon(Icons.check_circle, color: Colors.green)
                                else if (isDownloading)
                                  SizedBox(
                                    height: 20, width: 20, 
                                    child: CircularProgressIndicator(value: progress, color: Colors.blueAccent)
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      liveProvider.downloadModel(ref.name);
                                    },
                                    child: const Text('Download'),
                                  )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(ref.description, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            if (isDownloading) ...[
                              const SizedBox(height: 10),
                              LinearProgressIndicator(value: progress, backgroundColor: Colors.black, color: Colors.blueAccent),
                              const SizedBox(height: 4),
                              Text('${(progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white54, fontSize: 12))
                            ]
                          ],
                        ),
                      ),
                    );
                  }
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, child) {
        
        // Auto-scroll logic
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (provider.isGenerating) {
            _scrollToBottom();
          }
        });

        // Installer View - Shown if Ollama binary is missing from system
        if (!provider.isOllamaInstalled) {
          return Scaffold(
            backgroundColor: const Color(0xFF1E1E1E),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orangeAccent),
                  const SizedBox(height: 24),
                  const Text('Ollama Engine Not Found', 
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 12),
                  const Text('The Ollama backend service is required to run models locally.\nWould you like to install it now?', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16)
                  ),
                  const SizedBox(height: 32),
                  provider.isInstallingEngine
                    ? const Column(
                        children: [
                          CircularProgressIndicator(color: Colors.blueAccent),
                          SizedBox(height: 16),
                          Text('Installing Engine... Please check prompt.', style: TextStyle(color: Colors.white54))
                        ],
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => provider.installOllamaEngine(),
                        icon: const Icon(Icons.download),
                        label: const Text('Install Ollama (requires sudo)', style: TextStyle(fontSize: 16)),
                      )
                ],
              ),
            ),
          );
        }

        // Main Chat Interface
        return Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF252526),
            title: const Text('Ollama Desktop', style: TextStyle(color: Colors.white)),
            elevation: 0,
            actions: [
              if (!provider.isOllamaRunning)
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh, color: Colors.redAccent, size: 16),
                      label: const Text('🔴 Engine Offline - Retry', style: TextStyle(color: Colors.redAccent)),
                      onPressed: () => provider.checkOllamaStatus(),
                    )
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
              // Sidebar
              Container(
                width: 250,
                color: const Color(0xFF252526),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // New Chat Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          alignment: Alignment.centerLeft,
                          elevation: 0,
                        ),
                        onPressed: provider.createNewChat,
                        icon: const Icon(Icons.add),
                        label: const Text('New Chat'),
                      ),
                    ),
                    const Divider(color: Colors.black54, height: 1),
                    
                    // Chat History List
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              'CHAT HISTORY',
                              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: provider.savedSessions.length,
                              itemBuilder: (context, index) {
                                final session = provider.savedSessions[index];
                                final isSelected = provider.currentSessionId == session.id;

                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    session.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                                    onPressed: () => provider.deleteSession(session.id),
                                  ),
                                  tileColor: isSelected ? Colors.white.withValues(alpha: 0.1) : null,
                                  onTap: () => provider.switchSession(session.id),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.black54),
                    
                    // Available Models Area
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        'CURRENT MODEL',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      height: 120, // Fixed height for models list
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: provider.availableModels.isEmpty
                          ? const Center(
                              child: Text('No models installed.', style: TextStyle(color: Colors.white54)),
                            )
                          : ListView.builder(
                              itemCount: provider.availableModels.length,
                              itemBuilder: (context, index) {
                                final model = provider.availableModels[index];
                                final isSelected = provider.selectedModel == model;
                                
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    model,
                                    style: TextStyle(
                                      color: isSelected ? Colors.blueAccent : Colors.white70,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  leading: isSelected ? const Icon(Icons.check, color: Colors.blueAccent, size: 16) : const SizedBox(width: 16),
                                  onTap: () => provider.selectModel(model),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                        ),
                        onPressed: () => _showDownloadDialog(context, provider),
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('Download Models'),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider
              Container(width: 1, color: Colors.black),
              
              // Chat Interface
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: provider.messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
                                  const SizedBox(height: 16),
                                  Text(
                                    provider.availableModels.isEmpty 
                                      ? 'Install a model from within the Sidebar to begin.' 
                                      : 'Send a message to start a new chat history!',
                                    style: const TextStyle(color: Colors.white54, fontSize: 18),
                                  ),
                                ],
                              )
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
                                    : 'Please select a model...',
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: const Color(0xFF3E3E42),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.send, color: Colors.white),
                              onPressed: () {
                                if (_textController.text.isNotEmpty && !provider.isGenerating && provider.selectedModel != null) {
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
