import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: message.isUser ? Colors.blueAccent : Colors.teal.shade700,
            child: Icon(
              message.isUser ? Icons.person : Icons.memory,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isUser ? "You" : "Ollama",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser 
                        ? Colors.blueAccent.withOpacity(0.1) 
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: message.isUser 
                          ? Colors.blueAccent.withOpacity(0.3) 
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: message.isUser
                      ? Text(
                          message.text,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        )
                      : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(color: Colors.white, fontSize: 16),
                            code: TextStyle(
                              backgroundColor: Colors.black45,
                              color: Colors.greenAccent.shade200,
                              fontFamily: 'monospace',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (message.isUser) const SizedBox(width: 48) else const SizedBox(width: 24),
        ],
      ),
    );
  }
}
