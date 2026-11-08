import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

import '../../../../../helpers/helpers.dart';

class MockDmRepository extends Mock implements DmRepository {}

class _FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );
}

class _FakePeopleRepository implements PeopleRepository {
  _FakePeopleRepository({this.fail = false, this.extra = const []});

  final bool fail;
  final List<OrgMember> extra;
  final searches = <String>[];

  static const _everyone = [
    OrgMember(
      id: 'u-1',
      name: 'Ada Lovelace',
      email: 'ada@zedu.test',
      phone: '+234 800',
      online: true,
    ),
    OrgMember(id: 'u-2', name: 'Grace Hopper', email: 'grace@zedu.test'),
  ];

  @override
  Future<Result<MembersPage>> fetchMembers({
    required String orgId,
    int page = 1,
    String search = '',
  }) async {
    searches.add(search);
    if (fail) return const Failure(ApiFailure(message: 'offline'));
    final members = [..._everyone, ...extra]
        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return Success(
      MembersPage(
        members: members,
        totalPages: search.isEmpty ? 2 : 1,
        totalItems: search.isEmpty ? 60 : members.length,
      ),
    );
  }
}

Future<MockDmRepository> _pump(
  WidgetTester tester,
  _FakePeopleRepository people,
) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dms = MockDmRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workspaceProvider.overrideWith(_FakeWorkspaceNotifier.new),
        peopleRepositoryProvider.overrideWithValue(people),
        dmRepositoryProvider.overrideWithValue(dms),
      ],
      child: buildTestMaterialApp(
        const Scaffold(
          body: Row(
            children: [
              PeopleSidebar(),
              Expanded(child: PeopleView()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return dms;
}

void main() {
  testWidgets('lists the members in the sidebar and as cards', (tester) async {
    await _pump(tester, _FakePeopleRepository());

    expect(find.text('People'), findsOneWidget);
    expect(find.text('Invite People'), findsOneWidget);
    expect(find.text('New Chat'), findsOneWidget);
    expect(find.text('Channels'), findsNothing);
    // Each member is in the sidebar and on a card.
    expect(find.text('Ada Lovelace'), findsNWidgets(2));
    expect(find.text('ada@zedu.test'), findsOneWidget);
    expect(find.text('+234 800'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Showing 2 of 60 members'), findsOneWidget);
    // In the sidebar and under the cards.
    expect(find.text('Load more'), findsNWidgets(2));
  });

  testWidgets('searching for people asks the server', (tester) async {
    final people = _FakePeopleRepository();
    await _pump(tester, people);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search for people').last,
      'grace',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(people.searches, contains('grace'));
    expect(find.text('Showing 1 of 1 member'), findsOneWidget);
    // One search for the whole tab: the sidebar filters too.
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(find.text('Grace Hopper'), findsNWidgets(2));
  });

  testWidgets('the sidebar search filters the grid and fills its box', (
    tester,
  ) async {
    final people = _FakePeopleRepository();
    await _pump(tester, people);

    final boxes = find.widgetWithText(TextField, 'Search for people');
    expect(boxes, findsNWidgets(2));
    expect(find.text('Find a conversation'), findsNothing);

    await tester.enterText(boxes.first, 'ada');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Showing 1 of 1 member'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsNothing);
    expect(find.text('Ada Lovelace'), findsNWidgets(2));
    // Both boxes show the search in force.
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.map((f) => f.controller!.text), everyElement('ada'));
    // One request per search, not one per box.
    expect(people.searches.where((s) => s == 'ada'), hasLength(1));

    await tester.tap(find.byTooltip('Clear search').last);
    await tester.pumpAndSettle();
    expect(find.text('Showing 2 of 60 members'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsNWidgets(2));
  });

  testWidgets('a search with no match says so', (tester) async {
    await _pump(tester, _FakePeopleRepository());

    await tester.enterText(
      find.widgetWithText(TextField, 'Search for people').last,
      'zzz',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No members found matching your search.'), findsOneWidget);
  });

  testWidgets('clicking a member opens the DM with them', (tester) async {
    final dms = await _pump(tester, _FakePeopleRepository());
    when(
      () => dms.openConversation(orgId: 'org-1', participantId: 'u-2'),
    ).thenAnswer((_) async => (channelId: 'c-2', participantId: 'u-2'));

    await tester.tap(find.text('Grace Hopper').first);
    await tester.pumpAndSettle();

    verify(
      () => dms.openConversation(orgId: 'org-1', participantId: 'u-2'),
    ).called(1);
  });

  testWidgets('shows a retry when members fail to load', (tester) async {
    await _pump(tester, _FakePeopleRepository(fail: true));

    expect(find.text('Could not load people'), findsOneWidget);
    expect(find.text('Could not load members.'), findsOneWidget);
    expect(find.text('Retry'), findsNWidgets(2));
  });

  testWidgets('a deactivated member reads Deactivated and opens no DM', (
    tester,
  ) async {
    final dms = await _pump(
      tester,
      _FakePeopleRepository(
        extra: const [
          OrgMember(
            id: 'u-3',
            name: 'Alan Turing',
            email: 'alan@zedu.test',
            online: true,
            deactivated: true,
          ),
        ],
      ),
    );

    // Ada is the only Online member; Alan is marked Deactivated, not Online.
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Deactivated'), findsOneWidget);

    await tester.tap(find.text('Alan Turing').last);
    await tester.pump();
    expect(find.text("Alan Turing's account is deactivated."), findsOneWidget);
    await tester.tap(find.text('Alan Turing').first);
    await tester.pump();

    verifyNever(
      () => dms.openConversation(
        orgId: any(named: 'orgId'),
        participantId: any(named: 'participantId'),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
