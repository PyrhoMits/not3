// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:not3/services/pdf_import_coordinator.dart';
import 'package:not3/services/pdf_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const picked = PdfPickedFile(
    path: '/source/Lecture.PDF',
    displayName: 'Lecture.PDF',
  );

  test('cancelled picker does not render', () async {
    var rendered = false;
    final coordinator = PdfImportCoordinator(
      supported: true,
      picker: () async => null,
      renderer: (_) {
        rendered = true;
        return const Stream.empty();
      },
    );

    expect(await coordinator.pickAndImport(), isNull);
    expect(rendered, isFalse);
  });

  test('returns ordered one-page and multi-page results', () async {
    PdfImportCoordinator coordinator(List<PdfPageImage> pages) =>
        PdfImportCoordinator(
          supported: true,
          picker: () async => picked,
          renderer: (_) => Stream.fromIterable(pages),
        );

    final one = await coordinator([
      const PdfPageImage('/out/1.png', 100, 200),
    ]).pickAndImport();
    expect(one!.filename, 'Lecture.PDF');
    expect(one.suggestedTitle, 'Lecture');
    expect(one.pages.single.path, '/out/1.png');

    final many = await coordinator([
      const PdfPageImage('/out/1.png', 100, 200),
      const PdfPageImage('/out/2.png', 300, 400),
      const PdfPageImage('/out/3.png', 500, 600),
    ]).pickAndImport();
    expect(many!.pages.map((page) => page.path), [
      '/out/1.png',
      '/out/2.png',
      '/out/3.png',
    ]);
  });

  test('zero-page render returns a defined failure', () async {
    final coordinator = PdfImportCoordinator(
      supported: true,
      picker: () async => picked,
      renderer: (_) => const Stream.empty(),
    );

    await expectLater(
      coordinator.pickAndImport(),
      throwsA(
        isA<PdfImportException>().having(
          (error) => error.kind,
          'kind',
          PdfImportFailureKind.empty,
        ),
      ),
    );
  });

  test('renderer failure removes pages produced by the attempt', () async {
    final deleted = <String>[];
    Stream<PdfPageImage> render(String _) async* {
      yield const PdfPageImage('/out/partial-1.png', 100, 200);
      yield const PdfPageImage('/out/partial-2.png', 100, 200);
      throw StateError('damaged PDF');
    }

    final coordinator = PdfImportCoordinator(
      supported: true,
      picker: () async => picked,
      renderer: render,
      deleteImportedFile: (path) async => deleted.add(path),
    );

    await expectLater(
      coordinator.pickAndImport(),
      throwsA(
        isA<PdfImportException>().having(
          (error) => error.kind,
          'kind',
          PdfImportFailureKind.render,
        ),
      ),
    );
    expect(deleted, ['/out/partial-1.png', '/out/partial-2.png']);
  });

  test('progress reports monotonically increasing page counts', () async {
    final progress = <int>[];
    final coordinator = PdfImportCoordinator(
      supported: true,
      picker: () async => picked,
      renderer: (_) => Stream.fromIterable(const [
        PdfPageImage('/out/1.png', 100, 200),
        PdfPageImage('/out/2.png', 100, 200),
        PdfPageImage('/out/3.png', 100, 200),
      ]),
    );

    await coordinator.pickAndImport(onProgress: progress.add);

    expect(progress, [1, 2, 3]);
  });

  test('unsupported platforms fail before opening the picker', () async {
    var pickedFile = false;
    final coordinator = PdfImportCoordinator(
      supported: false,
      picker: () async {
        pickedFile = true;
        return picked;
      },
    );

    await expectLater(
      coordinator.pickAndImport(),
      throwsA(
        isA<PdfImportException>().having(
          (error) => error.kind,
          'kind',
          PdfImportFailureKind.unsupported,
        ),
      ),
    );
    expect(pickedFile, isFalse);
  });
}
