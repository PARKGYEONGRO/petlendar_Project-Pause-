// import 부분은 그대로
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_verify_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();
  final _phoneController = TextEditingController(); // 1. 전화번호 컨트롤러 추가

  bool _isEmailValid = false;
  bool _isEmailUnique = true;
  bool _isCheckingEmail = false;
  bool _passwordsMatch = false;
  bool _hasUpperLower = false;
  bool _hasSpecialChar = false;
  bool _hasMinLength = false;
  String? _existingDisplayName;

  final _emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");
  final _upperLowerRegex = RegExp(r'(?=.*[a-z])(?=.*[A-Z])');
  final _specialCharRegex = RegExp(r'(?=.*[!@#$%^&*(),.?":{}|<>])');

  // 2. _allFieldsValid에 전화번호 포함
  bool get _allFieldsValid =>
      _isEmailValid &&
      _isEmailUnique &&
      _passwordsMatch &&
      _hasUpperLower &&
      _hasSpecialChar &&
      _hasMinLength &&
      _nameController.text.isNotEmpty &&
      _birthController.text.isNotEmpty &&
      _phoneController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => _checkEmailFormat(_emailController.text.trim()));
    _passwordController.addListener(_checkPasswordRules);
    _passwordController.addListener(_checkPasswords);
    _confirmPasswordController.addListener(_checkPasswords);
  }

  void _checkPasswords() {
    setState(() {
      _passwordsMatch =
          _passwordController.text == _confirmPasswordController.text &&
              _passwordController.text.isNotEmpty;
    });
  }

  void _checkPasswordRules() {
    final pw = _passwordController.text;
    setState(() {
      _hasUpperLower = _upperLowerRegex.hasMatch(pw);
      _hasSpecialChar = _specialCharRegex.hasMatch(pw);
      _hasMinLength = pw.length >= 8;
    });
  }

  Future<void> _checkEmailFormat(String email) async {
    final isValid = _emailRegex.hasMatch(email);
    setState(() {
      _isEmailValid = isValid;
      _existingDisplayName = null;
      _isEmailUnique = true;
    });

    if (!isValid || email.isEmpty) return;

    setState(() => _isCheckingEmail = true);
    try {
      final res = await http.post(
        Uri.parse(
            'https://tpaszbxerpnwrxuxarlv.supabase.co/functions/v1/database-access'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRwYXN6YnhlcnBud3J4dXhhcmx2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDY3NTAsImV4cCI6MjA3MzE4Mjc1MH0.CPJqL0ax1k27O9H5Bz4lw9d1qhoZSIJmDINJq5-Kj8U',
          },
        body: jsonEncode({'action': 'check_email', 'email': email}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
        final isDuplicate = data['isDuplicate'] ?? false;
        final displayName = data['displayName'];

        if (mounted) {
          setState(() {
            _isEmailUnique = !isDuplicate;
            _existingDisplayName = displayName;
          });
        }
      } else {
        setState(() => _isEmailUnique = true);
      }
    } catch (_) {
      setState(() => _isEmailUnique = true);
    } finally {
      if (mounted) setState(() => _isCheckingEmail = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1971),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _signup() async {
    if (!_allFieldsValid) return;

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        data: {
          'display_name': _nameController.text,
          'birth': _birthController.text,
          'phone': _phoneController.text, // 3. 전화번호 추가
        },
        emailRedirectTo: 'petlendar://signup-callback',
      );

      if (response.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerifyScreen(
              email: _emailController.text,
              password: _passwordController.text,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("회원가입 실패: $e")),
        );
      }
    }
  }

  Widget _passwordRuleRow(String text, bool passed) => Row(
        children: [
          Icon(passed ? Icons.check : Icons.close,
              color: passed ? Colors.green : Colors.red, size: 18),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _birthController.dispose();
    _phoneController.dispose(); // 4. dispose 추가
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showEmailError = !_isEmailUnique;
    final showDisplayName = _existingDisplayName != null;

    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // 이메일 입력
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: "이메일"),
                  ),
                ),
                const SizedBox(width: 8),
                if (_emailController.text.isNotEmpty)
                  _isCheckingEmail
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isEmailValid
                              ? (_isEmailUnique ? Icons.check_circle : Icons.cancel)
                              : Icons.close,
                          color: _isEmailValid
                              ? (_isEmailUnique ? Colors.green : Colors.red)
                              : Colors.red,
                        ),
              ],
            ),
            if (showEmailError)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text("중복된 이메일입니다.", style: TextStyle(color: Colors.red)),
              ),
            if (showDisplayName)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("기존 계정 Display Name: $_existingDisplayName",
                    style: const TextStyle(color: Colors.blue)),
              ),
            const SizedBox(height: 10),
            // 비밀번호 입력
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "비밀번호"),
            ),
            const SizedBox(height: 6),
            _passwordRuleRow("1. 대소문자 포함", _hasUpperLower),
            _passwordRuleRow("2. 특수문자 포함", _hasSpecialChar),
            _passwordRuleRow("3. 최소 8자 이상", _hasMinLength),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "비밀번호 확인",
                suffixIcon: _confirmPasswordController.text.isEmpty
                    ? null
                    : Icon(
                        _passwordsMatch ? Icons.check : Icons.close,
                        color: _passwordsMatch ? Colors.green : Colors.red,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            // 이름 입력
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "성함"),
            ),
            const SizedBox(height: 10),
            // 생년월일 입력
            TextField(
              controller: _birthController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "생년월일"),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 10),
            // 5. 전화번호 입력 UI 추가
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "전화번호"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _allFieldsValid ? _signup : null,
              child: const Text("회원가입"),
            ),
          ],
        ),
      ),
    );
  }
}
