import 'package:flutter/material.dart';

class AIAssistantChatWidget extends StatefulWidget {
  const AIAssistantChatWidget();

  @override
  State<AIAssistantChatWidget> createState() => _AIAssistantChatWidgetState();
}

class _AIAssistantChatWidgetState extends State<AIAssistantChatWidget> {
  final List<Map<String, String>> messages = [];
  final TextEditingController _controller = TextEditingController();
  bool isOpen = false;

  void _toggleChat() {
    setState(() {
      isOpen = !isOpen;
    });
  }

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": _controller.text.trim()});
      _controller.clear();

      // Fake AI response
      messages.add({"sender": "ai", "text": "Let me help you with that!"});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Floating button
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: _toggleChat,
            backgroundColor: Colors.white,
            child: const Icon(Icons.auto_awesome, color: Colors.black87),
          ),
        ),

        // Chat widget
        if (isOpen)
          Positioned(
            bottom: 90,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(16),
              elevation: 10,
              child: Container(
                width: 320,
                height: 400,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "AI Assistant",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _toggleChat,
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isUser = msg["sender"] == "user";
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(maxWidth: 250),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.blue.shade100
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(msg["text"]!),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: "Type a message...",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sendMessage,
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          )
      ],
    );
  }
}
