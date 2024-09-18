import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:safe_street/ipconfig/ip.dart';
import 'package:safe_street/screens/send.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'maintain_map.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  PolylinePoints polylinePoints = PolylinePoints();
  Map<PolylineId, Polyline> polylines = {};

  Set<Marker> _markers = {};
  late BitmapDescriptor _userIcon;
  late BitmapDescriptor _smallHoleIcon;
  late BitmapDescriptor _largeHoleIcon;
  late BitmapDescriptor _smallCrackIcon;
  late BitmapDescriptor _largeCrackIcon;
  late BitmapDescriptor _maintainIcon;

  List<dynamic> smallHoles = [];
  List<dynamic> largeHoles = [];
  List<dynamic> smallCracks = [];
  List<dynamic> largeCracks = [];

  bool _iconsLoaded = false;
  Position? _currentPosition; // Change to nullable type

  static CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _loadCustomIcons().then((_) {
      _iconsLoaded = true;
      _getUserLocation();
      _getCurrentLocation();
      _showMyLocation();
      fetchData();
      _fetchAndDrawRoutes();
    });
  }

  Future<void> _loadCustomIcons() async {
    final Uint8List location = await getBytesFromAsset('assets/images/car.png', 100);
    final Uint8List smallHole = await getBytesFromAsset('assets/images/small_hole.png', 50);
    final Uint8List largeHole = await getBytesFromAsset('assets/images/large_hole.png', 70);
    final Uint8List smallCrack = await getBytesFromAsset('assets/images/small_crack.png', 50);
    final Uint8List largeCrack = await getBytesFromAsset('assets/images/large_crack.png', 70);
    final Uint8List maintain = await getBytesFromAsset('assets/images/fix_road.png', 70);

    setState(() {
      _userIcon = BitmapDescriptor.fromBytes(location);
      _smallHoleIcon = BitmapDescriptor.fromBytes(smallHole);
      _largeHoleIcon = BitmapDescriptor.fromBytes(largeHole);
      _smallCrackIcon = BitmapDescriptor.fromBytes(smallCrack);
      _largeCrackIcon = BitmapDescriptor.fromBytes(largeCrack);
      _maintainIcon = BitmapDescriptor.fromBytes(maintain);
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  void _showMyLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _updateMarkerPosition(position);
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 17.0),
    ));
  }

  Future<void> fetchData() async {
    var url = Uri.parse('$ip/detection/get-detection');
    var response = await http.get(url);
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      setState(() {
        smallHoles = jsonResponse['latLongSmallHole'];
        largeHoles = jsonResponse['latLongLargeHole'];
        smallCracks = jsonResponse['latLongSmallCrack'];
        largeCracks = jsonResponse['latLongLargeCrack'];
      });
      if (_iconsLoaded) {
        polylines.clear();
        _fetchAndDrawRoutes();
        _updateMarkers();
      }
    } else {
      throw Exception('Failed to load data');
    }
  }

  void _updateMarkers() {
    setState(() {
      _markers.clear();
      int smallHoleIndex = 0;
      for (var item in smallHoles) {
        _markers.add(
          Marker(
            markerId: MarkerId('smallHole$smallHoleIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Hole', snippet: 'Small Hole'),
            icon: _smallHoleIcon,
          ),
        );
        smallHoleIndex++;
      }

      int largeHoleIndex = 0;
      for (var item in largeHoles) {
        _markers.add(
          Marker(
            markerId: MarkerId('largeHole$largeHoleIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Hole', snippet: 'Large Hole'),
            icon: _largeHoleIcon,
          ),
        );
        largeHoleIndex++;
      }

      int smallCrackIndex = 0;
      for (var item in smallCracks) {
        _markers.add(
          Marker(
            markerId: MarkerId('smallCrack$smallCrackIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Crack', snippet: 'Small Crack'),
            icon: _smallCrackIcon,
          ),
        );
        smallCrackIndex++;
      }

      int largeCrackIndex = 0;
      for (var item in largeCracks) {
        _markers.add(
          Marker(
            markerId: MarkerId('largeCrack$largeCrackIndex'),
            position: LatLng(item[0], item[1]),
            infoWindow: InfoWindow(title: 'Crack', snippet: 'Large Crack'),
            icon: _largeCrackIcon,
          ),
        );
        largeCrackIndex++;
      }

      if (_iconsLoaded && _currentPosition != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('myLocation'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: InfoWindow(title: 'Your Location', snippet: 'This is where you are.'),
            icon: _userIcon,
          ),
        );
      }
    });
  }

  Future<void> _drawRouteForMap(LatLng source, LatLng destination, int date, String createdAt, String updatedAt) async {
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${source.latitude},${source.longitude}&destination=${destination.latitude},${destination.longitude}&key=$api_key'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = polylinePoints.decodePolyline(data['routes'][0]['overview_polyline']['points']);
      List<LatLng> polylineCoordinates = [];
      if (points.isNotEmpty) {
        points.forEach((point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });
      }

      setState(() {
        final id = PolylineId(source.toString() + '_' + destination.toString());
        Polyline polyline = Polyline(
          polylineId: id,
          color: Colors.red,
          points: polylineCoordinates,
          width: 5,
        );
        polylines[id] = polyline;

        // Calculate the midpoint of the route and add a marker
        if (polylineCoordinates.length > 1) {
          LatLng midPoint = polylineCoordinates[(polylineCoordinates.length / 2).round()];
          _markers.add(
            Marker(
              markerId: MarkerId('midpoint_${id.value}'),
              position: midPoint,
              icon: _maintainIcon,
              infoWindow: InfoWindow(title: 'Date maintain: ${date}d', snippet: '${DateFormat('yyyy/MM/dd ').format(DateTime.parse(createdAt))} - ${DateFormat('yyyy/MM/dd ').format(DateTime.parse(updatedAt))}'),
            ),
          );
        }
      });
    } else {
      throw Exception('Failed to load directions');
    }
  }

  Future<void> _fetchAndDrawRoutes() async {
    var url = Uri.parse('$ip/detection/get-maintain-road');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      for (var route in data) {
        final locationA = _parseLatLng(route['locationA']);
        final locationB = _parseLatLng(route['locationB']);
        final date = route['dateMaintain'];
        final createdAt = route['createdAt'];
        final updatedAt = route['updatedAt'];
        await _drawRouteForMap(locationA, locationB, date, createdAt, updatedAt);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch routes from server')));
    }
  }

  LatLng _parseLatLng(String latLngString) {
    final parts =
    latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  void _getCurrentLocation() async {
    await Geolocator.getPositionStream(desiredAccuracy: LocationAccuracy.high, distanceFilter: 10).listen((Position position) {
      print(position);
      _currentPosition = position;
      _updateMarkerPosition(position);
    });
  }

  Future<void> _getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentPosition = position;
    _kGooglePlex = CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 14.4746);
    _updateMarkerPosition(position);
  }

  void _updateMarkerPosition(Position position) {
    setState(() {
      _currentPosition = position;
      _markers.removeWhere((marker) => marker.markerId.value == 'myLocation');
      _markers.add(
        Marker(
          markerId: MarkerId('myLocation'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: InfoWindow(title: 'Your Location', snippet: 'This is where you are.'),
          icon: _userIcon,
        ),
      );
    });
  }

  void _reloadData() {
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.terrain,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _reloadData();
            },
            markers: _markers,
            polylines: Set<Polyline>.of(polylines.values), // Ensure polylines are added to the map
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: <Widget>[
          Positioned(
            bottom: 130.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag1',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SendScreen()),
                );
              },
              tooltip: 'Send Report',
              child: Icon(Icons.add_alert),
            ),
          ),
          Positioned(
            bottom: 85.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag2',
              backgroundColor: Color(0xFFFFFFFF),
              mini: true,
              shape: const CircleBorder(),
              onPressed: _showMyLocation,
              tooltip: 'Show My Location',
              child: Image.asset('assets/images/car.png',
                  width: 30, height: 30),
            ),
          ),
          Positioned(
            bottom: 175.0,
            right: -4,
            child: FloatingActionButton(
              heroTag: 'uniqueTag3',
              mini: true,
              shape: const CircleBorder(),
              backgroundColor: Color(0xFFFFFFFF),
              onPressed: _reloadData,
              tooltip: 'Reload Data',
              child: Icon(Icons.refresh),
            ),
          ),
          Positioned(
              bottom: 10.0,
              left: 25,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white70,
                  border: Border.all(color: Colors.blueAccent),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'Maintain',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Image.asset('assets/images/fix_road.png', width: 40, height: 40)
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Small Hole',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Image.asset('assets/images/small_hole.png', width: 40, height: 40)
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Large Hole',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Image.asset('assets/images/large_hole.png', width: 45, height: 45)
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Small Crack',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Image.asset('assets/images/small_crack.png', width: 40, height: 40)
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'Large Crack',
                          style: GoogleFonts.beVietnamPro(
                            textStyle: const TextStyle(
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Image.asset('assets/images/large_crack.png', width: 40, height: 40)
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
