import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _vibration = true;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibration = prefs.getBool('vibration') ?? true;
      _notifications = prefs.getBool('notifications') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration', _vibration);
    await prefs.setBool('notifications', _notifications);
  }

  void _handleVibrationChanged(bool value) async {
    setState(() => _vibration = value);
    _saveSettings();

    if (_vibration && await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 250);
    }

    Fluttertoast.showToast(
      msg: "진동 ${_vibration ? '켜짐' : '꺼짐'}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color.fromARGB(178, 0, 0, 0),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _handleNotificationChanged(bool value) {
    setState(() => _notifications = value);
    _saveSettings();

    Fluttertoast.showToast(
      msg: "알림 ${_notifications ? '허용' : '차단'}",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: const Color.fromARGB(178, 0, 0, 0),
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.signOutAll();

      Fluttertoast.showToast(
        msg: "로그아웃 완료",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color.fromARGB(178, 0, 0, 0),
        textColor: Colors.white,
        fontSize: 16.0,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('로그아웃 처리 중 오류: $e');
      Fluttertoast.showToast(
        msg: "로그아웃 중 오류 발생",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: const Color.fromARGB(178, 255, 0, 0),
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _launchInquiryURL() async {
    final Uri url = Uri.parse("https://forms.gle/znZT6oSJJ9Au2Ro1A");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      Fluttertoast.showToast(msg: "사이트를 열 수 없습니다.");
    }
  }

  /// provider별 커스텀 아이콘 (Google 4색 / Kakao / Email)
  Widget _getProviderIcon(String provider, {double size = 28}) {
    switch (provider) {
      case 'google':
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 4색 원형 조각
              Transform.rotate(
                angle: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: size * 0.25, height: size * 0.5, color: Colors.blue),
                    Container(width: size * 0.25, height: size * 0.5, color: Colors.red),
                    Container(width: size * 0.25, height: size * 0.5, color: Colors.yellow),
                    Container(width: size * 0.25, height: size * 0.5, color: Colors.green),
                  ],
                ),
              ),
              const Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );

      case 'kakao':
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.yellow,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text(
              'K',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );

      case 'email':
        return Icon(Icons.email, color: Colors.blue, size: size);

      default:
        return Icon(Icons.person, color: Colors.grey, size: size);
    }
  }

  /// 이메일 기준으로 중복 provider 합치기
  List<Map<String, dynamic>> _mergeIdentities(List<UserIdentity> identities) {
    final Map<String, Set<String>> merged = {};

    for (var identity in identities) {
      final email = identity.identityData?['email'] ?? '이메일 없음';
      final provider = identity.provider;

      merged.putIfAbsent(email, () => {});
      merged[email]!.add(provider);
    }

    return merged.entries
        .map((e) => {
              'email': e.key,
              'providers': e.value.toList(),
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final identities = user?.identities ?? [];
    final mergedIdentities = _mergeIdentities(identities);

    return Scaffold(
      appBar: AppBar(title: const Text('설정'), centerTitle: true),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '내 계정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 20, thickness: 1),

              // 계정 리스트
              if (mergedIdentities.isNotEmpty)
                ...mergedIdentities.map((item) {
                  final email = item['email'] as String;
                  final providers = item['providers'] as List<String>;

                  return ListTile(
                    leading: const Icon(Icons.account_circle, size: 32),
                    title: Text("이메일: $email"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: providers
                          .map((p) => Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _getProviderIcon(p, size: 24),
                              ))
                          .toList(),
                    ),
                  );
                })
              else
                const ListTile(
                  title: Text("로그인된 계정이 없습니다."),
                ),
              const SizedBox(height: 30),

              const Text(
                '앱 설정',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 20, thickness: 1),
              SwitchListTile(
                title: const Text('진동'),
                value: _vibration,
                onChanged: _handleVibrationChanged,
              ),
              SwitchListTile(
                title: const Text('알림'),
                value: _notifications,
                onChanged: _handleNotificationChanged,
              ),
              const SizedBox(height: 30),

              const Text(
                  '문의',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20, thickness: 1),
                ListTile(
                  title: const Text('기능 문의'),
                  onTap: () {
                    debugPrint('기능 문의 클릭됨');
                  },
                ),
                ListTile(
                  title: const Text('오류 및 직접 문의하기'),
                  onTap: _launchInquiryURL,
                ),
              const SizedBox(height: 30),


              const Text(
                '정보',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 20, thickness: 1),
              ListTile(
                title: const Text('공지사항'),
                onTap: () {
                  debugPrint('공지사항 클릭됨');
                },
              ),
              const SizedBox(height: 30),

              const Text(
                '앱 정보',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(height: 20, thickness: 1),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('버전'),
                subtitle: Text('1.0.0'),
              ),
              const SizedBox(height: 60),
            ],
          ),

          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: _handleLogout,
              child: const Text(
                '로그아웃',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
