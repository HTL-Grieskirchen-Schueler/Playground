import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xml/xml.dart' as xml;
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const MainApp());
}

var colorActive = Colors.blue;
var colorNotActive = Colors.black;

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  _MainAppState createState() => _MainAppState();

  
}

class _MainAppState extends State<MainApp> {
  String _selectedRoom = '';

  void _selectRoom(String room) {
    setState(() {
      _selectedRoom = room;
      getRoomsFromSvg();
    });
  }


  List<Positioned> roomsTest = [];

  Future<void> getRoomsFromSvg() async {
      final String svgString = await rootBundle.loadString('assets/floor.svg');
      final document = xml.XmlDocument.parse(svgString);
      final rooms = document.findAllElements('rect');

      for (var room in rooms) {
        final id = room.getAttribute('id')?? 'fail';

        // if(id == 'stairs') {
        //   continue;
        // }
        final x = double.parse(room.getAttribute('x') ?? '0');
        final y = double.parse(room.getAttribute('y') ?? '0');
        final width = double.parse(room.getAttribute('width') ?? '0');
        final height = double.parse(room.getAttribute('height') ?? '0');
        
        Positioned p;

        if(id != 'stairs') {
            p = Positioned(
            left: x,
            top: y,
            child: GestureDetector(
              onTap: () {
                print('$id selected');
                _selectRoom(id);
              },
            child: Container(
              width: width,
              height: height,
              color: _selectedRoom == id ? colorActive : colorNotActive,
              child: Center(
            child: Text(
            id,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            ),
                ),
              ),
            ),
          );
        }
        else {
          p = Positioned(
          left: x,
          top: y,
          child: Container(
            width: width,
            height: height,
            color: colorNotActive,
            ),
        );
        }

        
        

        setState(() {
          roomsTest = [...roomsTest, p];
        });
      }
  }

  @override
  void initState() {
    super.initState();
    getRoomsFromSvg();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zoomable Room Layout',
      home: Scaffold(
        body: Center(
          child: InteractiveViewer(
            boundaryMargin: const EdgeInsets.all(0),
            minScale: 0.5,
            maxScale: 4.0,
            child: Stack(
              children: [
                SvgPicture.asset(
                  'assets/floor.svg',
                  semanticsLabel: 'Room Layout',
                  placeholderBuilder: (BuildContext context) =>
                      const CircularProgressIndicator(),
                  width: 1000,
                  height: 500,
                ),
                ...roomsTest,
                Positioned(
                  left: 50,
                  top: 50,
                  child: Container(
                  width: 100,
                  height: 2,
                  color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Room {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;

  Room({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}