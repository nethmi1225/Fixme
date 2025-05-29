import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fixme_new/features/auth/presentation/views/ChatPage.dart';
import 'package:flutter/material.dart';
import 'package:fixme_new/features/auth/data/models/ChatUserModel.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final DatabaseReference database = FirebaseDatabase.instance.ref();
  final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (currentUserUid == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
            ),
          ),
          child: const Center(
            child: Text(
              'Please log in to view conversations',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        elevation: 0,
        title: const Text(
          'Conversations',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
          ),
        ),
        child: StreamBuilder(
          stream: database.child('chats').onValue.timeout(
            const Duration(seconds: 10),
            onTimeout: (sink) {
              print('ConversationsScreen StreamBuilder: Stream timed out after 10 seconds');
              sink.addError('Failed to load conversations: Stream timed out');
              sink.close();
            },
          ),
          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('ConversationsScreen StreamBuilder: Waiting for chats data...');
              return const Center(child: CircularProgressIndicator(color: Color(0xFF00C4B4)));
            }

            if (snapshot.hasError) {
              print('ConversationsScreen StreamBuilder: Error: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontFamily: 'Open Sans')));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              print('ConversationsScreen StreamBuilder: No conversations found');
              return _buildNoConversationsPrompt(context);
            }

            Map<dynamic, dynamic>? chats;
            try {
              chats = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
              if (chats == null) {
                print('ConversationsScreen StreamBuilder: Chats data is null');
                return _buildNoConversationsPrompt(context);
              }
            } catch (e) {
              print('ConversationsScreen StreamBuilder: Error parsing chats data: $e');
              return Center(child: Text('Error parsing chats: $e', style: const TextStyle(fontFamily: 'Open Sans')));
            }

            List<MapEntry<dynamic, dynamic>> relevantChats = chats.entries.where((entry) {
              String chatId = entry.key;
              List<String> uids = chatId.split('-');
              if (uids.length != 2) {
                print('ConversationsScreen StreamBuilder: Invalid chatId format: $chatId');
                return false;
              }
              bool hasAccess = uids.contains(currentUserUid);
              if (!hasAccess) {
                print('ConversationsScreen StreamBuilder: User $currentUserUid does not have access to chat $chatId');
              }
              return hasAccess;
            }).toList();

            if (relevantChats.isEmpty) {
              print('ConversationsScreen StreamBuilder: No relevant chats after filtering');
              return _buildNoConversationsPrompt(context);
            }

            relevantChats.sort((a, b) {
              Map<dynamic, dynamic> messagesA = a.value as Map<dynamic, dynamic>;
              Map<dynamic, dynamic> messagesB = b.value as Map<dynamic, dynamic>;
              int latestTimestampA = messagesA.entries.fold(0, (max, entry) {
                return (entry.value['timestamp'] as int? ?? 0) > max ? (entry.value['timestamp'] as int) : max;
              });
              int latestTimestampB = messagesB.entries.fold(0, (max, entry) {
                return (entry.value['timestamp'] as int? ?? 0) > max ? (entry.value['timestamp'] as int) : max;
              });
              return latestTimestampB.compareTo(latestTimestampA);
            });

            return ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: relevantChats.length,
              itemBuilder: (context, index) {
                String chatId = relevantChats[index].key;
                List<String> uids = chatId.split('-');
                String otherUserUid = uids[0] == currentUserUid ? uids[1] : uids[0];

                return FutureBuilder(
                  future: database.child('users/$otherUserUid').get(),
                  builder: (context, AsyncSnapshot<DataSnapshot> userSnapshot) {
                    if (!userSnapshot.hasData || userSnapshot.data!.value == null) {
                      return const Card(
                        child: ListTile(title: Text('Loading...', style: TextStyle(fontFamily: 'Open Sans'))),
                      );
                    }

                    Map<dynamic, dynamic> userData = userSnapshot.data!.value as Map<dynamic, dynamic>;
                    String userName = userData['firstName']?.toString() ?? 'Unknown';

                    Map<dynamic, dynamic> messages = relevantChats[index].value as Map<dynamic, dynamic>;
                    var latestMessageEntry = messages.entries.toList()
                      ..sort((a, b) => (b.value['timestamp'] as int).compareTo(a.value['timestamp'] as int));
                    String lastMessage = latestMessageEntry.isNotEmpty
                        ? latestMessageEntry.first.value['message']?.toString() ?? ''
                        : 'No messages yet';
                    int lastTimestamp = latestMessageEntry.isNotEmpty
                        ? latestMessageEntry.first.value['timestamp'] as int
                        : 0;

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            radius: 25,
                            backgroundColor: Color(0xFF00C4B4),
                            child: Icon(Icons.person, size: 30, color: Colors.white),
                          ),
                          title: Text(
                            userName,
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF131010),
                            ),
                          ),
                          subtitle: Text(
                            lastMessage,
                            style: const TextStyle(
                              fontFamily: 'Open Sans',
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            lastTimestamp != 0
                                ? DateTime.fromMillisecondsSinceEpoch(lastTimestamp).toString().substring(11, 16)
                                : '',
                            style: const TextStyle(
                              fontFamily: 'Open Sans',
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  receiverUid: otherUserUid,
                                  senderName: FirebaseAuth.instance.currentUser?.displayName ?? 'Service Provider',
                                  receiver: ChatUserModel(
                                    otherUserUid,
                                    name: userName,
                                    email: userData['email']?.toString() ?? '',
                                    uid: otherUserUid,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 2),
    );
  }

  Widget _buildNoConversationsPrompt(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No conversations yet.',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 18,
                color: Color(0xFF131010),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Wait for customers to start a chat with you.',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int selectedIndex) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF00C4B4),
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Booking'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/booking');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/chat');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/profile');
            break;
        }
      },
    );
  }
}