import 'package:zedu/core/core.dart';
import 'package:zedu/features/dms/presentation/components/composer/composer.dart';

import '../../../../../../helpers/helpers.dart';

void main() {
  Future<List<int>> pumpBar(WidgetTester tester) async {
    final removed = <int>[];
    await tester.pumpWidget(
      buildTestMaterialApp(
        Scaffold(
          body: AttachmentPreviewBar(
            files: [XFile('first.pdf'), XFile('second.pdf')],
            onRemove: removed.add,
            colors: AppPalette.light,
          ),
        ),
      ),
    );
    return removed;
  }

  testWidgets('remove button has a tooltip and a click cursor', (tester) async {
    await pumpBar(tester);

    final button = find.byTooltip('Remove attachment');
    expect(button, findsNWidgets(2));

    final cursors = tester
        .widgetList<MouseRegion>(
          find.descendant(of: button.first, matching: find.byType(MouseRegion)),
        )
        .map((region) => region.cursor);
    expect(cursors, contains(SystemMouseCursors.click));
  });

  testWidgets('remove button can be clicked across its 24x24 target', (
    tester,
  ) async {
    final removed = await pumpBar(tester);

    final button = find.byTooltip('Remove attachment').first;
    expect(tester.getSize(button), const Size(24, 24));

    final corners = tester.getRect(button).deflate(1);
    for (final corner in [
      corners.topLeft,
      corners.topRight,
      corners.bottomLeft,
      corners.bottomRight,
    ]) {
      await tester.tapAt(corner);
    }

    expect(removed, [0, 0, 0, 0]);
  });

  group('thumbnails', () {
    Future<void> pumpFiles(WidgetTester tester, List<XFile> files) async {
      await tester.pumpWidget(
        buildTestMaterialApp(
          Scaffold(
            body: AttachmentPreviewBar(
              files: files,
              onRemove: (_) {},
              colors: AppPalette.light,
            ),
          ),
        ),
      );
    }

    Future<void> settleDecoding(WidgetTester tester) async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    test('detects images by name or MIME type', () {
      expect(isImageAttachment(XFile('/a/photo.JPG')), isTrue);
      expect(
        isImageAttachment(XFile.fromData(Uint8List(0), name: 'clip')),
        isFalse,
      );
      expect(
        isImageAttachment(
          XFile.fromData(Uint8List(0), name: 'clip', mimeType: 'image/png'),
        ),
        isTrue,
      );
      expect(isImageAttachment(XFile('/a/report.pdf')), isFalse);
    });

    testWidgets('shows an image for a drawn PNG and an icon for a document', (
      tester,
    ) async {
      final png = await tester.runAsync(
        () => exportDoodlePng(const [], canvasSize: const Size(600, 450)),
      );

      await pumpFiles(tester, [
        XFile.fromData(png!, name: 'Doodle.png', mimeType: 'image/png'),
        XFile('report.pdf'),
      ]);
      await settleDecoding(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('a picked image file is shown with Image.file', (tester) async {
      await pumpFiles(tester, [XFile('/tmp/photo.png', name: 'photo.png')]);

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).imageProvider, isA<FileImage>());
    });

    testWidgets('an image that cannot be decoded falls back to the icon', (
      tester,
    ) async {
      await pumpFiles(tester, [
        XFile.fromData(
          Uint8List.fromList([1, 2, 3, 4]),
          name: 'broken.png',
          mimeType: 'image/png',
        ),
      ]);
      await settleDecoding(tester);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.insert_drive_file_rounded), findsOneWidget);
    });
  });
}
