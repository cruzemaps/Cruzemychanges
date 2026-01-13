import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cruze_mobile/services/micro_braking_service.dart';

class PlatooningService {
  static final PlatooningService _instance = PlatooningService._internal();
  static PlatooningService get instance => _instance;
  PlatooningService._internal();

  Timer? _pollingTimer;
  final String _baseUrl = kIsWeb 
      ? "http://localhost:7071" 
      : (defaultTargetPlatform == TargetPlatform.android ? "http://10.0.2.2:7071" : "http://127.0.0.1:7071");

  final StreamController<List<dynamic>> _messagesController = StreamController<List<dynamic>>.broadcast();
  Stream<List<dynamic>> get messagesStream => _messagesController.stream;

  Set<int> _processedMessageIds = {};

  void start() {
    print("Starting Platoon Service...");
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _pollMessages();
    });
  }
  
  void stop() {
    _pollingTimer?.cancel();
  }

  Future<void> _pollMessages() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/platoon/messages'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = data['messages'] as List;
        
        List<dynamic> newMessages = [];
        for (var msg in messages) {
           int id = msg['id'];
           if (!_processedMessageIds.contains(id)) {
             _processedMessageIds.add(id);
             newMessages.add(msg);
           }
        }
        
        if (newMessages.isNotEmpty) {
           _messagesController.add(newMessages);
        }
      }
    } catch (e) {
      print("Platoon Poll Error: $e");
    }
  }

  Future<void> broadcastMessage(String type, String content) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/platoon/message'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sender": "Me",
          "type": type,
          "content": content
        }),
      );
    } catch (e) {
      print("Error broadcasting platoon message: $e");
    }
  }
}
