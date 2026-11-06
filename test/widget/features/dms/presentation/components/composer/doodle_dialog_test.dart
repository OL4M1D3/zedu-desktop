import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  late Future<Uint8List?> result;

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showDoodleDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> draw(WidgetTester tester) async {
    final canvas = find.byKey(const ValueKey('doodle-canvas'));
    await tester.dragFrom(tester.getCenter(canvas), const Offset(80, 40));
    await tester.pump();
  }

  DoodlePainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byKey(const ValueKey('doodle-canvas')),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as DoodlePainter;

  FilledButton attachButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('Attach is disabled until something is drawn', (tester) async {
    await openDialog(tester);
    expect(attachButton(tester).onPressed, isNull);

    await draw(tester);

    expect(painter(tester).strokes, hasLength(1));
    expect(attachButton(tester).onPressed, isNotNull);
  });

  testWidgets('undo, redo and clear edit the strokes', (tester) async {
    await openDialog(tester);
    await draw(tester);
    await draw(tester);

    await tester.tap(find.byTooltip('Undo (Ctrl+Z)'));
    await tester.pump();
    expect(painter(tester).strokes, hasLength(1));

    await tester.tap(find.byTooltip('Redo (Ctrl+Shift+Z)'));
    await tester.pump();
    expect(painter(tester).strokes, hasLength(2));

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(painter(tester).strokes, isEmpty);
  });

  testWidgets('Ctrl+Z undoes and Ctrl+Shift+Z redoes', (tester) async {
    await openDialog(tester);
    await draw(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(painter(tester).strokes, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(painter(tester).strokes, hasLength(1));
  });

  testWidgets('the eraser and pen settings apply to new strokes', (
    tester,
  ) async {
    await openDialog(tester);
    await tester.tap(find.byTooltip('Thick'));
    await tester.tap(find.byTooltip('Eraser'));
    await tester.pump();

    await draw(tester);

    final stroke = painter(tester).strokes.single;
    expect(stroke.isEraser, isTrue);
    expect(stroke.width, doodleStrokeWidths.last * 2);
  });

  testWidgets('Escape closes without attaching', (tester) async {
    await openDialog(tester);
    await draw(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(DoodleDialog), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('Attach returns the PNG bytes', (tester) async {
    await openDialog(tester);
    await draw(tester);

    await tester.tap(find.text('Attach to message'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();

    final png = await result;
    expect(png, isNotNull);
    expect(png!.sublist(0, 4), [137, 80, 78, 71]);
    expect(find.byType(DoodleDialog), findsNothing);
  });
}
