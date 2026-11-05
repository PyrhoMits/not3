// SPDX-License-Identifier: GPL-3.0-or-later
part of 'canvas_controller.dart';

enum ShapeEditOperation { anchor, rotate, move }

/// Point editing for a single recognized shape.
mixin _CanvasShapeEditing on _CanvasCore {
  String? _activeShapeEditId;
  ShapeEditOperation? _shapeEditOperation;
  Stroke? _shapeEditBefore;
  List<Offset> _shapeEditStartAnchors = const [];
  Offset _shapeEditStartPoint = Offset.zero;
  Offset _shapeEditCenter = Offset.zero;
  double _shapeEditStartAngle = 0;
  int? _shapeEditAnchorIndex;
  double? _shapeRotationDelta;

  Stroke? get activeShapeEditStroke {
    final id = _activeShapeEditId;
    if (id == null) return null;
    for (final stroke in page.strokes) {
      if (stroke.id == id && stroke.shapeType != null) return stroke;
    }
    return null;
  }

  List<Offset> get activeShapeAnchors {
    final stroke = activeShapeEditStroke;
    if (stroke == null) return const [];
    return stroke.shapeAnchors ??
        ShapeDetector.deriveAnchors(stroke) ??
        const [];
  }

  ShapeEditOperation? get shapeEditOperation => _shapeEditOperation;
  double? get shapeRotationDelta => _shapeRotationDelta;
  bool get isShapeEditGestureActive => _shapeEditOperation != null;

  ({List<Offset> anchors, Offset rotate, double radius})?
  get shapeEditingHandles {
    final anchors = activeShapeAnchors;
    if (anchors.isEmpty) return null;
    final bounds = polygonBounds(anchors);
    final radius = 9 / _scale;
    return (
      anchors: anchors,
      rotate: Offset(bounds.center.dx, bounds.bottom + 38 / _scale),
      radius: radius,
    );
  }

  void activateShapeEditing(Stroke stroke) {
    if (stroke.shapeType == null || _isLayerLocked(stroke.layerIndex)) return;
    _activeShapeEditId = stroke.id;
    _shapeRotationDelta = null;
    _notifyActiveOverlay();
    notifyListeners();
  }

  void clearShapeEditing() {
    if (_activeShapeEditId == null && _shapeEditOperation == null) return;
    _activeShapeEditId = null;
    _resetShapeEditGesture();
    _notifyActiveOverlay();
    notifyListeners();
  }

  /// Selects the topmost recognized shape at [worldPoint].
  bool selectShapeAt(Offset worldPoint) {
    for (final stroke in page.strokes.reversed) {
      if (stroke.shapeType == null ||
          !_isLayerVisible(stroke.layerIndex) ||
          _isLayerLocked(stroke.layerIndex)) {
        continue;
      }
      if (_shapeContains(stroke, worldPoint, 20 / _scale)) {
        activateShapeEditing(stroke);
        return true;
      }
    }
    return false;
  }

  /// Starts a handle, rotation, or body drag on the active shape.
  ///
  /// Returns false when the pointer is outside; in that case editing is
  /// dismissed and the caller should route the event to the current tool.
  bool beginShapeEditGesture(Offset worldPoint) {
    final stroke = activeShapeEditStroke;
    final handles = shapeEditingHandles;
    if (stroke == null || handles == null) {
      clearShapeEditing();
      return false;
    }
    final hitRadius = 22 / _scale;
    var nearestDistance = double.infinity;
    int? anchorIndex;
    for (var i = 0; i < handles.anchors.length; i++) {
      final distance = (worldPoint - handles.anchors[i]).distance;
      if (distance <= hitRadius && distance < nearestDistance) {
        nearestDistance = distance;
        anchorIndex = i;
      }
    }

    ShapeEditOperation? operation;
    if (anchorIndex != null) {
      operation = ShapeEditOperation.anchor;
    } else if ((worldPoint - handles.rotate).distance <= hitRadius) {
      operation = ShapeEditOperation.rotate;
    } else if (_shapeContains(stroke, worldPoint, hitRadius)) {
      operation = ShapeEditOperation.move;
    }
    if (operation == null) {
      clearShapeEditing();
      return false;
    }

    _shapeEditOperation = operation;
    _shapeEditBefore = stroke;
    _shapeEditStartAnchors = List<Offset>.from(handles.anchors);
    _shapeEditStartPoint = worldPoint;
    _shapeEditCenter = polygonBounds(handles.anchors).center;
    _shapeEditStartAngle = (worldPoint - _shapeEditCenter).direction;
    _shapeEditAnchorIndex = anchorIndex;
    _shapeRotationDelta = operation == ShapeEditOperation.rotate ? 0 : null;
    _notifyActiveOverlay();
    notifyListeners();
    return true;
  }

  void updateShapeEditGesture(Offset worldPoint) {
    final before = _shapeEditBefore;
    final operation = _shapeEditOperation;
    if (before == null || operation == null) return;
    var anchors = List<Offset>.from(_shapeEditStartAnchors);
    switch (operation) {
      case ShapeEditOperation.anchor:
        final index = _shapeEditAnchorIndex;
        if (index == null) return;
        if (before.shapeType == ShapeType.circle.name && anchors.length == 4) {
          anchors = _resizeEllipseAxis(anchors, index, worldPoint);
        } else {
          anchors[index] = worldPoint;
        }
      case ShapeEditOperation.rotate:
        final delta = _normalizedAngle(
          (worldPoint - _shapeEditCenter).direction - _shapeEditStartAngle,
        );
        _shapeRotationDelta = delta;
        anchors = [
          for (final anchor in anchors)
            _rotate(anchor, _shapeEditCenter, delta),
        ];
      case ShapeEditOperation.move:
        final delta = worldPoint - _shapeEditStartPoint;
        anchors = [for (final anchor in anchors) anchor + delta];
    }
    _replaceEditedShape(before, anchors);
  }

  void endShapeEditGesture() {
    final before = _shapeEditBefore;
    final current = activeShapeEditStroke;
    if (before != null && current != null && !identical(before, current)) {
      _undoStack.push(
        CanvasAction(strokesRemoved: [before], strokesAdded: [current]),
      );
      _resetShapeEditGesture();
      _touch();
      return;
    }
    _resetShapeEditGesture();
    _notifyActiveOverlay();
    notifyListeners();
  }

  void cancelShapeEditGesture() {
    final before = _shapeEditBefore;
    if (before != null) {
      final index = page.strokes.indexWhere((stroke) => stroke.id == before.id);
      if (index >= 0) page.strokes[index] = before;
      _touchLive();
    }
    _resetShapeEditGesture();
    _notifyActiveOverlay();
    notifyListeners();
  }

  List<Offset> _resizeEllipseAxis(
    List<Offset> anchors,
    int index,
    Offset worldPoint,
  ) {
    final oppositeIndex = (index + 2) % 4;
    final opposite = anchors[oppositeIndex];
    final originalAxis = anchors[index] - opposite;
    if (originalAxis.distance == 0) return anchors;
    final direction = originalAxis / originalAxis.distance;
    final pointerFromOpposite = worldPoint - opposite;
    final projectedLength = max(
      8 / _scale,
      pointerFromOpposite.dx * direction.dx +
          pointerFromOpposite.dy * direction.dy,
    );
    final oldCenter = (anchors[index] + opposite) / 2;
    anchors[index] = opposite + direction * projectedLength;
    final newCenter = (anchors[index] + opposite) / 2;
    final centerDelta = newCenter - oldCenter;
    anchors[(index + 1) % 4] += centerDelta;
    anchors[(index + 3) % 4] += centerDelta;
    return anchors;
  }

  void _replaceEditedShape(Stroke before, List<Offset> anchors) {
    final resolvedType = ShapeType.values.cast<ShapeType?>().firstWhere(
      (value) => value?.name == before.shapeType,
      orElse: () => null,
    );
    if (resolvedType == null) return;
    final points = ShapeDetector.pointsFromAnchors(resolvedType, anchors);
    if (points.isEmpty) return;
    final currentIndex = page.strokes.indexWhere(
      (stroke) => stroke.id == before.id,
    );
    if (currentIndex < 0) return;
    page.strokes[currentIndex] = before.copyWith(
      points: points,
      shapeAnchors: anchors,
    );
    _notifyActiveOverlay();
    _touchLive();
  }

  bool _shapeContains(Stroke stroke, Offset point, double tolerance) {
    if (stroke.shapeType == ShapeType.rectangle.name ||
        stroke.shapeType == ShapeType.triangle.name ||
        stroke.shapeType == ShapeType.circle.name) {
      final polygon = [for (final sample in stroke.points) sample.offset];
      if (polygon.length >= 3 && pointInPolygon(point, polygon)) return true;
    }
    return StrokeEngine.findStrokeAt(point, [stroke], maxDistance: tolerance) !=
        null;
  }

  Offset _rotate(Offset point, Offset center, double angle) {
    final relative = point - center;
    final cosA = cos(angle);
    final sinA = sin(angle);
    return center +
        Offset(
          relative.dx * cosA - relative.dy * sinA,
          relative.dx * sinA + relative.dy * cosA,
        );
  }

  double _normalizedAngle(double angle) {
    while (angle > pi) {
      angle -= 2 * pi;
    }
    while (angle < -pi) {
      angle += 2 * pi;
    }
    return angle;
  }

  void _resetShapeEditGesture() {
    _shapeEditOperation = null;
    _shapeEditBefore = null;
    _shapeEditStartAnchors = const [];
    _shapeEditAnchorIndex = null;
    _shapeRotationDelta = null;
  }
}
