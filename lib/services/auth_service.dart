import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// 이메일 회원가입
  static Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required String phone,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'phone': phone, // 전화번호 필수 입력
        },
        emailRedirectTo: 'petlendar://signup-callback',
      );
      if (response.user != null) return null;
      return "회원가입 실패: 알 수 없는 오류";
    } on AuthException catch (e) {
      debugPrint("이메일 회원가입 AuthException: ${e.message}");
      return e.message;
    } catch (e) {
      debugPrint("이메일 회원가입 에러: $e");
      return "회원가입 중 오류가 발생했습니다";
    }
  }

  /// 이메일 로그인
  static Future<String?> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session != null) return null;
      return "로그인 실패: 알 수 없는 오류";
    } on AuthException catch (e) {
      debugPrint("이메일 로그인 AuthException: ${e.message}");
      return e.message;
    } catch (e) {
      debugPrint("이메일 로그인 에러: $e");
      return "로그인 중 오류가 발생했습니다";
    }
  }

  /// 구글 로그인
  static Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'petlendar://login-callback',
      );
    } catch (e) {
      debugPrint("구글 로그인 에러: $e");
      rethrow;
    }
  }

  /// 카카오 로그인
  static Future<void> signInWithKakao() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.kakao,
        redirectTo: 'petlendar://login-callback',
      );
    } catch (e) {
      debugPrint("카카오 로그인 에러: $e");
      rethrow;
    }
  }

  /// 전체 로그아웃
  static Future<void> signOutAll() async {
    try {
      await _supabase.auth.signOut();

      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      try {
        await UserApi.instance.logout();
      } catch (e) {
        debugPrint("카카오 로그아웃 실패: $e");
      }

      debugPrint("모든 로그아웃 완료");
    } catch (e) {
      debugPrint("로그아웃 전체 에러: $e");
      rethrow;
    }
  }
}
