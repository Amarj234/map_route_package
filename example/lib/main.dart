import 'package:flutter/material.dart';

import 'package:distance_route/distance_route.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {






  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapScreenRoute(bikeIcon: "assets/bike_icon.png", dropIcon: "assets/destination_icon.png", pickupIcon: "assets/pickup_icon.png", destinationLocation: LatLng(32.3, 71.5),  apiKey: '',),
    );
  }
}
