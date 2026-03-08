import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../core/app_theme.dart';
import 'chat_service.dart';
import 'user_chat_screen.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});
  
  @override
  
  Widget build(BuildContext context) {
    final myUid = AuthService.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      
      body: StreamBuilder(
        
        stream: ChatService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
  return Center(
    child: Text(
      'Failed to load users: ${snapshot.error}',
      style: const TextStyle(color: Colors.white70),
      textAlign: TextAlign.center,
    ),
  );
}
print('logged in uid: ${AuthService.currentUser?.uid}');
print('users snapshot error: ${snapshot.error}');
print('users snapshot hasData: ${snapshot.hasData}');
print('current uid: ${AuthService.currentUser?.uid}');

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }

          final docs = snapshot.data!.docs
              .where((doc) => doc.id != myUid)
              .toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No users found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppTheme.dividerColor, height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final userId = doc.id;
              final userName = (data['name'] ?? 'User').toString();
              final email = (data['email'] ?? '').toString();

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.person, color: Colors.black),
                ),
                title: Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  email,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                onTap: () async {
                  final chatId = await ChatService.createOrGetChat(
                    otherUserId: userId,
                    otherUserName: userName,
                  );

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserChatScreen(
                        chatId: chatId,
                        title: userName,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}