import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class MockAppLinks extends Mock implements AppLinks {}

class FakeDeepLinkAuthNotifier extends AuthNotifier {
  FakeDeepLinkAuthNotifier({required this.user});

  final User user;

  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: user);
}

class FakeDeepLinkCreditsNotifier extends CreditsNotifier {
  FakeDeepLinkCreditsNotifier({this.verified = true});

  final bool verified;

  @override
  CreditsState build() => const CreditsState();

  @override
  Future<bool> verifyPayment({
    required String sessionId,
    required String orgId,
  }) async => verified;
}

User _user({String? currentOrg}) => User(
  id: 'u-1',
  firstName: 'Fawaz',
  lastName: 'Yusuff',
  email: 'fawaz@example.com',
  phone: '0800000000',
  username: 'foyusuff7',
  isVerified: true,
  isOnboarded: true,
  createdAt: DateTime(2026),
  currentOrg: currentOrg ?? 'org-1',
  currentOrganisationSlug: 'team-neo',
  avatarUrl: '',
  defaultAvatarUrl: '',
);

void main() {
  // The widgets reach the auth and workspace providers, which read AppConfig.
  setUp(() {
    if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
    locator.registerSingleton<AppConfig>(
      const AppConfig(apiBaseUrl: 'http://test', usesMockData: false),
    );
  });

  tearDown(() {
    if (locator.isRegistered<AppConfig>()) locator.unregister<AppConfig>();
  });

  group('CreditsPaymentDeepLinkListener', () {
    late MockAppLinks mockAppLinks;
    late StreamController<Uri> linkController;

    setUp(() {
      mockAppLinks = MockAppLinks();
      linkController = StreamController<Uri>.broadcast();
      when(
        () => mockAppLinks.uriLinkStream,
      ).thenAnswer((_) => linkController.stream);
    });

    tearDown(() async {
      await linkController.close();
    });

    Future<void> pumpPaymentLink(
      WidgetTester tester, {
      required String sessionId,
      required User user,
      required bool verified,
    }) async {
      // Mounts the listener where App.build mounts it: wrapping the router
      // from MaterialApp.router's builder, above the Navigator.
      final router = GoRouter(
        initialLocation: AppRouter.login,
        navigatorKey: AppRouter.navigatorKey,
        routes: [
          GoRoute(
            path: AppRouter.login,
            builder: (context, state) =>
                const Scaffold(body: Text('Login screen')),
          ),
          GoRoute(
            path: AppRouter.buyCredits,
            builder: (context, state) =>
                const Scaffold(body: Text('Credits screen')),
          ),
        ],
      );

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async =>
            Uri.parse('zedu://credits/payment-success?session_id=$sessionId'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(user: user),
            ),
            currentOrgIdProvider.overrideWithValue(''),
            creditsNotifierProvider.overrideWith(
              () => FakeDeepLinkCreditsNotifier(verified: verified),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => CreditsPaymentDeepLinkListener(
              appLinks: mockAppLinks,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a verified payment reaches the user', (tester) async {
      await pumpPaymentLink(
        tester,
        sessionId: 'cs-1',
        user: _user(),
        verified: true,
      );

      expect(find.text('Credits screen'), findsOneWidget);
      expect(find.text('AI credits purchased successfully!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    /// Opens a payment link and returns the (session, org) it was verified for.
    Future<(String?, String?)> verifyLink(
      WidgetTester tester, {
      required String selectedOrg,
    }) async {
      String? verifiedSession;
      String? verifiedOrg;

      final router = GoRouter(
        initialLocation: AppRouter.login,
        navigatorKey: AppRouter.navigatorKey,
        routes: [
          GoRoute(
            path: AppRouter.login,
            builder: (context, state) =>
                const Scaffold(body: Text('Login screen')),
          ),
          GoRoute(
            path: AppRouter.buyCredits,
            builder: (context, state) =>
                const Scaffold(body: Text('Credits screen')),
          ),
        ],
      );

      when(() => mockAppLinks.getInitialLink()).thenAnswer(
        (_) async =>
            Uri.parse('zedu://credits/payment-success?session_id=cs-2'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(
              () => FakeDeepLinkAuthNotifier(user: _user(currentOrg: 'org-9')),
            ),
            currentOrgIdProvider.overrideWithValue(selectedOrg),
            creditsNotifierProvider.overrideWith(
              () => _SpyCreditsNotifier(
                onVerify: (sessionId, orgId) {
                  verifiedSession = sessionId;
                  verifiedOrg = orgId;
                },
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => CreditsPaymentDeepLinkListener(
              appLinks: mockAppLinks,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      return (verifiedSession, verifiedOrg);
    }

    testWidgets('a payment link is verified against the selected workspace', (
      tester,
    ) async {
      final (session, org) = await verifyLink(tester, selectedOrg: 'org-ws');

      expect(session, 'cs-2');
      expect(org, 'org-ws');
    });

    testWidgets(
      'does not subscribe to uriLinkStream when unmounted while getting initial link',
      (tester) async {
        final completer = Completer<Uri?>();
        when(
          () => mockAppLinks.getInitialLink(),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith(
                () => FakeDeepLinkAuthNotifier(user: _user()),
              ),
            ],
            child: MaterialApp(
              home: CreditsPaymentDeepLinkListener(
                appLinks: mockAppLinks,
                child: const SizedBox(),
              ),
            ),
          ),
        );

        // Unmount the listener before initial link completes
        await tester.pumpWidget(const SizedBox());

        completer.complete(null);
        await tester.pump();

        expect(linkController.hasListener, isFalse);
      },
    );

    testWidgets('falls back to the sign-in org when no workspace is selected', (
      tester,
    ) async {
      final (session, org) = await verifyLink(tester, selectedOrg: '');

      expect(session, 'cs-2');
      expect(org, 'org-9');
    });

    testWidgets(
      'a payment link opened before sign-in is verified once a workspace is known',
      (tester) async {
        final verified = <(String, String)>[];
        when(() => mockAppLinks.getInitialLink()).thenAnswer(
          (_) async =>
              Uri.parse('zedu://credits/payment-success?session_id=cs-3'),
        );
        final router = GoRouter(
          initialLocation: AppRouter.login,
          navigatorKey: AppRouter.navigatorKey,
          routes: [
            GoRoute(
              path: AppRouter.login,
              builder: (context, state) =>
                  const Scaffold(body: Text('Login screen')),
            ),
            GoRoute(
              path: AppRouter.buyCredits,
              builder: (context, state) =>
                  const Scaffold(body: Text('Credits screen')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              creditsOrgIdProvider.overrideWith((ref) => ref.watch(_orgId)),
              creditsNotifierProvider.overrideWith(
                () => _SpyCreditsNotifier(
                  succeeds: true,
                  onVerify: (sessionId, orgId) =>
                      verified.add((sessionId, orgId)),
                ),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              builder: (context, child) => CreditsPaymentDeepLinkListener(
                appLinks: mockAppLinks,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        // Cold start: no workspace yet, so nothing can be verified.
        expect(verified, isEmpty);

        // Signing in makes the workspace known: the held link is verified.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(CreditsPaymentDeepLinkListener)),
        );
        container.read(_orgId.notifier).set('org-1');
        await tester.pump();
        await tester.pump();
        expect(verified, [('cs-3', 'org-1')]);

        // The same link again, or another workspace change, is not
        // verified twice.
        linkController.add(
          Uri.parse('zedu://credits/payment-success?session_id=cs-3'),
        );
        container.read(_orgId.notifier).set('org-2');
        await tester.pump();
        await tester.pump();
        expect(verified, [('cs-3', 'org-1')]);

        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  });
}

final _orgId = NotifierProvider<_OrgId, String>(_OrgId.new);

class _OrgId extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

class _SpyCreditsNotifier extends CreditsNotifier {
  _SpyCreditsNotifier({required this.onVerify, this.succeeds = false});

  final void Function(String sessionId, String orgId) onVerify;

  /// What [verifyPayment] reports. A failed verification may be retried when
  /// the link arrives again; a successful one never runs twice.
  final bool succeeds;

  @override
  CreditsState build() => const CreditsState();

  @override
  Future<bool> verifyPayment({
    required String sessionId,
    required String orgId,
  }) async {
    onVerify(sessionId, orgId);
    return succeeds;
  }
}
