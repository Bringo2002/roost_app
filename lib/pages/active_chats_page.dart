import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import 'chat_room_page.dart';

class ActiveChatsPage extends StatefulWidget {
  const ActiveChatsPage({super.key});

  @override
  State<ActiveChatsPage> createState() => _ActiveChatsPageState();
}

class _ActiveChatsPageState extends State<ActiveChatsPage> {
  List<User> _partners = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final partners = await ChatService.getActiveChats();
      setState(() {
        _partners = partners;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MESSAGES'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadChats,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _partners.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadChats,
                      child: ListView.builder(
                        itemCount: _partners.length,
                        itemBuilder: (context, index) {
                          final partner = _partners[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.white24,
                              child: Text(
                                partner.name.isNotEmpty ? partner.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(partner.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(partner.role, style: const TextStyle(color: Colors.white54)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatRoomPage(partner: partner),
                                ),
                              ).then((_) => _loadChats());
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}
