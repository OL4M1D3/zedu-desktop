import 'dart:ui' as ui;

import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  DoodleController drawTwo() {
    final controller = DoodleController();
    controller
      ..startStroke(const Offset(1, 1), color: Colors.black, width: 3)
      ..extendStroke(const Offset(5, 5))
      ..startStroke(const Offset(10, 10), color: Colors.red, width: 6);
    return controller;
  }

  group('DoodleController', () {
    test('records strokes and extends the last one', () {
      final controller = drawTwo();

      expect(controller.strokes, hasLength(2));
      expect(controller.strokes.first.points, [
        const Offset(1, 1),
        const Offset(5, 5),
      ]);
      expect(controller.isEmpty, isFalse);
    });

    test('undo steps back one stroke at a time and redo restores it', () {
      final controller = drawTwo();

      controller.undo();
      expect(controller.strokes, hasLength(1));
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.strokes, hasLength(2));
      expect(controller.strokes.last.color, Colors.red);
    });

    test('a new stroke drops the redo history', () {
      final controller = drawTwo()..undo();

      controller.startStroke(const Offset(2, 2), color: Colors.blue, width: 3);

      expect(controller.canRedo, isFalse);
    });

    test('clear empties the canvas and every edit bumps the revision', () {
      final controller = drawTwo();
      final before = controller.revision;

      controller.clear();

      expect(controller.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
      expect(controller.revision, greaterThan(before));
    });

    test('strokes are immutable', () {
      final controller = drawTwo();

      expect(
        () => controller.strokes.add(
          const DoodleStroke(points: [], color: Colors.black, width: 1),
        ),
        throwsUnsupportedError,
      );
    });
  });

  test('DoodlePainter repaints only when the revision changes', () {
    const painter = DoodlePainter(strokes: [], revision: 1);

    expect(
      painter.shouldRepaint(const DoodlePainter(strokes: [], revision: 1)),
      isFalse,
    );
    expect(
      painter.shouldRepaint(const DoodlePainter(strokes: [], revision: 0)),
      isTrue,
    );
  });

  testWidgets('exports a 1200x900 PNG', (tester) async {
    final controller = drawTwo();

    final png = await tester.runAsync(
      () =>
          exportDoodlePng(controller.strokes, canvasSize: const Size(600, 450)),
    );

    expect(png!.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });
    expect(image!.width, 1200);
    expect(image.height, 900);
  });
}
