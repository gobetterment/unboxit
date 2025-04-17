import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일과 비밀번호를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (response.user != null && mounted) {
        print('로그인 성공 - 사용자 ID: ${response.user!.id}');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on AuthException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인 오류: ${error.message}\n상태 코드: ${error.statusCode}'),
          backgroundColor: Colors.red,
        ),
      );
      print('로그인 오류 상세: $error');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('예상치 못한 오류: $error'),
          backgroundColor: Colors.red,
        ),
      );
      print('예상치 못한 오류 상세: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Google 로그인 실행
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Supabase에 Google 로그인
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: Provider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google 로그인 오류: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Apple 로그인 실행
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Supabase에 Apple 로그인
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: Provider.apple,
        idToken: credential.identityToken!,
      );

      if (response.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple 로그인 오류: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // 앱 타이틀
                const Text(
                  '꺼내보기',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                // 이메일 입력
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: '이메일',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                // 비밀번호 입력
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: '비밀번호',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 24),
                // 로그인 버튼
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_emailController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('이메일을 입력해주세요'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          try {
                            setState(() {
                              _isLoading = true;
                            });

                            await Supabase.instance.client.auth
                                .resetPasswordForEmail(
                              _emailController.text,
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('비밀번호 재설정 이메일이 발송되었습니다'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (error) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('오류가 발생했습니다: $error'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                  child: const Text(
                    '비밀번호 재설정',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '또는',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Google 로그인 버튼
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: Image.asset(
                    'assets/icon/google.png',
                    width: 24,
                    height: 24,
                  ),
                  label: const Text(
                    'Google로 계속하기',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Apple 로그인 버튼
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleAppleSignIn,
                  icon: const Icon(
                    Icons.apple,
                    size: 24,
                    color: Colors.black,
                  ),
                  label: const Text(
                    'Apple로 계속하기',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
