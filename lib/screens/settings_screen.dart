import 'package:flutter/material.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _handleLogout(BuildContext context) {
    // TODO: 로그아웃 로직 구현
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // 모든 이전 화면 제거
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '설정',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          ListTile(
            onTap: () => _handleLogout(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 8,
            ),
            title: const Text(
              '로그아웃',
              style: TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            trailing: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
