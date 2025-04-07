import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<StatefulWidget> createState() {
    return MainAppState();
  }
}

class Coordinate {
  final double x;
  final double y;

  Coordinate({required this.x, required this.y});
}

class Line {
  final Coordinate start;
  final Coordinate end;
  Line({required this.start, required this.end});
}

class MainAppState extends State<MainApp> {
  String text = "";
  Coordinate pos = Coordinate(x: 0, y: 0);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 20), // Add margin from top
              ElevatedButton(
                onPressed: () async {
                  startBLE();
                },
                child: const Text('Start Scanning'),
              ),
              ElevatedButton(
                onPressed: () async {
                  calcPosLine();
                },
                child: const Text('Start Positioning'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => SecondPage(
                              beaconCoordinates: beaconCoordinates,
                              distances: distances,
                              line: line,
                              probLine: probLine!,
                              currentPostion: currentPostion,
                            )),
                  );
                },
                child: const Text('Go to Second Page'),
              ),
              Text(text),
              Text('Position: ${currentPostion['x']} ${currentPostion['y']}'),
            ],
          ),
        ),
      ),
    ));
  }

  final regions = <Region>[
    Region(identifier: 'com.beacon'),
  ];

  // sender coordinates
  // in cm
  // final Map<String, Coordinate> beaconCoordinates = {
  //   '54C30B7D-6B88-4BB6-AEDA-A157C07476BA': Coordinate(x: 0, y: 150),
  //   'B1291BC1-5CC2-402E-854C-CBC111F67295': Coordinate(x: 0, y: 0),
  //   'A8A7DC3D-5EB1-4DE4-B020-62BD11DAC3FE': Coordinate(x: 200, y: 0),
  //   'BDB02063-BC84-4A7A-B9B4-A6FCD8691EC9': Coordinate(x: 0, y: 150),
  //   '9D90F6C9-CF5E-4222-80F7-177C080A0D4D': Coordinate(x: 0, y: 0),
  //   '4041FCF1-3C8B-4948-B096-0804CAF87341': Coordinate(x: 200, y: 0),
  // };

  final Map<String, Coordinate> beaconCoordinates = {
    '54C30B7D-6B88-4BB6-AEDA-A157C07476BA': Coordinate(x: 0, y: 0),
    'B1291BC1-5CC2-402E-854C-CBC111F67295': Coordinate(x: 0, y: 625),
    'A8A7DC3D-5EB1-4DE4-B020-62BD11DAC3FE': Coordinate(x: 750, y: 600),
    // 'BDB02063-BC84-4A7A-B9B4-A6FCD8691EC9': Coordinate(x: -100, y: 300),
  };

  // Aktuelle Distanzen zu Sender
  List<double> distances = [150, 180, 150];

  // Gang
  final Line line =
      Line(start: Coordinate(x: 375, y: 0), end: Coordinate(x: 375, y: 625));

  Line? probLine;

  List<Coordinate> calculateIntersectionPoints() {
    List<Coordinate> intersectionPoints = [];

    for (var entry in beaconCoordinates.entries) {
      Coordinate circleCenter = entry.value;
      double radius =
          distances[beaconCoordinates.keys.toList().indexOf(entry.key)];

      double a = 1;
      double b = -2 * circleCenter.y;
      num c = pow(circleCenter.y, 2) +
          pow(line.start.x - circleCenter.x, 2) -
          pow(radius, 2);
      double discriminant = b * b - 4 * a * c;

      if (discriminant >= 0) {
        double y1 = (-b + sqrt(discriminant)) / (2 * a);
        double y2 = (-b - sqrt(discriminant)) / (2 * a);
        if (y1 == y2) {
          intersectionPoints.add(Coordinate(x: line.start.x, y: y1));
        } else {
          intersectionPoints.add(Coordinate(x: line.start.x, y: y1));
          intersectionPoints.add(Coordinate(x: line.start.x, y: y2));
        }
      } else {
        double nearestY =
            circleCenter.y >= line.start.y && circleCenter.y <= line.end.y
                ? circleCenter.y
                : (circleCenter.y < line.start.y ? line.start.y : line.end.y);
        intersectionPoints.add(Coordinate(x: line.start.x, y: nearestY));
      }
    }

    return intersectionPoints;
  }

  void calcPosLine() {
    List<Coordinate> intersectionPoints = calculateIntersectionPoints();
    intersectionPoints.sort((a, b) => a.y.compareTo(b.y));

    Coordinate minPoint1 = intersectionPoints[0];
    Coordinate minPoint2 = intersectionPoints[1];
    double minDelta = (minPoint2.y - minPoint1.y).abs();

    for (int i = 1; i < intersectionPoints.length - 1; i++) {
      double delta =
          (intersectionPoints[i + 1].y - intersectionPoints[i].y).abs();
      if (delta < minDelta) {
        minDelta = delta;
        minPoint1 = intersectionPoints[i];
        minPoint2 = intersectionPoints[i + 1];
      }
    }
    probLine = Line(start: minPoint1, end: minPoint2);
  }

  Map<String, double> currentPostion = {};

  void calcPosition2() {
    List<Map<String, dynamic>> beacons = [];
    var entries = beaconCoordinates.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      var distance = distances[0];
      beacons.add({
        'x': entries[i].value.x,
        'y': entries[i].value.y,
        'distance': distance,
      });
    }

    currentPostion = multilaterate(beacons);
  }

  Map<String, double> multilaterate(List<Map<String, dynamic>> beacons) {
    int n = beacons.length;

    if (n < 3) {
      throw Exception("At least 3 beacons are required for trilateration");
    }

    // Matrices for least squares calculation
    List<List<double>> A = [];
    List<double> b = [];

    // Reference beacon (first beacon)
    double x1 = beacons[0]['x'],
        y1 = beacons[0]['y'],
        d1 = beacons[0]['distance'];

    for (int i = 1; i < n; i++) {
      double xi = beacons[i]['x'];
      double yi = beacons[i]['y'];
      double di = beacons[i]['distance'];

      // Fill A matrix
      A.add([2 * (xi - x1), 2 * (yi - y1)]);

      // Fill b vector
      b.add((pow(d1, 2) -
              pow(di, 2) -
              pow(x1, 2) +
              pow(xi, 2) -
              pow(y1, 2) +
              pow(yi, 2))
          .toDouble());
    }

    // Solve using least squares: p = (A^T * A)^-1 * A^T * b
    var AT = transposeMatrix(A);
    var ATA = multiplyMatrices(AT, A);
    var ATA_inv = invertMatrix(ATA);
    var ATb = multiplyMatrixVector(AT, b);
    var p = multiplyMatrixVector(ATA_inv, ATb);

    return {'x': p[0], 'y': p[1]};
  }

// Helper functions for matrix operations
  List<List<double>> transposeMatrix(List<List<double>> matrix) {
    int rows = matrix.length, cols = matrix[0].length;
    List<List<double>> transposed =
        List.generate(cols, (_) => List.filled(rows, 0.0));
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        transposed[j][i] = matrix[i][j];
      }
    }
    return transposed;
  }

  List<List<double>> multiplyMatrices(
      List<List<double>> A, List<List<double>> B) {
    int rowsA = A.length, colsA = A[0].length, colsB = B[0].length;
    List<List<double>> result =
        List.generate(rowsA, (_) => List.filled(colsB, 0.0));
    for (int i = 0; i < rowsA; i++) {
      for (int j = 0; j < colsB; j++) {
        for (int k = 0; k < colsA; k++) {
          result[i][j] += A[i][k] * B[k][j];
        }
      }
    }
    return result;
  }

  List<double> multiplyMatrixVector(List<List<double>> A, List<double> b) {
    int rows = A.length, cols = A[0].length;
    List<double> result = List.filled(rows, 0.0);
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        result[i] += A[i][j] * b[j];
      }
    }
    return result;
  }

  List<List<double>> invertMatrix(List<List<double>> matrix) {
    // Simple inversion for 2x2 matrices
    double a = matrix[0][0], b = matrix[0][1];
    double c = matrix[1][0], d = matrix[1][1];
    double det = a * d - b * c;
    if (det == 0) throw Exception("Matrix is not invertible");
    return [
      [d / det, -b / det],
      [-c / det, a / det]
    ];
  }

  void startBLE() async {
    try {
      await flutterBeacon.initializeAndCheckScanning;
      await Permission.bluetoothScan.request();
      await Permission.bluetoothAdvertise.request();
      await Permission.location.request();
      await Permission.bluetoothConnect.request();
      flutterBeacon.ranging(regions).listen((RangingResult result) {
        setState(() {
          text = '';

          text = result.beacons.toString();
          text = result.region.toString();
          text += '\n';
          text += result.beacons.toString();
          text += '\n';

          for (var x in result.beacons) {
            for (int i = 0; i < beaconCoordinates.keys.length; i++) {
              if (x.proximityUUID.toString() ==
                  beaconCoordinates.keys.elementAt(i)) {
                distances[i] = x.accuracy * 100;
                text += '\n d${i + 1}: ${x.accuracy * 100}';
              }
            }
          }

          calcPosLine();
        });
      });
    } on PlatformException catch (e) {
      print('@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ error: $e');
    }
  }
}

class SecondPage extends StatelessWidget {
  SecondPage(
      {super.key,
      required this.beaconCoordinates,
      required this.distances,
      required this.currentPostion,
      required this.line,
      required this.probLine});

  final List<double> distances;
  final Map<String, double> currentPostion;
  final Map<String, Coordinate> beaconCoordinates;
  final Line line;
  final Line probLine;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Page'),
      ),
      body: GridPainterWidget(
        beaconCoordinates: beaconCoordinates,
        distances: distances,
        currentPostion: currentPostion,
        line: line,
        probLine: probLine,
      ),
    );
  }
}

class GridPainterWidget extends StatefulWidget {
  const GridPainterWidget({
    super.key,
    required this.beaconCoordinates,
    required this.distances,
    required this.currentPostion,
    required this.line,
    required this.probLine,
  });

  final Map<String, Coordinate> beaconCoordinates;
  final List<double> distances;
  final Map<String, double> currentPostion;
  final Line line;
  final Line probLine;

  @override
  _GridPainterWidgetState createState() => _GridPainterWidgetState();
}

class _GridPainterWidgetState extends State<GridPainterWidget> {
  final List<Offset> _dots = [];
  final List<Offset> _circles = [];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: GridPainter(
        dots: _dots,
        circles: _circles,
        beaconCoordinates: widget.beaconCoordinates,
        distances: widget.distances,
        currentPostion: widget.currentPostion,
        line: widget.line,
        probLine: widget.probLine,
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final List<Offset> dots;
  final List<Offset> circles;
  final Map<String, Coordinate> beaconCoordinates;
  final List<double> distances;
  final Map<String, double> currentPostion;
  final Line line;
  final Line probLine;

  GridPainter({
    required this.dots,
    required this.circles,
    required this.beaconCoordinates,
    required this.distances,
    required this.currentPostion,
    required this.line,
    required this.probLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0;

    // Draw Grid
    const gridSize = 20.0; // Spacing of grid
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    const Offset zero = Offset(20, 500);

    // Horizontal
    canvas.drawLine(zero, const Offset(340, 500), Paint()..strokeWidth = 2);
    // Vertical
    canvas.drawLine(zero, const Offset(20, 100), Paint()..strokeWidth = 2);

    // Draw Beacons
    final beaconPaint = Paint()..color = Colors.blue;
    for (var beacon in beaconCoordinates.entries) {
      canvas.drawCircle(
          convertToGridPosition(
              Offset(beacon.value.x, beacon.value.y), gridSize, zero),
          5,
          beaconPaint);
    }

    //Draw distance
    final distancePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke;
    for (var beacon in beaconCoordinates.entries) {
      double radius;
      if (beacon.key == '54C30B7D-6B88-4BB6-AEDA-A157C07476BA') {
        radius = distances[0] * 2.51;
      } else if (beacon.key == 'B1291BC1-5CC2-402E-854C-CBC111F67295') {
        radius = distances[1] * 2.51;
      } else if (beacon.key == 'A8A7DC3D-5EB1-4DE4-B020-62BD11DAC3FE') {
        radius = distances[2] * 2.51;
      } else {
        continue;
      }

      canvas.drawCircle(
        convertToGridPosition(
            Offset(beacon.value.x, beacon.value.y), gridSize, zero),
        radius / 50 * 20, // Convert cm to grid units
        distancePaint,
      );
    }

    // Draw Line / Gang
    // UserLine
    canvas.drawLine(
        convertToGridPosition(
            Offset(line.start.x, line.start.y), gridSize, zero),
        convertToGridPosition(Offset(line.end.x, line.end.y), gridSize, zero),
        Paint()
          ..strokeWidth = 3
          ..color = Colors.blue);

    // Draw Probability Line
    canvas.drawLine(
        convertToGridPosition(
            Offset(probLine.start.x, probLine.start.y), gridSize, zero),
        convertToGridPosition(
            Offset(probLine.end.x, probLine.end.y), gridSize, zero),
        Paint()
          ..strokeWidth = 2
          ..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repaint when dots or circles change
  }

  Offset convertToGridPosition(Offset obj, double gapMultiplyer, Offset zero) {
    //50cm = 20 grid gap
    const int factor = 50;

    // x | y
    //0 | 0 -> 20 | 500
    // 100 | 0 -> 60 | 500 ->>>> 100 / 50 * 20 + zero.x
    // 0 | 100 -> 20 | 460 ->>>> zero.y - 100 / 50 * 20

    return Offset(obj.dx / factor * gapMultiplyer + zero.dx,
        zero.dy - obj.dy / factor * gapMultiplyer);
  }
}
