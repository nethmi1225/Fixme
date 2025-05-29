import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fixme_new/features/auth/presentation/views/ChatPage.dart';
import 'package:flutter/material.dart';
import 'package:fixme_new/features/auth/data/models/ChatUserModel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final DatabaseReference database = FirebaseDatabase.instance.ref();
  final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (currentUserUid == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'Please log in to view your chats';
      });
      return;
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00C4B4),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
            ),
          ),
          child: Center(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                color: Colors.red,
                fontSize: 16,
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
          'Chats',
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
              print('ChatScreen StreamBuilder: Stream timed out after 10 seconds');
              sink.addError('Failed to load chats: Stream timed out');
              sink.close();
            },
          ),
          builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('ChatScreen StreamBuilder: Waiting for chats data...');
              return const Center(child: CircularProgressIndicator(color: Color(0xFF00C4B4)));
            }

            if (snapshot.hasError) {
              print('ChatScreen StreamBuilder: Error: ${snapshot.error}');
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontFamily: 'Open Sans')));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              print('ChatScreen StreamBuilder: No conversations found');
              return _buildNoChatsPrompt(context);
            }

            Map<dynamic, dynamic>? chats;
            try {
              chats = snapshot.data!.snapshot.value as Map<dynamic, dynamic>?;
              if (chats == null) {
                print('ChatScreen StreamBuilder: Chats data is null');
                return _buildNoChatsPrompt(context);
              }
            } catch (e) {
              print('ChatScreen StreamBuilder: Error parsing chats data: $e');
              return Center(child: Text('Error parsing chats: $e', style: const TextStyle(fontFamily: 'Open Sans')));
            }

            List<MapEntry<dynamic, dynamic>> relevantChats = chats.entries.where((entry) {
              String chatId = entry.key;
              List<String> uids = chatId.split('-');
              if (uids.length != 2) {
                print('ChatScreen StreamBuilder: Invalid chatId format: $chatId');
                return false;
              }
              bool hasAccess = uids.contains(currentUserUid);
              if (!hasAccess) {
                print('ChatScreen StreamBuilder: User $currentUserUid does not have access to chat $chatId');
              }
              return hasAccess;
            }).toList();

            if (relevantChats.isEmpty) {
              print('ChatScreen StreamBuilder: No relevant chats after filtering');
              return _buildNoChatsPrompt(context);
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
                      print('ChatScreen FutureBuilder: No user data for UID: $otherUserUid');
                      return const Card(
                        child: ListTile(title: Text('Loading...', style: TextStyle(fontFamily: 'Open Sans'))),
                      );
                    }

                    Map<dynamic, dynamic> userData;
                    try {
                      userData = userSnapshot.data!.value as Map<dynamic, dynamic>;
                    } catch (e) {
                      print('ChatScreen FutureBuilder: Error parsing user data for UID: $otherUserUid: $e');
                      return const Card(
                        child: ListTile(title: Text('Error loading user', style: TextStyle(fontFamily: 'Open Sans'))),
                      );
                    }

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
                          onTap: () async {
                            try {
                              final snapshot = await database.child('users/$otherUserUid').get();
                              if (snapshot.exists) {
                                final userData = snapshot.value as Map<dynamic, dynamic>;
                                userData['uid'] = otherUserUid;
                                final receiver = ChatUserModel.fromMap(Map<String, dynamic>.from(userData));
                                final senderSnapshot = await database.child('users/$currentUserUid').get();
                                String senderName = 'Unknown';
                                if (senderSnapshot.exists) {
                                  final senderData = senderSnapshot.value as Map<dynamic, dynamic>;
                                  senderName = senderData['firstName'] as String? ?? 'Unknown';
                                }
                                print('Navigating to ChatPage with receiver: ${receiver.name}, senderName: $senderName');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      receiver: receiver,
                                      receiverUid: otherUserUid,
                                      senderName: senderName,
                                    ),
                                  ),
                                );
                              } else {
                                print('ChatScreen: Service provider data not found for UID: $otherUserUid');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Service provider data not found', style: TextStyle(fontFamily: 'Open Sans')),
                                  ),
                                );
                              }
                            } catch (e) {
                              print('ChatScreen: Error navigating to ChatPage: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e', style: TextStyle(fontFamily: 'Open Sans')),
                                ),
                              );
                            }
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

  Widget _buildNoChatsPrompt(BuildContext context) {
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
              'Start a new chat with a service provider!',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C4B4), Color(0xFF00A1A7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Find a Service Provider',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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