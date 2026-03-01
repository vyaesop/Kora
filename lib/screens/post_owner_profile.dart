import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:convert';
import 'dart:io';
import 'package:Kora/model/thread_message.dart';
import 'package:Kora/model/user.dart';
import 'package:Kora/widgets/thread_message.dart';
import 'package:Kora/screens/comment_screen.dart';
import 'package:Kora/utils/backend_auth_service.dart';
import 'package:Kora/utils/backend_config.dart';

class PostOwnerProfileScreen extends StatefulWidget {
  final String userId;

  const PostOwnerProfileScreen({super.key, required this.userId});

  @override
  State<PostOwnerProfileScreen> createState() => _PostOwnerProfileScreenState();
}

class _PostOwnerProfileScreenState extends State<PostOwnerProfileScreen> {
  late Future<UserModel> userFuture;
  late Future<List<ThreadMessage>> threadsFuture;
  PanelController panelController = PanelController();

  final BackendAuthService _authService = BackendAuthService();

  Future<Map<String, dynamic>> _authedRequest(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not signed in');
    }

    final uri = Uri.parse('${BackendConfig.baseUrl}$path');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();
      final raw = await utf8.decoder.bind(res).join();
      final data = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] == false) {
        throw Exception((data['error'] ?? 'Request failed').toString());
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  Future<UserModel> fetchUserData(String userId) async {
    final data = await _authedRequest('/api/users/$userId');
    final user = (data['user'] as Map<String, dynamic>? ?? <String, dynamic>{});
    return UserModel(
      id: (user['id'] ?? '').toString(),
      name: (user['name'] ?? '').toString(),
      username: (user['username'] ?? user['email'] ?? '').toString(),
      followers: const [],
      following: const [],
      profileImageUrl: user['profileImageUrl']?.toString(),
      bio: user['bio']?.toString(),
      link: user['link']?.toString(),
      userType: (user['userType'] ?? 'Cargo').toString(),
      truckType: user['truckType']?.toString(),
      licensePlate: user['licensePlate']?.toString(),
      licenseNumber: user['licenseNumber']?.toString(),
      tradeLicense: user['tradeLicense']?.toString(),
      acceptedLoads: const [],
      termsAccepted: true,
      privacyAccepted: true,
    );
  }

  Future<List<ThreadMessage>> fetchUserThreads(UserModel user) async {
    final data = await _authedRequest('/api/users/${user.id}/threads');
    final threads = (data['threads'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((messageData) {
      final timestampRaw = messageData['createdAt']?.toString();
      final timestamp = timestampRaw == null
          ? DateTime.now()
          : DateTime.tryParse(timestampRaw) ?? DateTime.now();
      return ThreadMessage(
        id: (messageData['id'] ?? '').toString(),
        docId: (messageData['id'] ?? '').toString(),
        senderName: user.name,
        senderProfileImageUrl: user.profileImageUrl ??
            'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRz8cLf8-P2P8GZ0-KiQ-OXpZQ4bebpa3K3Dw&usqp=CAU',
        message: (messageData['message'] ?? '').toString(),
        timestamp: timestamp,
        likes: const [],
        comments: const [],
        weight: (messageData['weight'] as num?)?.toDouble() ?? 0.0,
        type: (messageData['type'] ?? '').toString(),
        start: (messageData['start'] ?? '').toString(),
        end: (messageData['end'] ?? '').toString(),
        packaging: (messageData['packaging'] ?? '').toString(),
        weightUnit: (messageData['weightUnit'] ?? '').toString(),
        startLat: (messageData['startLat'] as num?)?.toDouble() ?? 0.0,
        startLng: (messageData['startLng'] as num?)?.toDouble() ?? 0.0,
        endLat: (messageData['endLat'] as num?)?.toDouble() ?? 0.0,
        endLng: (messageData['endLng'] as num?)?.toDouble() ?? 0.0,
        deliveryStatus: messageData['deliveryStatus']?.toString(),
      );
    }).toList();

    return threads;
  }

  @override
  void initState() {
    userFuture = fetchUserData(widget.userId);
    threadsFuture = userFuture.then(fetchUserThreads);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: FutureBuilder<UserModel>(
            future: userFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                final UserModel? user = snapshot.data;
                return user != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text(user.name),
                            subtitle: Text('@${user.username}'),
                            trailing: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(user.profileImageUrl ?? ""),
                              radius: 25,
                            ),
                          ),
                          Text(user.bio ?? 'Bio needs to be here...'),
                          const SizedBox(height: 25),
                          if (user.userType == 'Driver') ...[
                            Text("Truck Type: ${user.truckType ?? 'N/A'}"),
                            const SizedBox(height: 10),
                            Text(
                                "License Plate: ${user.licensePlate ?? 'N/A'}"),
                            const SizedBox(height: 10),
                            Text(
                                "License Number: ${user.licenseNumber ?? 'N/A'}"),
                            const SizedBox(height: 10),
                            Text(
                                "Trade License: ${user.tradeLicense ?? 'N/A'}"),
                          ] else if (user.userType == 'Cargo') ...[
                            Text(
                                "Trade License: ${user.tradeLicense ?? 'N/A'}"),
                          ],
                          const SizedBox(height: 25),
                          Expanded(
                            child: FutureBuilder<List<ThreadMessage>>(
                              future: threadsFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final userThreads = snapshot.data!;
                                  return ListView.builder(
                                    itemCount: userThreads.length,
                                    itemBuilder: (context, index) {
                                      final message = userThreads[index];
                                      return InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  CommentScreen(
                                                message: message,
                                                threadId: message.docId,
                                              ),
                                            ),
                                          );
                                        },
                                        child: ThreadMessageWidget(
                                          message: message,
                                          onDisLike: () =>
                                              dislikeThreadMessage(message.id),
                                          onLike: () =>
                                              likeThreadMessage(message.id),
                                          onComment: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    CommentScreen(
                                                  message: message,
                                                  threadId: message.docId,
                                                ),
                                              ),
                                            );
                                          },
                                          onProfileTap: () {},
                                          userId: '',
                                          panelController: panelController,
                                          showBidButton: false,
                                        ),
                                      );
                                    },
                                  );
                                }
                                return const CircularProgressIndicator();
                              },
                            ),
                          ),
                        ],
                      )
                    : const Center(child: Text("User not found"));
              }
              return const CircularProgressIndicator();
            },
          ),
        ),
      ),
    );
  }

  Future<void> likeThreadMessage(String id) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Likes sync is being migrated to backend.')),
    );
  }

  Future<void> dislikeThreadMessage(String id) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Likes sync is being migrated to backend.')),
    );
  }
}
