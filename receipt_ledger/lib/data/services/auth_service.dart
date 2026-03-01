import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 인증 상태
@immutable
class AuthState {
  final bool isSignedIn;
  final bool isLoading;
  final String? userEmail;
  final String? userName;
  final String? userPhotoUrl;
  final String? error;

  const AuthState({
    this.isSignedIn = false,
    this.isLoading = false,
    this.userEmail,
    this.userName,
    this.userPhotoUrl,
    this.error,
  });

  AuthState copyWith({
    bool? isSignedIn,
    bool? isLoading,
    String? userEmail,
    String? userName,
    String? userPhotoUrl,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isSignedIn: isSignedIn ?? this.isSignedIn,
      isLoading: isLoading ?? this.isLoading,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Google Sign-In 관리 서비스
class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  AuthNotifier() : super(const AuthState(isLoading: true));

  /// 앱 시작 시 자동 로그인 시도 (이전에 로그인한 적 있는 경우)
  Future<void> silentSignIn() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        state = AuthState(
          isSignedIn: true,
          isLoading: false,
          userEmail: account.email,
          userName: account.displayName,
          userPhotoUrl: account.photoUrl,
        );
      } else {
        state = state.copyWith(isSignedIn: false, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isSignedIn: false,
        isLoading: false,
        error: '자동 로그인 실패: $e',
      );
    }
  }

  /// Google 로그인
  Future<bool> signIn() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        state = AuthState(
          isSignedIn: true,
          isLoading: false,
          userEmail: account.email,
          userName: account.displayName,
          userPhotoUrl: account.photoUrl,
        );
        return true;
      } else {
        // 사용자가 로그인 취소
        state = state.copyWith(isSignedIn: false, isLoading: false);
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSignedIn: false,
        isLoading: false,
        error: '로그인 실패: $e',
      );
      return false;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(error: '로그아웃 실패: $e');
    }
  }
}

/// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// 로그인 여부 간편 Provider
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isSignedIn;
});

/// 사용자 이메일 간편 Provider (API 헤더에 사용)
final userEmailProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).userEmail;
});
