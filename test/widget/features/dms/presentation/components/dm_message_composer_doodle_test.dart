import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _MockSecureStorageService extends Mock implements SecureStorageService {}

Widget _composer() {
  final storage = _MockSecureStorageService();
  when(() => storage.readData(any())).thenAnswer((_) async => null);
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      dmDraftStoreProvider.overrideWith(
        (ref) => DmDraftStore(storage, userId: 'u', orgId: 'o'),
      ),
    ],
    child: buildTestMaterialApp(
      Scaffold(
        body: DmMessageComposer(recipientName: 'Ada', channelId: 'channel-1'),
      ),
    ),
  );
}

void main() {
  Future<void> openDoodle(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_composer());
    await tester.pump();
    // The doodle button sits in the More actions tray with Attach file.
    await tester.tap(find.byTooltip('More actions'));
    await tester.pump();
    await tester.tap(find.byTooltip('Draw a doodle'));
    await tester.pumpAndSettle();
  }

  testWidgets('the toolbar opens the doodle canvas', (tester) async {
    await openDoodle(tester);

    expect(find.byType(DoodleDialog), findsOneWidget);
  });

  testWidgets('closing the canvas attaches nothing', (tester) async {
    await openDoodle(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(DoodleDialog), findsNothing);
    expect(find.byType(AttachmentPreviewBar), findsNothing);
  });

  testWidgets('attaching adds one Doodle.png and focuses the text field', (
    tester,
  ) async {
    await openDoodle(tester);
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('doodle-canvas'))),
      const Offset(60, 30),
    );
    await tester.pump();

    await tester.tap(find.text('Attach to message'));
    // Export and the temp-file write are real async work.
    for (var i = 0; i < 30; i++) {
      if (find.byType(AttachmentPreviewBar).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }

    final bar = tester.widget<AttachmentPreviewBar>(
      find.byType(AttachmentPreviewBar),
    );
    expect(bar.files, hasLength(1));
    expect(bar.files.single.name, 'Doodle.png');
    expect(bar.files.single.mimeType, 'image/png');
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
  });
}
