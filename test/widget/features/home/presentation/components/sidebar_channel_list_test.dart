import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

Channel _channel(
  String name, {
  bool archived = false,
  bool isPrivate = false,
  bool hasAccess = true,
  String org = 'org-1',
}) => Channel(
  id: 'channel-$name',
  name: name,
  description: '',
  organisationId: org,
  ownerId: 'user-1',
  archived: archived,
  isPrivate: isPrivate,
  hasAccess: hasAccess,
);

class FakeChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general'),
    _channel('random'),
    _channel('old', archived: true),
    _channel('left-channel', hasAccess: false),
  ];
}

class FakeMixedChannelNotifier extends ChannelNotifier {
  @override
  Future<List<Channel>> build() async => [
    _channel('general'),
    _channel('secret', isPrivate: true),
    _channel('random'),
    _channel('leads', isPrivate: true),
  ];
}

/// Holds one selected workspace, and can switch to another.
class FakeWorkspaceNotifier extends WorkspaceNotifier {
  @override
  WorkspaceState build() => const WorkspaceState(
    selectedWorkspace: Workspace(id: 'org-1', name: 'Workspace A', avatar: ''),
  );

  void switchTo(String id) {
    state = WorkspaceState(
      selectedWorkspace: Workspace(id: id, name: 'Workspace $id', avatar: ''),
    );
  }
}

/// Lists workspace A's channels until [switched] is set. After that, the next
/// build loads workspace B's channels, or fails when [failB] is set. It does
/// not watch the workspace, so it stays stale until it is invalidated, like
/// the real provider in the moment after a switch.
class SwitchingChannelNotifier extends ChannelNotifier {
  static bool switched = false;
  static bool failB = false;

  @override
  Future<List<Channel>> build() async {
    if (!switched) return [_channel('a-only')];
    if (failB) throw const ApiFailure(message: 'Could not load channels');
    return [_channel('b-only', org: 'org-2')];
  }
}

void main() {
  group('SidebarChannelList', () {
    late ProviderContainer container;

    Future<void> pumpList(
      WidgetTester tester, {
      required ChannelNotifier Function() channels,
    }) async {
      container = ProviderContainer(
        overrides: [
          channelProvider.overrideWith(channels),
          workspaceProvider.overrideWith(FakeWorkspaceNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: buildTestMaterialApp(
            const Scaffold(body: SidebarChannelList()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    FakeWorkspaceNotifier workspace() =>
        container.read(workspaceProvider.notifier) as FakeWorkspaceNotifier;

    testWidgets('lists the active channels and hides archived ones', (
      tester,
    ) async {
      await pumpList(tester, channels: FakeChannelNotifier.new);

      expect(find.text('general'), findsOneWidget);
      expect(find.text('random'), findsOneWidget);
      expect(find.text('old'), findsNothing);
      expect(find.text('left-channel'), findsNothing);
    });

    group('after a workspace switch', () {
      setUp(() {
        SwitchingChannelNotifier.switched = false;
        SwitchingChannelNotifier.failB = false;
      });

      testWidgets('hides the old channels until the new ones arrive', (
        tester,
      ) async {
        await pumpList(tester, channels: SwitchingChannelNotifier.new);
        expect(find.text('a-only'), findsOneWidget);

        // The workspace changes before the channel list has reloaded.
        workspace().switchTo('org-2');
        await tester.pumpAndSettle();
        expect(find.text('a-only'), findsNothing);

        SwitchingChannelNotifier.switched = true;
        container.invalidate(channelProvider);
        await tester.pumpAndSettle();

        expect(find.text('b-only'), findsOneWidget);
        expect(find.text('a-only'), findsNothing);
      });

      testWidgets('shows an error and retries after the new load fails', (
        tester,
      ) async {
        await pumpList(tester, channels: SwitchingChannelNotifier.new);
        expect(find.text('a-only'), findsOneWidget);

        workspace().switchTo('org-2');
        SwitchingChannelNotifier.switched = true;
        SwitchingChannelNotifier.failB = true;
        container.invalidate(channelProvider);
        await tester.pumpAndSettle();

        expect(find.text('a-only'), findsNothing);
        expect(find.text('b-only'), findsNothing);
        expect(find.text('Unable to load channels.'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        SwitchingChannelNotifier.failB = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.text('Unable to load channels.'), findsNothing);
        expect(find.text('Retry'), findsNothing);
        expect(find.text('b-only'), findsOneWidget);
        expect(find.text('a-only'), findsNothing);
      });
    });

    group('highlights the open channel', () {
      bool isHighlighted(WidgetTester tester, String name) {
        final ink = tester.widget<Ink>(
          find.ancestor(of: find.text(name), matching: find.byType(Ink)),
        );
        return (ink.decoration! as BoxDecoration).color != Colors.transparent;
      }

      testWidgets('and moves it when another channel opens', (tester) async {
        await pumpList(tester, channels: FakeChannelNotifier.new);
        expect(isHighlighted(tester, 'general'), isTrue);
        expect(isHighlighted(tester, 'random'), isFalse);

        await tester.tap(find.text('random'));
        await tester.pump();

        expect(isHighlighted(tester, 'general'), isFalse);
        expect(isHighlighted(tester, 'random'), isTrue);
      });

      testWidgets('but not a channel named like the open group DM', (
        tester,
      ) async {
        await pumpList(tester, channels: FakeChannelNotifier.new);

        container.read(activeChatProvider.notifier).selectGroupDm('random');
        await tester.pump();

        expect(isHighlighted(tester, 'general'), isFalse);
        expect(isHighlighted(tester, 'random'), isFalse);
      });

      testWidgets(
        'renders accent indicator bar and distinct hash mark on active channel',
        (tester) async {
          await pumpList(tester, channels: FakeChannelNotifier.new);

          // Active channel has an accent DecoratedBox indicator bar
          final generalItem = find.ancestor(
            of: find.text('general'),
            matching: find.byType(Ink),
          );
          final indicator = find.descendant(
            of: generalItem,
            matching: find.byType(DecoratedBox),
          );
          expect(indicator, findsOneWidget);

          // Inactive channel does not have an indicator bar
          final randomItem = find.ancestor(
            of: find.text('random'),
            matching: find.byType(Ink),
          );
          final randomIndicator = find.descendant(
            of: randomItem,
            matching: find.byType(DecoratedBox),
          );
          expect(randomIndicator, findsNothing);
        },
      );
    });

    testWidgets('tapping a channel opens it', (tester) async {
      await pumpList(tester, channels: FakeChannelNotifier.new);
      expect(container.read(activeChatProvider).id, 'general');

      await tester.tap(find.text('random'));
      await tester.pump();

      expect(
        container.read(activeChatProvider),
        const ActiveChatState(
          type: ActiveChatType.channel,
          id: 'random',
          channelId: 'channel-random',
        ),
      );
    });

    group('private channels', () {
      Finder heading() => find.text('Private');

      double top(WidgetTester tester, String text) =>
          tester.getTopLeft(find.text(text)).dy;

      Finder lockBeside(String name) => find.descendant(
        of: find.ancestor(of: find.text(name), matching: find.byType(Row)),
        matching: find.byIcon(Icons.lock_outline),
      );

      testWidgets('are listed under a Private heading with a lock', (
        tester,
      ) async {
        await pumpList(tester, channels: FakeMixedChannelNotifier.new);

        expect(heading(), findsOneWidget);
        for (final name in ['secret', 'leads']) {
          expect(top(tester, name), greaterThan(top(tester, 'Private')));
          expect(lockBeside(name), findsOneWidget);
        }
        for (final name in ['general', 'random']) {
          expect(top(tester, name), lessThan(top(tester, 'Private')));
          expect(lockBeside(name), findsNothing);
        }
      });

      testWidgets('collapse and expand from the heading', (tester) async {
        await pumpList(tester, channels: FakeMixedChannelNotifier.new);

        await tester.tap(heading());
        await tester.pump();
        expect(find.text('secret'), findsNothing);
        expect(find.text('leads'), findsNothing);
        expect(find.text('general'), findsOneWidget);
        expect(find.text('random'), findsOneWidget);

        await tester.tap(heading());
        await tester.pump();
        expect(find.text('secret'), findsOneWidget);
        expect(find.text('leads'), findsOneWidget);
      });

      testWidgets('open the same channel as before when selected', (
        tester,
      ) async {
        await pumpList(tester, channels: FakeMixedChannelNotifier.new);

        await tester.tap(find.text('secret'));
        await tester.pump();

        expect(
          container.read(activeChatProvider),
          const ActiveChatState(
            type: ActiveChatType.channel,
            id: 'secret',
            channelId: 'channel-secret',
          ),
        );
      });

      testWidgets('no Private heading when every channel is public', (
        tester,
      ) async {
        await pumpList(tester, channels: FakeChannelNotifier.new);

        expect(heading(), findsNothing);
      });
    });
  });
}
