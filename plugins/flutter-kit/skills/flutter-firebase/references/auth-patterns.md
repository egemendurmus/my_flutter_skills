# Firebase Auth desenleri

## Auth state provider — features/auth/data/repositories/auth_repository.dart

```dart
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signIn(String email, String password) => _guard(
        () => _auth.signInWithEmailAndPassword(email: email.trim(), password: password),
      );

  Future<void> register(String email, String password) => _guard(
        () => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password),
      );

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseAuthException catch (e) {
      throw ValidationException(authErrorMessage(e.code));
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    }
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepository(ref.watch(firebaseAuthProvider));

@Riverpod(keepAlive: true)
Stream<User?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();
```

> Basitlik için Auth'ta Service katmanı atlanmıştır: `FirebaseAuth` zaten ince bir SDK. Kullanıcı profili Firestore'da tutuluyorsa `UserProfileService` ayrı yazılır.

## Türkçe hata mesajları

```dart
String authErrorMessage(String code) => switch (code) {
      'invalid-email' => 'E-posta adresi geçersiz.',
      'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'E-posta veya şifre hatalı.',
      'email-already-in-use' => 'Bu e-posta ile kayıtlı bir hesap var.',
      'weak-password' => 'Şifre çok zayıf (en az 6 karakter).',
      'too-many-requests' => 'Çok fazla deneme yapıldı, biraz sonra tekrar deneyin.',
      'network-request-failed' => 'İnternet bağlantınızı kontrol edin.',
      'requires-recent-login' => 'Bu işlem için tekrar giriş yapmanız gerekiyor.',
      _ => 'Giriş yapılamadı, tekrar deneyin.',
    };
```

## go_router redirect (giriş koruması)

Router'ı auth değişince **yeniden oluşturma**; `refreshListenable` ile sadece redirect'i tetikle.

```dart
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authListenable = ValueNotifier<AsyncValue<User?>>(const AsyncLoading());
  ref
    ..onDispose(authListenable.dispose)
    ..listen(
      authStateProvider,
      (_, next) => authListenable.value = next,
      fireImmediately: true,
    );

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = authListenable.value;
      if (auth.isLoading && !auth.hasValue) return Routes.splash;

      final loggedIn = auth.value != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == Routes.login || loc == Routes.register;

      if (!loggedIn) return onAuthPage ? null : Routes.login;
      if (onAuthPage || loc == Routes.splash) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
```

Giriş başarılı olunca ekranda `context.go(...)` çağırmaya gerek yok: auth state değişir, redirect kullanıcıyı ana sayfaya taşır.

Aynı desen REST API tabanlı auth için de geçerli: `authStateProvider` yerine token durumunu tutan bir `@Riverpod(keepAlive: true)` Notifier kullanılır.

## Login ViewModel

`flutter-architecture/references/riverpod-patterns.md` §4'teki `LoginViewModel` örneği doğrudan kullanılabilir; `authRepositoryProvider.signIn` çağırır, hata mesajı `AppException.message`'dan gelir.

## Çıkışta temizlik

`signOut` sonrası kullanıcıya özel provider'lar `authStateProvider`'ı `watch` ettiği için otomatik yenilenir. Kullanıcıya özel lokal veri (shared_preferences, cache) varsa `signOut` içinde temizle.
