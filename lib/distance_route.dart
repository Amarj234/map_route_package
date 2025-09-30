import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
export 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;

class MapScreenRoute extends StatefulWidget {

 final LatLng? destinationLocation;
  final String bikeIcon;
  final String dropIcon;
  final String pickupIcon;
  final String apiKey;
  MapScreenRoute({super.key, required this.bikeIcon, required this.dropIcon, required this.pickupIcon,required this.destinationLocation, required this.apiKey});

  @override
  State<MapScreenRoute> createState() => _MapScreenRouteState();
}

class _MapScreenRouteState extends State<MapScreenRoute> {
  final Completer<GoogleMapController> _ctrl = Completer();
  static const CameraPosition _initial = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 18,
  );

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _bikeIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destinationIcon;

  LatLng? _userLocation;

  StreamSubscription<Position>? _posSub;



  List<LatLng> _routePoints = [];
  double? _estimatedDistance;
  String? _estimatedTime;

  Map<String, LatLng> _drivers = {
    'driver_1': LatLng(28.616, 77.21),
  };

  Timer? _rideTimer;

  // Navigation steps
  List<StepInfo> _navigationSteps = [];
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCustomIcons().then((_) => _initMarkers());
    _listenLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _rideTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomIcons() async {
    _bikeIcon = await _loadCustomMarker('assets/AppAsset/bike_icon.png', width: 120);
    _pickupIcon = await _loadCustomMarker('assets/AppAsset/pickup_icon.png', width: 40);
    _destinationIcon = await _loadCustomMarker('assets/AppAsset/destination_icon.png', width: 40);
  }

  Future<BitmapDescriptor> _loadCustomMarker(String assetPath, {int width = 120}) async {
    final byteData = await rootBundle.load(assetPath);
    Uint8List bytes = byteData.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: width, targetHeight: 100);
    final frame = await codec.getNextFrame();
    final resizedBytes = (await frame.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  void _initMarkers() {
    _markers.clear();

    if (_userLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }

    if (pickupLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickupLocation!,
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Point'),
      ));
    }

    if (widget.destinationLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: widget.destinationLocation!,
        icon: _destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }

    _drivers.forEach((id, pos) {
      _markers.add(Marker(
        markerId: MarkerId(id),
        position: pos,
        icon: _bikeIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'Driver'),
      ));
    });

    setState(() {});
  }

  LatLng? pickupLocation;

  Future<void> _listenLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    _userLocation = LatLng(pos.latitude, pos.longitude);
    pickupLocation ??= _userLocation;
    _moveCamera(_userLocation!, zoom: 15);
    _initMarkers();

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 10),
    ).listen((p) {
      _userLocation = LatLng(p.latitude, p.longitude);
      _initMarkers();
    });
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 18}) async {
    final controller = await _ctrl.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: zoom)));
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    String googleApiKey = widget.apiKey ;// replace
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$googleApiKey";

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    if (data["routes"].isEmpty) return;

    final route = data["routes"][0];
    final polyline = route["overview_polyline"]["points"];
    _routePoints = decodePolyline(polyline);

    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId("main"),
      points: _routePoints,
      width: 6,
      color: Colors.blueAccent,
    ));

    _navigationSteps.clear();
    _currentStepIndex = 0;

    final legs = route["legs"] as List;
    for (final leg in legs) {
      for (final step in leg["steps"]) {
        final htmlInstruction = step["html_instructions"];
        final endLat = step["end_location"]["lat"];
        final endLng = step["end_location"]["lng"];
        _navigationSteps.add(StepInfo(
          instruction: _stripHtmlTags(htmlInstruction),
          endLocation: LatLng(endLat, endLng),
        ));
      }
    }

    _calculateRideDetails();
    setState(() {});
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyPoints = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final point = LatLng(lat / 1E5, lng / 1E5);
      polyPoints.add(point);
    }

    return polyPoints;
  }



  String _stripHtmlTags(String htmlText) {
    return htmlText.replaceAll(RegExp(r"<[^>]*>"), ""); // remove HTML tags
  }
  void _calculateRideDetails() {
    double totalDistance = 0;
    for (int i = 1; i < _routePoints.length; i++) {
      totalDistance += _calculateDistance(_routePoints[i - 1], _routePoints[i]);
    }

    _estimatedDistance = double.parse(totalDistance.toStringAsFixed(2));
    _estimatedTime = (totalDistance * 2).toStringAsFixed(0);
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371;
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(from.latitude)) *
            cos(_toRadians(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;


  void _showLocationOptions(LatLng position) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ListTile(
          //   leading: const Icon(Icons.location_on, color: Colors.green),
          //   title: const Text('Set as Pickup Location'),
          //   onTap: () {
          //     Navigator.pop(ctx);
          //     setState(() => pickupLocation = position);
          //     _initMarkers();
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(Icons.flag, color: Colors.red),
          //   title: const Text('Set as Destination'),
          //   onTap: () {
          //     Navigator.pop(ctx);
          //     setState(() => widget.destinationLocation = position);
          //     _initMarkers();
          //     if (pickupLocation != null) {
          //       _drawRoute(pickupLocation!, widget.destinationLocation!);
          //     }
          //   },
          // ),
        ],
      ),
    );
  }



  StreamSubscription<Position>? _positionStream;

  void _startRide() {
    if (_routePoints.isEmpty || widget.destinationLocation == null) return;

    _positionStream?.cancel(); // Cancel previous if exists
    _currentStepIndex = 0;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
          final currentPos = LatLng(position.latitude, position.longitude);

          print("📍 New location: ${currentPos.latitude}, ${currentPos.longitude}");

          _userLocation = currentPos;
          _drivers["driver_1"] = currentPos;

          _initMarkers();
          _moveCamera(currentPos);

          // ✅ 1. Check if deviated from polyline
          final nearestDistance = _getNearestPolylineDistance(currentPos);
          if (nearestDistance > 50) {
            print("⚠️ Off-route detected! Recalculating route...");
            _drawRoute(currentPos, widget.destinationLocation!);
            return;
          }

          // ✅ 2. Check if reached current navigation step
          if (_currentStepIndex < _navigationSteps.length) {
            final stepEnd = _navigationSteps[_currentStepIndex].endLocation;
            final distanceToStepEnd =
                _calculateDistance(currentPos, stepEnd) * 1000; // meters

            if (distanceToStepEnd < 30) {
              print(
                  "✅ Reached step ${_currentStepIndex + 1}: ${_navigationSteps[_currentStepIndex].instruction}");
              setState(() {
                _currentStepIndex++;
              });
            }
          }

          // ✅ 3. Check if reached destination
          final distanceToDestination =
              _calculateDistance(currentPos, widget.destinationLocation!) * 1000;
          if (distanceToDestination < 20) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("🎯 Ride Finished")),
            );
            _positionStream?.cancel();
          }
        });
  }
  double _getNearestPolylineDistance(LatLng currentPos) {
    double minDistance = double.infinity;

    for (var point in _routePoints) {
      final distance = _calculateDistance(currentPos, point) * 1000; // meters
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initial,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) => _ctrl.complete(controller),
           // onTap: _handleMapTap,
          ),
          // Positioned(
          //   top: 40,
          //   left: 16,
          //   right: 16,
          //   child: Card(
          //     child: ListTile(
          //       leading: const Icon(Icons.search),
          //       title: const Text("Tap to select destination"),
          //       onTap: _startDestinationSelection,
          //     ),
          //   ),
          // ),
          if (_routePoints.isNotEmpty)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _startRide,
                child: const Text("Start Ride", style: TextStyle(fontSize: 18)),
              ),
            ),
          if (_estimatedDistance != null && _estimatedTime != null)
            Positioned(
              bottom: 90,
              left: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                      "Distance: $_estimatedDistance km | ETA: $_estimatedTime min"),
                ),
              ),
            ),
          if (_navigationSteps.isNotEmpty && _currentStepIndex < _navigationSteps.length)
            Positioned(
              bottom: 150,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Next: ${_navigationSteps[_currentStepIndex].instruction}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Helper class to store step info
class StepInfo {
  final String instruction;
  final LatLng endLocation;
  StepInfo({required this.instruction, required this.endLocation});
}
