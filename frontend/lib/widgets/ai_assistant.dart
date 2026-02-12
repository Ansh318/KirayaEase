import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AIAssistantChatWidget extends StatefulWidget {
  const AIAssistantChatWidget({super.key});

  @override
  State<AIAssistantChatWidget> createState() => _AIAssistantChatWidgetState();
}

class _AIAssistantChatWidgetState extends State<AIAssistantChatWidget> {
  final List<Map<String, String>> messages = [];
  final TextEditingController _controller = TextEditingController();
  bool isOpen = false;
  bool isLoading = false;

  void _toggleChat() {
    setState(() {
      isOpen = !isOpen;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": text});
      isLoading = true;
      _controller.clear();
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.chatbotEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText = data["response"];

        setState(() {
          messages.add({"sender": "ai", "text": aiText});
        });
      } else {
        setState(() {
          messages.add({
            "sender": "ai",
            "text": "⚠️ Server error: ${response.statusCode}"
          });
        });
      }
    } catch (e) {
      setState(() {
        messages
            .add({"sender": "ai", "text": "❌ Could not connect to server."});
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Floating Button
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: _toggleChat,
            backgroundColor: const Color.fromARGB(221, 255, 255, 255),
            child: const Icon(Icons.chat_bubble, color: Colors.white),
          ),
        ),

        // Chat Popup
        if (isOpen)
          Positioned(
            bottom: 90,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 340,
                  height: 460,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color.fromARGB(255, 0, 0, 0).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "RentWise AI",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: _toggleChat,
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),

                      // Messages
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
                                padding: const EdgeInsets.all(12),
                                constraints:
                                    const BoxConstraints(maxWidth: 260),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Colors.blueAccent.withOpacity(0.8)
                                      : Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(isUser ? 16 : 0),
                                    bottomRight:
                                        Radius.circular(isUser ? 0 : 16),
                                  ),
                                ),
                                child: Text(
                                  msg["text"]!,
                                  style: TextStyle(
                                    color:
                                        isUser ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Typing...",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Input Field
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Type a message...",
                                hintStyle: TextStyle(color: Colors.white60),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                              ),
                              child: const Icon(Icons.send,
                                  size: 20, color: Colors.white),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
      ],
    );
  }
}
