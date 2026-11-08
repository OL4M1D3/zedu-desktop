import 'package:flutter_test/flutter_test.dart';
import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

void main() {
  group('UserProfileRemoteDataSourceImpl.inviteMember role payload', () {
    test('sends the resolved role id as role_id and the org id', () async {
      final captured = await _captureInvite(
        invitations: const [],
        roleName: null,
      );

      final body = captured.data as Map<String, dynamic>;
      expect(body['role_id'], equals('role-manager'));
      expect(body['org_id'], equals('org-1'));
      expect(body['emails'], equals(['invitee@example.com']));
    });

    test('prefers the backend role_name when the response echoes it', () async {
      final member = await _invite(
        invitations: const [
          {
            'id': 'invite-1',
            'email': 'invitee@example.com',
            'role_name': 'Manager',
            'sent_at': '2026-01-01',
          },
        ],
      );

      expect(member.role, equals('Manager'));
      expect(
        member.role,
        isNot(equals('role-manager')),
        reason: 'the backend role name wins over the raw UUID',
      );
    });

    test(
      'falls back to the requested role id when no role_name is returned',
      () async {
        final member = await _invite(
          invitations: const [
            {
              'id': 'invite-1',
              'email': 'invitee@example.com',
              'sent_at': '2026-01-01',
            },
          ],
        );

        expect(member.role, equals('role-manager'));
      },
    );
  });

  group('UserProfileRemoteDataSourceImpl.inviteMember response', () {
    test('a created response without an invitations list is a sent invite, '
        'as zedu-be answers', () async {
      final member = await _inviteWith({'errors': <String>[]});

      expect(member.email, 'invitee@example.com');
      expect(member.status, TeamMemberStatus.pending);
    });

    test('fails when the response names the email as not invited', () async {
      await expectLater(
        _inviteWith({
          'errors': ['could not generate token for invitee@example.com: boom'],
        }),
        throwsA(isA<ApiFailure>()),
      );
    });
  });

  group(
    'UserProfileRemoteDataSourceImpl.inviteMember Referer (Ziki #2708)',
    () {
      test(
        'sends the web app address so the emailed link has a host',
        () async {
          final captured = await _captureInvite(
            invitations: const [],
            roleName: null,
          );

          // zedu-be builds the link as Referer + 'accept_org_invitation?...'.
          expect(captured.headers['Referer'], 'https://example.com/');
        },
      );

      test('uses WEB_APP_URL when it is set', () async {
        final captured = await _captureInvite(
          invitations: const [],
          roleName: null,
          webAppUrl: 'https://app.zedu.chat',
        );

        expect(captured.headers['Referer'], 'https://app.zedu.chat/');
      });
    },
  );
}

Future<RequestOptions> _captureInvite({
  required List<dynamic> invitations,
  required String? roleName,
  String webAppUrl = '',
}) async {
  final config = AppConfig(
    apiBaseUrl: 'https://api.example.com/api/v1/',
    usesMockData: false,
    webAppUrl: webAppUrl,
  );
  final dio = Dio();
  RequestOptions? captured;
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        captured = options;
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {
              'data': {'invitations': invitations},
            },
          ),
        );
      },
    ),
  );

  final dataSource = UserProfileRemoteDataSourceImpl(
    config: config,
    apiBaseService: ApiBaseService(config: config, dio: dio),
  );

  await dataSource.inviteMember(
    email: 'invitee@example.com',
    role: 'role-manager',
    orgId: 'org-1',
  );

  return captured!;
}

Future<TeamMember> _invite({required List<dynamic> invitations}) =>
    _inviteWith({'invitations': invitations});

Future<TeamMember> _inviteWith(Map<String, dynamic> data) async {
  final config = AppConfig(
    apiBaseUrl: 'https://api.example.com/api/v1/',
    usesMockData: false,
  );
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Map<String, dynamic>>(
            requestOptions: options,
            data: {'data': data},
          ),
        );
      },
    ),
  );

  final dataSource = UserProfileRemoteDataSourceImpl(
    config: config,
    apiBaseService: ApiBaseService(config: config, dio: dio),
  );

  return dataSource.inviteMember(
    email: 'invitee@example.com',
    role: 'role-manager',
    orgId: 'org-1',
  );
}
