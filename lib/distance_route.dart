import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
export "package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart";
import 'package:http/http.dart' as http;
import 'package:keep_screen_on/keep_screen_on.dart';

class MapScreenRoute extends StatefulWidget {
  final LatLng? pickupLocations;
  final LatLng? destinationLocation;
  final String bikeIcon;
  final Color? buttonColor;
  final String dropIcon;
  final String pickupIcon;
  final bool isShowRideButton;
  final String apiKey;
  final Size? bikeIconSize;
  final Size? dropIconSize;
  final Size? pickupIconSize;
  final Function(double distance) onReach;
  final Widget? rideButton;
  const MapScreenRoute({
    super.key,
    required this.bikeIcon,
    required this.dropIcon,
    required this.pickupIcon,
    required this.destinationLocation,
    required this.apiKey,
    this.pickupLocations,
    this.isShowRideButton = true,
    required this.onReach,
    this.rideButton,
    this.buttonColor,
    this.bikeIconSize,
    this.dropIconSize,
    this.pickupIconSize,
  });

  @override
  State<MapScreenRoute> createState() => _MapScreenRouteState();
}

class _MapScreenRouteState extends State<MapScreenRoute>
    with TickerProviderStateMixin {
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

  String startRide = "Start Ride";

  List<LatLng> _routePoints = [];
  double? _estimatedDistance;
  String? _estimatedTime;

  late AnimationController _topInstructionController;
  late AnimationController _bottomPillController;
  late AnimationController _etaController;

  late AnimationController _markerController;
  LatLng? _oldPosition;
  LatLng? _newPosition;
  double _oldRotation = 0;
  double _newRotation = 0;

  late Animation<Offset> _topSlide;
  late Animation<double> _etaFade;

  Map<String, LatLng> _drivers = {'driver_1': const LatLng(28.616, 77.21)};

  Timer? _rideTimer;

  // Navigation steps
  List<StepInfo> _navigationSteps = [];
  int _currentStepIndex = 0;

  @override
  void initState() {
    if (widget.pickupLocations != null) {
      pickupLocation = widget.pickupLocations;
    }
    Future.delayed(const Duration(seconds: 4), () async {
      if (pickupLocation == null) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 10), // increased timeout
            desiredAccuracy: LocationAccuracy.bestForNavigation,
          );
          pickupLocation = LatLng(pos.latitude, pos.longitude);
        } catch (e) {
          // If getCurrentPosition fails, try to get last known location
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) {
            pickupLocation = LatLng(lastPos.latitude, lastPos.longitude);
          }
        }
      }

      if (pickupLocation != null) {
        _drawRoute(pickupLocation!, widget.destinationLocation!);
        initlizeAnimation();
      }
    });
    super.initState();
    _loadCustomIcons().then((_) => _initMarkers());
    _listenLocation();
    // Keep the screen on.
    KeepScreenOn.turnOn();
  }

  initlizeAnimation() {
    _topInstructionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _bottomPillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _etaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _topSlide =
        Tween<Offset>(
          begin: const Offset(0, -1),
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(
            parent: _topInstructionController,
            curve: Curves.easeOutBack,
          ),
        );

        Tween<Offset>(
          begin: const Offset(0, 1),
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(
            parent: _bottomPillController,
            curve: Curves.easeOutBack,
          ),
        );

    _etaFade = Tween<double>(begin: 0, end: 1).animate(_etaController);

    _markerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(() {
            setState(() {
              if (_oldPosition != null && _newPosition != null) {
                final double t = _markerController.value;
                final double lat =
                    _oldPosition!.latitude +
                    (_newPosition!.latitude - _oldPosition!.latitude) * t;
                final double lng =
                    _oldPosition!.longitude +
                    (_newPosition!.longitude - _oldPosition!.longitude) * t;
                _drivers["driver_1"] = LatLng(lat, lng);

                double diff = _newRotation - _oldRotation;
                if (diff.abs() > 180) diff -= 360 * diff.sign;
                _liveBearing = (_oldRotation + diff * t) % 360;
              }
              _initMarkers();
            });
          });

    // Trigger animations on screen open
    _topInstructionController.forward();
    _bottomPillController.forward();
    _etaController.forward();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _rideTimer?.cancel();
    _positionStream?.cancel();
    KeepScreenOn.turnOff();
    _topInstructionController.dispose();
    _bottomPillController.dispose();
    _etaController.dispose();
    _markerController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomIcons() async {
    _bikeIcon = await _loadCustomMarker(
      widget.bikeIcon,
      width: widget.bikeIconSize?.width.toInt() ?? 120,
      height: widget.bikeIconSize?.height.toInt() ?? 100,
    );
    _pickupIcon = await _loadCustomMarker(
      widget.pickupIcon,
      width: widget.pickupIconSize?.width.toInt() ?? 40,
      height: widget.pickupIconSize?.height.toInt() ?? 40,
    );
    _destinationIcon = await _loadCustomMarker(
      widget.dropIcon,
      width: widget.dropIconSize?.width.toInt() ?? 40,
      height: widget.dropIconSize?.height.toInt() ?? 40,
    );
  }

  Future<BitmapDescriptor> _loadCustomMarker(
    String assetPath, {
    int width = 120,
    int height = 100,
  }) async {
    final byteData = await rootBundle.load(assetPath);
    Uint8List bytes = byteData.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      targetHeight: height,
    );
    final frame = await codec.getNextFrame();
    final resizedBytes = (await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  void _initMarkers() {
    _markers.clear();

    if (_userLocation != null && !rideStarted) {
      _markers.add(
        Marker(
          markerId: const MarkerId('user'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    if (pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLocation!,
          icon:
              _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Point'),
        ),
      );
    }

    if (widget.destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.destinationLocation!,
          icon:
              _destinationIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    _drivers.forEach((id, pos) {
      _markers.add(
        Marker(
          markerId: MarkerId(id),
          position: pos,
          icon: _bikeIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          rotation: _liveBearing,
          flat: true,
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
      );
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

    try {
      // Try to get last known position first (fastest)
      Position? pos = await Geolocator.getLastKnownPosition();

      // If no last known position, request current position
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      _userLocation = LatLng(pos.latitude, pos.longitude);
      pickupLocation ??= _userLocation;

      _moveCamera(_userLocation!, zoom: 15);
      _initMarkers();
    } catch (e) {
      debugPrint("Error getting initial location: $e");
    }

    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(distanceFilter: 0),
        ).listen((p) {
          _userLocation = LatLng(p.latitude, p.longitude);

          _initMarkers();
        });
  }

  double _calculateBearing(LatLng from, LatLng to) {
    double lat1 = _toRadians(from.latitude);
    double lon1 = _toRadians(from.longitude);
    double lat2 = _toRadians(to.latitude);
    double lon2 = _toRadians(to.longitude);

    double dLon = lon2 - lon1;
    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    double bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360; // convert to degrees
  }

  Future<void> _moveCamera(
    LatLng target, {
    double zoom = 18,
    double bearing = 0,
  }) async {
    final controller = await _ctrl.future;

    // Offset camera slightly ahead in direction of bearing
    final offsetDistance = 0.0003; // ≈ 30m
    final offsetLat =
        target.latitude + offsetDistance * cos(bearing * pi / 180);
    final offsetLng =
        target.longitude + offsetDistance * sin(bearing * pi / 180);

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(offsetLat, offsetLng),
          zoom: zoom,
          bearing: bearing,
          tilt: 60,
        ),
      ),
    );
  }

  bool _isLoadingRoute = true;
  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    setState(() {
      _isLoadingRoute = true;
      _estimatedDistance = null;
      _estimatedTime = null;
    });
    try {
      String googleApiKey = widget.apiKey;
      final url =
          "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$googleApiKey";

      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["status"] != "OK") {
        String errorMessage = "Directions Error: ${data["status"]}";
        if (data["status"] == "ZERO_RESULTS") {
          errorMessage = "No driving route found between these locations.";
        } else if (data["status"] == "OVER_QUERY_LIMIT") {
          errorMessage =
              "API limit exceeded. Please check Google Cloud billing.";
        } else if (data["status"] == "REQUEST_DENIED") {
          errorMessage =
              "API request denied. Check your API key and restriction.";
        } else if (data["status"] == "INVALID_REQUEST") {
          errorMessage = "Invalid request parameters detected.";
        }

        debugPrint(errorMessage);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
        return;
      }

      if (data["routes"].isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No routes found between these locations."),
            ),
          );
        }
        return;
      }

      final route = data["routes"][0];
      final polyline = route["overview_polyline"]["points"];
      _routePoints = decodePolyline(polyline);

      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId("main"),
          points: _routePoints,
          width: 6,
          color: Colors.blueAccent,
        ),
      );

      _navigationSteps.clear();
      _currentStepIndex = 0;

      final legs = route["legs"] as List;
      for (final leg in legs) {
        for (final step in leg["steps"]) {
          final htmlInstruction = step["html_instructions"];
          final endLat = step["end_location"]["lat"];
          final endLng = step["end_location"]["lng"];
          _navigationSteps.add(
            StepInfo(
              instruction: _stripHtmlTags(htmlInstruction),
              endLocation: LatLng(endLat, endLng),
            ),
          );
        }
      }

      _calculateRideDetails();
    } catch (e) {
      debugPrint("Error drawing route: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load route: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
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
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(from.latitude)) *
            cos(_toRadians(to.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  //
  // void _showLocationOptions(LatLng position) {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (ctx) => Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         // ListTile(
  //         //   leading: const Icon(Icons.location_on, color: Colors.green),
  //         //   title: const Text('Set as Pickup Location'),
  //         //   onTap: () {
  //         //     Navigator.pop(ctx);
  //         //     setState(() => pickupLocation = position);
  //         //     _initMarkers();
  //         //   },
  //         // ),
  //         // ListTile(
  //         //   leading: const Icon(Icons.flag, color: Colors.red),
  //         //   title: const Text('Set as Destination'),
  //         //   onTap: () {
  //         //     Navigator.pop(ctx);
  //         //     setState(() => widget.destinationLocation = position);
  //         //     _initMarkers();
  //         //     if (pickupLocation != null) {
  //         //       _drawRoute(pickupLocation!, widget.destinationLocation!);
  //         //     }
  //         //   },
  //         // ),
  //       ],
  //     ),
  //   );
  // }

  double _liveBearing = 0.0;

  StreamSubscription<Position>? _positionStream;

  double _getRemainingDistance(LatLng currentPos) {
    double total = 0;

    // Find closest polyline index
    int closestIndex = 0;
    double minDist = double.infinity;

    for (int i = 0; i < _routePoints.length; i++) {
      double dist = _calculateDistance(currentPos, _routePoints[i]);
      if (dist < minDist) {
        minDist = dist;
        closestIndex = i;
      }
    }

    // Add remaining distance on polyline
    for (int i = closestIndex; i < _routePoints.length - 1; i++) {
      total += _calculateDistance(_routePoints[i], _routePoints[i + 1]);
    }

    return total; // in km
  }

  String _calculateETA(double distanceKm) {
    const double avgSpeedKmH = 30; // adjust as you want
    double timeHours = distanceKm / avgSpeedKmH;
    int minutes = (timeHours * 60).round();
    return minutes.toString();
  }

  void _startRide() async {
    if (_routePoints.isEmpty || widget.destinationLocation == null) return;

    _positionStream?.cancel();
    _currentStepIndex = 0;

    // 🔥 Compass listener — instant rotation
    FlutterCompass.events!.listen((event) {
      if (event.heading != null) {
        _liveBearing = event.heading!;
      }
    });

    // 🌎 Last location
    Position? lastPosition = await Geolocator.getLastKnownPosition();
    if (lastPosition != null) {
      final currentPos = LatLng(lastPosition.latitude, lastPosition.longitude);
      _userLocation = currentPos;
      _drivers["driver_1"] = currentPos;

      _initMarkers();
      _moveCamera(currentPos, bearing: _liveBearing);
    }

    startRide = "Re Route";

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    // 🚀 Live location updates
    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) async {
            final currentPos = LatLng(position.latitude, position.longitude);
            _userLocation = currentPos;

            // Start smooth animation
            _oldPosition = _drivers["driver_1"];
            _newPosition = currentPos;
            _oldRotation = _liveBearing;

            // Calculate bearing from previous point if movement is significant
            if (_oldPosition != null) {
              double bearing = _calculateBearing(_oldPosition!, _newPosition!);
              if (_calculateDistance(_oldPosition!, _newPosition!) > 0.005) {
                // more than 5 meters
                _newRotation = bearing;
              } else {
                _newRotation = _liveBearing;
              }
            }

            _markerController.reset();
            _markerController.forward();

            // 🧭 INSTANT ROTATION
            double bearing = _liveBearing;

            // 🎥 Move map + bike instantly
            _moveCamera(currentPos, bearing: bearing);

            // =============================
            // 🔥 LIVE ETA + DISTANCE UPDATE
            // =============================
            double remainingKm = _getRemainingDistance(currentPos);
            String remainingTime = _calculateETA(remainingKm);

            setState(() {
              _estimatedDistance = double.parse(remainingKm.toStringAsFixed(3));
              _estimatedTime = remainingTime;
            });

            // 🚧 Check off-route (50m)
            final nearestDistance = _getNearestPolylineDistance(currentPos);
            if (nearestDistance > 50) {
              _drawRoute(currentPos, widget.destinationLocation!);
              return;
            }

            // 📍 Step navigation
            if (_currentStepIndex < _navigationSteps.length) {
              final stepEnd = _navigationSteps[_currentStepIndex].endLocation;
              final distanceToStepEnd =
                  _calculateDistance(currentPos, stepEnd) * 1000; // meters

              if (distanceToStepEnd < 30) {
                setState(() {
                  _currentStepIndex++;
                });
              }
            }

            // 🎯 Destination reached
            final distanceToDestination =
                _calculateDistance(currentPos, widget.destinationLocation!) *
                1000;

            //if (distanceToDestination < 500) {
            widget.onReach(distanceToDestination);
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(content: Text("🎯 Ride Finished")),
            // );
            // _positionStream?.cancel();
            // }
          },
        );
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
    return SafeArea(
      child: Scaffold(
        body: _isLoadingRoute
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // MAP
                  GoogleMap(
                    mapType: MapType.normal,

                    initialCameraPosition: _initial,
                    compassEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _ctrl.complete(controller);
                    },
                    // onTap: _handleMapTap,
                  ),

                  // ---------- TOP INSTRUCTION (Slide Down) ----------
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: SlideTransition(
                      position: _topSlide,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _currentStepIndex < _navigationSteps.length
                                        ? _navigationSteps[_currentStepIndex]
                                              .instruction
                                        : "Continue straight",
                                    key: ValueKey(_currentStepIndex),
                                    softWrap: true,
                                    maxLines: 3, // 👈 adjust as needed
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _getTurnIcon(
                                    _navigationSteps,
                                    _currentStepIndex,
                                  ),
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ---------- ETA CARD (Fade on update) ----------
                  if (_estimatedDistance != null && _estimatedTime != null)
                    Positioned(
                      top: 10,
                      left: 20,
                      child: FadeTransition(
                        opacity: _etaFade,
                        child: ScaleTransition(
                          scale: _etaController,
                          child: Container(
                            width:
                                240, // ← control bubble width (increase if needed)
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.timer_outlined, size: 22),
                                const SizedBox(width: 10),

                                /// EXPANDED so text wraps to multiple lines
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      /// ETA - First Line
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        transitionBuilder: (child, anim) =>
                                            FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                        child: Text(
                                          "$_estimatedTime min",
                                          key: ValueKey("time_$_estimatedTime"),
                                          maxLines: null,
                                          softWrap: true,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.route_outlined,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 6),

                                          /// DISTANCE - Second Line
                                          Expanded(
                                            child: AnimatedSwitcher(
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              transitionBuilder:
                                                  (child, anim) =>
                                                      FadeTransition(
                                                        opacity: anim,
                                                        child: child,
                                                      ),
                                              child: Text(
                                                "$_estimatedDistance km",
                                                key: ValueKey(
                                                  "distance_$_estimatedDistance",
                                                ),
                                                maxLines: null,
                                                softWrap: true,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ---------- BOTTOM TURN PILL (Slide Up + Fade) ----------
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => rideStarted = true);
                        _startRide(); // <-- your function
                      },
                      child:
                          widget.rideButton ??
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: widget.buttonColor ?? Colors.black,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                startRide,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

bool rideStarted = false;

IconData _getTurnIcon(List steps, int index) {
  if (index >= steps.length) return Icons.straight;

  String instruction = steps[index].instruction.toLowerCase();

  if (instruction.contains("left")) return Icons.turn_left;
  if (instruction.contains("right")) return Icons.turn_right;
  if (instruction.contains("u-turn")) return Icons.u_turn_left;

  return Icons.straight;
}

// Helper class to store step info
class StepInfo {
  final String instruction;
  final LatLng endLocation;
  StepInfo({required this.instruction, required this.endLocation});
}
