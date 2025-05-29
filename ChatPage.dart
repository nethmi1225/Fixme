import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fixme_new/features/auth/data/models/ChatUserModel.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatPage extends StatefulWidget {
  final String receiverUid;
  final String senderName;
  final ChatUserModel receiver;

  const ChatPage({
    required this.receiverUid,
    required this.senderName,
    required this.receiver,
    super.key,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSendingNotification = false;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _saveFcmToken();
  }

  Future<void> _saveFcmToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null && FirebaseAuth.instance.currentUser != null) {
      print('Saving sender FCM token: $token for user: ${FirebaseAuth.instance.currentUser!.uid}');
      await _database
          .child('users/${FirebaseAuth.instance.currentUser!.uid}/fcmToken')
          .set(token);
    } else {
      print('Failed to save sender FCM token: token=$token, user=${FirebaseAuth.instance.currentUser?.uid}');
    }
  }

  Future<void> _sendPushNotification(String message) async {
    try {
      final snapshot = await _database.child('users/${widget.receiverUid}/fcmToken').get();
      if (!snapshot.exists || snapshot.value == null) {
        print('Receiver FCM token not found');
        return;
      }

      String receiverFcmToken = snapshot.value as String;
      const String fcmServerKey = 'YOUR_FCM_SERVER_KEY'; // Replace with your FCM server key

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$fcmServerKey',
        },
        body: jsonEncode({
          'to': receiverFcmToken,
          'notification': {
            'title': 'New Message from ${widget.senderName}',
            'body': message,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'chatId': '${FirebaseAuth.instance.currentUser!.uid}-${widget.receiverUid}',
          },
        }),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  Future<void> _sendMessageAndNotify(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _isSendingNotification = true;
    });

    try {
      String senderUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (senderUid.isEmpty) throw Exception('User not authenticated');

      print('Sender UID: $senderUid, Receiver UID: ${widget.receiverUid}');

      // Create a consistent chat ID
      String chatId = senderUid.compareTo(widget.receiverUid) < 0
          ? '$senderUid-${widget.receiverUid}'
          : '${widget.receiverUid}-$senderUid';
      print('Generated chatId: $chatId');

      // Store the message in the database
      String messageId = _database.child('chats/$chatId').push().key!;
      print('Generated messageId: $messageId');
      await _database.child('chats/$chatId/$messageId').set({
        'message': message,
        'senderUid': senderUid,
        'senderName': widget.senderName,
        'receiverUid': widget.receiverUid,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }).then((_) {
        print('Message successfully written to database at chats/$chatId/$messageId');
      }).catchError((error) {
        print('Failed to write message to database: $error');
        throw error;
      });

      // Send push notification to the receiver
      await _sendPushNotification(message);

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent!')),
      );
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() {
        _isSendingNotification = false;
      });
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    String senderUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (senderUid.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Text(
            'Please log in to send messages',
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              color: Color(0xFF131010),
            ),
          ),
        ),
      );
    }

    // Create the same chat ID for fetching messages
    String chatId = senderUid.compareTo(widget.receiverUid) < 0
        ? '$senderUid-${widget.receiverUid}'
        : '${widget.receiverUid}-$senderUid';
    print('Fetching messages for chatId: $chatId');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        title: Text(
          'Chat with ${widget.receiver.name}',
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _database.child('chats/$chatId').onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  print('ChatPage StreamBuilder: Waiting for messages...');
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C4B4),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  print('ChatPage StreamBuilder: Error: ${snapshot.error}');
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  print('ChatPage StreamBuilder: No messages found');
                  return const Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 16,
                        color: Color(0xFF131010),
                      ),
                    ),
                  );
                }

                Map<dynamic, dynamic> messages = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                print('ChatPage StreamBuilder: Fetched messages: $messages');
                List<MapEntry<dynamic, dynamic>> messageList = messages.entries.toList()
                  ..sort((a, b) => (b.value['timestamp'] as int).compareTo(a.value['timestamp'] as int));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16.0),
                  itemCount: messageList.length,
                  itemBuilder: (context, index) {
                    var messageData = messageList[index].value;
                    bool isSender = messageData['senderUid'] == senderUid;

                    return Align(
                      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
                      child: Card(
                        elevation: 2,
                        color: isSender ? const Color(0xFF00C4B4) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSender ? 'You' : messageData['senderName'],
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isSender ? Colors.white : const Color(0xFF131010),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                messageData['message'],
                                style: TextStyle(
                                  fontFamily: 'Open Sans',
                                  fontSize: 16,
                                  color: isSender ? Colors.white : const Color(0xFF131010),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateTime.fromMillisecondsSinceEpoch(messageData['timestamp']).toString().substring(11, 16),
                                style: TextStyle(
                                  fontFamily: 'Open Sans',
                                  fontSize: 12,
                                  color: isSender ? Colors.white70 : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Enter your message',
                        hintStyle: const TextStyle(
                          fontFamily: 'Open Sans',
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF00C4B4),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Open Sans',
                        fontSize: 16,
                        color: Color(0xFF131010),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSendingNotification
                    ? const CircularProgressIndicator(
                        color: Color(0xFF00C4B4),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: Color(0xFF00C4B4),
                          size: 30,
                        ),
                        onPressed: () {
                          _sendMessageAndNotify(_messageController.text);
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}