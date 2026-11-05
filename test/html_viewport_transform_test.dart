// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:not3/logic/html_viewport_transform.dart';
import 'package:not3/models/page.dart';

void main() {
  const document = Size(1191, 3000);
  const viewport = Size(595.5, 800);

  test('fit-to-width maps the document top-left to the viewport top-left', () {
    const transform = HtmlViewportTransform(
      documentSize: document,
      viewportSize: viewport,
      visibleCssWidth: 1191,
      pageOffset: Offset.zero,
    );

    expect(transform.scale, 0.5);
    expect(transform.viewportToWorld(Offset.zero), const Offset(-595.5, -1500));
    expect(transform.maxPageLeft, 0);
    expect(transform.maxPageTop, 1400);
  });

  test('scroll and pinch zoom keep screen points in document coordinates', () {
    const transform = HtmlViewportTransform(
      documentSize: document,
      viewportSize: viewport,
      visibleCssWidth: 595.5,
      pageOffset: Offset(100, 700),
    );

    expect(transform.scale, 1);
    expect(transform.viewportToWorld(Offset.zero), const Offset(-495.5, -800));
    expect(transform.maxPageLeft, 595.5);
    expect(transform.maxPageTop, 2200);
  });

  test('HTML metadata is bounded and owns the matching finite template', () {
    final page = Page.fromJson({
      'id': 'page',
      'name': 'HTML',
      'strokes': const [],
      'images': const [],
      'template': const {
        'type': 'custom',
        'customWidth': -1,
        'customHeight': -1,
      },
      'htmlContent': const {
        'sourcePath': 'html/note/source.html',
        'logicalWidth': -1,
        'contentHeight': double.infinity,
      },
    });

    expect(page.htmlContent!.logicalWidth, 1191);
    expect(page.htmlContent!.contentHeight, 1684);
    expect(page.template.sheetSize, const Size(1191, 1684));
    expect(page.template.isFinite, isTrue);
  });
}
