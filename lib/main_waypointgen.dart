import 'package:flutter/material.dart';
import 'package:xml/xml.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MainApp());
}

Future<List<Rect>> extractRectsFromSvg(String assetPath) async {
  final svgString = await rootBundle.loadString(assetPath);
  final document = XmlDocument.parse(svgString);
  final rectElements = document.findAllElements('rect');

  return rectElements.map((element) {
    final x = double.tryParse(element.getAttribute('x') ?? '0') ?? 0;
    final y = double.tryParse(element.getAttribute('y') ?? '0') ?? 0;
    final width = double.tryParse(element.getAttribute('width') ?? '0') ?? 0;
    final height = double.tryParse(element.getAttribute('height') ?? '0') ?? 0;
    return Rect.fromLTWH(x, y, width, height);
  }).toList();
}

class WayPoint {
  Offset offset;
  bool isValid;

  WayPoint(this.offset, {this.isValid = true});
}


class NavPainter extends CustomPainter {
  final List<Rect> rects;
  final Offset? clickedPosition;



  NavPainter(this.rects, this.clickedPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final rect in rects) {
      canvas.drawRect(rect, paint);
    }

    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    const double gap = 5;

    List<WayPoint> dots = [];

    for (double x = 0; x < 830; x += gap) {
      for (double y = 0; y < 402; y += gap) {
        bool isInsideRect =
            rects.any((rect) => rect.deflate(-1).contains(Offset(x, y)));
        if (!isInsideRect) {
          final dot = WayPoint(Offset(x, y));
          dots.add(dot);
        }
      }
    }

    List<WayPoint> wayPoints = [];


    for (var dot in dots) {
      if (dot.isValid) {
        bool isValidDot(WayPoint dot, double depth) {
          List<Offset> offsets = [];
          for (double dx = -depth; dx <= depth; dx += gap) {
            for (double dy = -depth; dy <= depth; dy += gap) {
              if (!(dx == 0 && dy == 0)) {
                offsets.add(Offset(dot.offset.dx + dx, dot.offset.dy + dy));
              }
            }
          }
          for (var offset in offsets) {
            var existingDot = dots.firstWhere(
              (wayPoint) => wayPoint.offset == offset,
              orElse: () =>
                  WayPoint(const Offset(-12.5, -12.5), isValid: false),
            );
            if (existingDot.offset != const Offset(-12.5, -12.5)) {
              existingDot.isValid = false;
            } else {
              return false;
            }
          }
          return true;
        }

        if (isValidDot(dot, 2 * gap)) {
          wayPoints.add(dot);
            canvas.drawCircle(dot.offset, 2, dotPaint);
        }
      }
    }
    if (clickedPosition != null) {
      WayPoint? nearestDot;
      double minDistance = double.infinity;

      for (var dot in wayPoints) {
        final distance = (dot.offset - clickedPosition!).distance;
        if (distance < minDistance) {
          minDistance = distance;
          nearestDot = dot;
        }
      }

      final highlightPaint = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.fill;

      if (nearestDot != null) {
        canvas.drawCircle(nearestDot.offset, 4, highlightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Allow repaint when rects change
  }
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  List<Rect> rects = [];
  Offset? clickedPosition;

  @override
  void initState() {
    super.initState();
    loadSvgData();
  }

  Future<void> loadSvgData() async {
    final loadedRects = await extractRectsFromSvg('assets/floor.svg');
    setState(() {
      rects = loadedRects;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      clickedPosition = details.localPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTapDown: _handleTapDown,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red,
                      width: 2.0,
                    ),
                  ),
                  width: 830,
                  height: 402,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        painter: NavPainter(rects, clickedPosition),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}