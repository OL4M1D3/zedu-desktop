import 'dart:ui' as ui;

import 'package:zedu/core/core.dart';

/// The doodle is exported on white so it reads the same in any chat bubble.
const doodleBackground = Colors.white;

/// The exported PNG is always this size, whatever size the canvas was drawn at.
const doodleExportSize = Size(1200, 900);

/// One freehand line. Eraser strokes paint in [doodleBackground].
@immutable
class DoodleStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  const DoodleStroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  DoodleStroke addPoint(Offset point) => DoodleStroke(
    points: [...points, point],
    color: color,
    width: width,
    isEraser: isEraser,
  );
}

/// Holds the strokes with undo and redo. [revision] changes on every edit so
/// the painter knows when to repaint.
class DoodleController extends ChangeNotifier {
  final List<DoodleStroke> _strokes = [];
  final List<DoodleStroke> _undone = [];
  int _revision = 0;

  List<DoodleStroke> get strokes => List.unmodifiable(_strokes);
  int get revision => _revision;
  bool get isEmpty => _strokes.isEmpty;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;

  void startStroke(
    Offset point, {
    required Color color,
    required double width,
    bool isEraser = false,
  }) {
    _strokes.add(
      DoodleStroke(
        points: [point],
        color: color,
        width: width,
        isEraser: isEraser,
      ),
    );
    _undone.clear();
    _changed();
  }

  void extendStroke(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes[_strokes.length - 1] = _strokes.last.addPoint(point);
    _changed();
  }

  void undo() {
    if (!canUndo) return;
    _undone.add(_strokes.removeLast());
    _changed();
  }

  void redo() {
    if (!canRedo) return;
    _strokes.add(_undone.removeLast());
    _changed();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    _undone.clear();
    _changed();
  }

  void _changed() {
    _revision++;
    notifyListeners();
  }
}

/// Paints [strokes] on a [doodleBackground] fill, scaled by [scale].
void paintDoodle(
  Canvas canvas,
  Size size,
  List<DoodleStroke> strokes, {
  double scale = 1,
}) {
  canvas.drawRect(Offset.zero & size, Paint()..color = doodleBackground);
  for (final stroke in strokes) {
    final paint = Paint()
      ..color = stroke.isEraser ? doodleBackground : stroke.color
      ..strokeWidth = stroke.width * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final points = stroke.points.map((p) => p * scale).toList();
    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        stroke.width * scale / 2,
        paint..style = PaintingStyle.fill,
      );
      continue;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }
}

class DoodlePainter extends CustomPainter {
  final List<DoodleStroke> strokes;
  final int revision;

  const DoodlePainter({required this.strokes, required this.revision});

  @override
  void paint(Canvas canvas, Size size) => paintDoodle(canvas, size, strokes);

  @override
  bool shouldRepaint(DoodlePainter oldDelegate) =>
      oldDelegate.revision != revision;
}

/// Renders [strokes], drawn on a canvas of [canvasSize], into a
/// [doodleExportSize] PNG. Works without a widget tree, so it is testable
/// headless.
Future<Uint8List> exportDoodlePng(
  List<DoodleStroke> strokes, {
  required Size canvasSize,
}) async {
  final scale = doodleExportSize.width / canvasSize.width;
  final recorder = ui.PictureRecorder();
  paintDoodle(Canvas(recorder), doodleExportSize, strokes, scale: scale);
  final image = await recorder.endRecording().toImage(
    doodleExportSize.width.toInt(),
    doodleExportSize.height.toInt(),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
