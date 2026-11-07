import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';
import '../../../../../helpers/helpers.dart';

// Fake notifier that avoids GetIt/locator setup while remaining type-compatible
// with authNotifierProvider (which is NotifierProvider<AuthNotifier, AuthState>).
class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

Widget buildResetPasswordViewUnderTest() {
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => FakeAuthNotifier())],
    child: const MaterialApp(
      home: ResetPasswordView(email: 'test@example.com'),
    ),
  );
}

/// The six code boxes, in order.
Finder codeBox(int index) => find.byType(TextFormField).at(index);

List<String> codeDigits(WidgetTester tester) => [
  for (var i = 0; i < 6; i++)
    tester.widget<TextFormField>(codeBox(i)).controller!.text,
];

bool hasFocus(WidgetTester tester, int index) {
  final editable = find.descendant(
    of: codeBox(index),
    matching: find.byType(EditableText),
  );
  return tester.widget<EditableText>(editable).focusNode.hasFocus;
}

void main() {
  group('ResetPasswordView countdown timer', () {
    testWidgets('ticks the resend countdown', (tester) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());

      await tester.pump(const Duration(seconds: 1));

      expect(
        find.textContaining('after 4:59', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('does not call setState after the view is unmounted', (
      tester,
    ) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());
      // The timer ticks one second after the view was built.
      await tester.pump(const Duration(seconds: 1));

      // Leave the view (any navigation away unmounts it) and let the polling
      // timer fire again afterwards; the periodic callback must bail out
      // instead of crashing with "setState() called after dispose()".
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith(() => FakeAuthNotifier()),
          ],
          child: const MaterialApp(home: Scaffold(body: SizedBox())),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
    });
  });

  group('ResetPasswordView code boxes', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildResetPasswordViewUnderTest());
      await tester.pump();
    }

    testWidgets('pasting a 6-digit code into the first box fills all six', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(codeBox(0), '123456');
      await tester.pump();

      expect(codeDigits(tester), ['1', '2', '3', '4', '5', '6']);
      expect(hasFocus(tester, 5), isTrue);
    });

    testWidgets('pasting into a later box fills from that box on', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(codeBox(2), '9876');
      await tester.pump();

      expect(codeDigits(tester), ['', '', '9', '8', '7', '6']);
    });

    testWidgets('a pasted code with spaces or dashes keeps only its digits', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(codeBox(0), '12-34 56');
      await tester.pump();

      expect(codeDigits(tester), ['1', '2', '3', '4', '5', '6']);
    });

    testWidgets('a longer paste is cut to the boxes left', (tester) async {
      await pump(tester);

      await tester.enterText(codeBox(3), '12345678');
      await tester.pump();

      expect(codeDigits(tester), ['', '', '', '1', '2', '3']);
    });

    testWidgets('typing one digit still moves to the next box', (tester) async {
      await pump(tester);

      await tester.enterText(codeBox(0), '4');
      await tester.pump();

      expect(codeDigits(tester), ['4', '', '', '', '', '']);
      expect(hasFocus(tester, 1), isTrue);
    });

    testWidgets('typing into a filled box replaces its digit', (tester) async {
      await pump(tester);
      await tester.enterText(codeBox(0), '4');
      await tester.pump();

      // The field holds '4' with the cursor after it; typing 7 gives '47'.
      await tester.enterText(codeBox(0), '47');
      await tester.pump();

      expect(codeDigits(tester), ['7', '', '', '', '', '']);
      expect(hasFocus(tester, 1), isTrue);
    });

    testWidgets('pasting a full code into a filled box drops its old digit', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(codeBox(0), '7');
      await tester.pump();

      // Flutter puts the paste after the old 7, so the field gets '7123456'.
      await tester.enterText(codeBox(0), '7123456');
      await tester.pump();

      expect(codeDigits(tester), ['1', '2', '3', '4', '5', '6']);
      expect(hasFocus(tester, 5), isTrue);
    });

    testWidgets('a paste landing before the old digit also drops it', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(codeBox(0), '7');
      await tester.pump();

      await tester.tap(codeBox(0));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '1234567',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();

      expect(codeDigits(tester), ['1', '2', '3', '4', '5', '6']);
    });

    testWidgets('focusing a filled box selects its digit', (tester) async {
      await pump(tester);
      await tester.enterText(codeBox(0), '7');
      await tester.pump();

      await tester.tap(codeBox(0));
      await tester.pump();

      final field = tester.widget<TextFormField>(codeBox(0));
      expect(
        field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
    });

    testWidgets('pasting two digits into an empty box fills two boxes', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(codeBox(0), '12');
      await tester.pump();

      expect(codeDigits(tester), ['1', '2', '', '', '', '']);
      expect(hasFocus(tester, 2), isTrue);
    });

    testWidgets('clearing a box moves back to the previous one', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(codeBox(0), '4');
      await tester.enterText(codeBox(1), '5');
      await tester.pump();

      await tester.enterText(codeBox(1), '');
      await tester.pump();

      expect(codeDigits(tester), ['4', '', '', '', '', '']);
      expect(hasFocus(tester, 0), isTrue);
    });
  });

  group('ResetPasswordView code boxes', () {
    List<String> codeDigits(WidgetTester tester) => tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .take(6)
        .map((field) => field.controller!.text)
        .toList();

    testWidgets(
      'Backspace walks back through the boxes and clears each digit',
      (tester) async {
        await tester.pumpWidget(buildResetPasswordViewUnderTest());
        final boxes = find.byType(TextFormField);
        await tester.enterText(boxes.at(0), '1');
        await tester.enterText(boxes.at(1), '2');
        await tester.enterText(boxes.at(2), '3');
        expect(codeDigits(tester), ['1', '2', '3', '', '', '']);

        // Focus now sits on the empty fourth box.
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.pump();
        }

        expect(codeDigits(tester), ['', '', '', '', '', '']);
      },
    );

    testWidgets('Backspace in the first empty box does nothing', (
      tester,
    ) async {
      await tester.pumpWidget(buildResetPasswordViewUnderTest());
      await tester.tap(find.byType(TextFormField).at(0));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(codeDigits(tester), ['', '', '', '', '', '']);
      expect(tester.takeException(), isNull);
    });
  });
}
