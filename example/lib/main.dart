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
      home: MapScreenRoute(
        bikeIcon: "assets/bike_icon.png",
        bikeIconSize: const Size(150, 300),
        pickupIconSize: const Size(100, 100), // Optional
        dropIconSize: const Size(100, 100),
        dropIcon: "assets/destination_icon.png",
        pickupIcon: "assets/pickup_icon.png",
        destinationLocation: LatLng(25.4681589, 81.8648168),
        apiKey:
            'Paste Your Google Map Key Here', // make sure you have enabled all required APIs
        onReach: (double distance) {},
      ),
    );
  }
}
