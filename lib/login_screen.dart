// login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './services/auth_service.dart';
import 'models/main_bottom_nav.dart';
import 'models/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AppLinks _appLinks = AppLinks();

  StreamSubscription? _sub;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _listenAppLinks();
    _listenAuthChanges();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  void _listenAppLinks() {
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) async {
      if (uri != null &&
          uri.scheme == 'petlendar' &&
          uri.host == 'login-callback') {
        // OAuth 완료 후에도 onAuthStateChange로 처리됨
      }
    });
  }

  void _listenAuthChanges() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        widget.onLoginSuccess?.call();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainBottomNav()),
          );
        }
      }

      if (event == AuthChangeEvent.signedOut) {
        // 로그아웃 처리 필요 시 여기에 작성 가능
      }
    });
  }

  // 이메일 로그인 (최신 Supabase v2 대응)
  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("아이디(이메일)와 비밀번호 모두 입력해주세요")),
      );
      return;
    }

    final error = await AuthService.signInWithEmail(email, password);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  // 구글 로그인
  Future<void> _handleGoogleLogin() async {
    try {
      await AuthService.signInWithGoogle();
    } catch (e) {
      debugPrint("구글 로그인 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("구글 로그인 중 오류 발생")),
        );
      }
    }
  }

  // 카카오 로그인
  Future<void> _handleKakaoLogin() async {
    try {
      await AuthService.signInWithKakao();
    } catch (e) {
      debugPrint("카카오 로그인 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("카카오 로그인 중 오류 발생")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 140),
            Image.asset(
              'assets/src/petlendar.png',
              width: 200,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
              child: SizedBox(
                width: 300,
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '아이디(이메일)',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
              child: SizedBox(
                width: 300,
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '비밀번호',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  child: const Text("회원가입 | ",
                  style: TextStyle(
                    fontSize: 16
                  ),),
                ),

                GestureDetector(
                  onTap: () {},
                  child: const Text("아이디 찾기 | ",
                  style: TextStyle(
                    fontSize: 16
                  ),),
                ),

                GestureDetector(
                  onTap: () {},
                  child: const Text("비밀번호 찾기",
                  style: TextStyle(
                    fontSize: 16
                  ),),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleEmailLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 230, 230, 230),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text(
                  "로그인",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Material(
              color: Colors.transparent,
              child: Ink.image(
                image: const AssetImage('assets/src/googleLoginBtn.png'),
                width: 300,
                height: 44,
                fit: BoxFit.cover,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _handleGoogleLogin,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: Ink.image(
                image: const AssetImage('assets/src/kakaoLoginBtn.png'),
                width: 300,
                height: 44,
                fit: BoxFit.cover,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _handleKakaoLogin,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                widget.onLoginSuccess?.call();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainBottomNav()),
                  );
                }
              },
              child: const Text("개발자 로그인"),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
