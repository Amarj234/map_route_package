# 🚗 Flutter Map Navigation (Custom Google Maps Route & Navigation)

A Flutter package that provides **real-time navigation with Google Maps**, including route drawing, turn-by-turn step instructions, re-routing when deviated, and live driver tracking.

---

## ✨ Features

- 🗺️ Draw driving route between pickup & destination using **Google Directions API**.
- 📍 Real-time **location tracking** with `geolocator`.
- 🎯 **Custom pickup, destination, and driver markers** with icons.
- 📏 Distance & ETA calculation.
- 🔄 Automatic **re-routing** if the driver goes off-route (with a configurable threshold).
- 🧲 **Snap-to-road** — the driver marker rides on the route line instead of floating off it.
- ✂️ **Consuming route polyline** — the traveled portion dims while the remaining route stays highlighted, so the line shrinks as you progress.
- 🏍️ **Smooth marker movement** — gliding motion matched to the GPS update rate.
- 🧭 Step-by-step navigation instructions (like Google Maps).
- 🎨 Fully customizable UI & markers.

---

## 🎥 Demo Video

[![Watch the demo](https://raw.githubusercontent.com/Amarj234/map_route_package/refs/heads/main/Screenshot%202025-10-01%20at%2011.16.32%E2%80%AFAM.png)](https://github.com/Amarj234/map_route_package/blob/main/Screen_recording_20250925_145039%20(1).mp4)

Click the image above to watch the demo video.




## 📦 Installation

Add dependency in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  distance_route: 


```
⚙️ Setup
1. Get a Google Maps API Key

Go to Google Cloud Console
.

Enable the following APIs:

Maps SDK for Android

Maps SDK for iOS

Directions API

Create an API Key and restrict it to Android/iOS apps.

2. Android Permissions

In android/app/src/main/AndroidManifest.xml, add:

```

<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.app">

    <!-- Internet + Location permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <application
        android:name="${applicationName}"
        android:label="app_name"
        android:icon="@mipmap/ic_launcher">

        <!-- Google Maps API Key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY_HERE"/>

    </application>
</manifest>

```

3. iOS Permissions

In ios/Runner/Info.plist, add:

```agsl

<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access for navigation</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs location access for navigation</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access for navigation</string>

<key>io.flutter.embedded_views_preview</key>
<true/>

```

```yaml

cd ios
pod install



```
## 🚀 Usage

```dart
MapScreenRoute(
  bikeIcon: "assets/bike_icon.png",
  dropIcon: "assets/destination_icon.png", 
  pickupIcon: "assets/pickup_icon.png",
  destinationLocation: LatLng(32.3, 71.5), 
  apiKey: 'YOUR_GOOGLE_MAPS_API_KEY', // make soure you have enable all required feature
  onReach: (double distance) { 
    print("Reached destination! Distance: $distance");
  },
  bikeIconSize: const Size(150, 300), // Optional
  pickupIconSize: const Size(40, 40), // Optional
  dropIconSize: const Size(40, 40),   // Optional
),
```

## 🛠️ Parameters

| Parameter | Type | Mandatory | Description |
|-----------|------|-----------|-------------|
| `bikeIcon` | `String` | ✅ Yes | Asset path to the bike/driver icon. |
| `dropIcon` | `String` | ✅ Yes | Asset path to the destination icon. |
| `pickupIcon` | `String` | ✅ Yes | Asset path to the pickup point icon. |
| `destinationLocation` | `LatLng` | ✅ Yes | Coordinates of the destination. |
| `apiKey` | `String` | ✅ Yes | Your Google Maps API Key (with Directions API enabled). |
| `onReach` | `Function(double)` | ✅ Yes | Callback function triggered when the user reaches the destination. |
| `pickupLocations` | `LatLng?` | ❌ No | Initial pickup location. If not provided, it uses current user location. |
| `buttonColor` | `Color?` | ❌ No | Background color for the default ride button. |
| `isShowRideButton` | `bool` | ❌ No | Whether to show the default "Start Ride" button. Default is `true`. |
| `rideButton` | `Widget?` | ❌ No | Custom widget to replace the default ride button. |
| `bikeIconSize` | `Size?` | ❌ No | Custom size for the bike/driver icon. Default is `120x100`. |
| `dropIconSize` | `Size?` | ❌ No | Custom size for the destination icon. Default is `40x40`. |
| `pickupIconSize` | `Size?` | ❌ No | Custom size for the pickup icon. Default is `40x40`. |
| `offRouteThreshold` | `double` | ❌ No | Distance (in meters) the driver may stray from the route before an automatic re-route is triggered. Default is `50`. |

```yaml 
flutter:
  assets:
    - assets/bike_icon.png
    - assets/pickup_icon.png
    - assets/destination_icon.png
```



## Author
<h2>Amarjeet Kushwaha</h2>
<h3>UserName: amarj234</h3>


<p align="center">
  <img src="https://media.licdn.com/dms/image/v2/D5603AQEaN03Kf1dbiA/profile-displayphoto-shrink_200_200/B56ZdYflF_H8Ag-/0/1749536366485?e=2147483647&v=beta&t=nmOpN350dNf3wqVfrNL-rE3zXBVSHfFDTDQ7X8oAykg" alt="Amarjeet Kushwaha
" width="150" height="150" style="border-radius:50%">
</p>

<p align="center">
  <a href="https://github.com/Amarj234">
    <img src="https://img.shields.io/badge/GitHub-181717?logo=github&logoColor=white&style=for-the-badge" alt="GitHub">
  </a>
  <a href="https://www.linkedin.com/in/amarj234/">
    <img src="https://img.shields.io/badge/LinkedIn-0A66C2?logo=linkedin&logoColor=white&style=for-the-badge" alt="LinkedIn">
  </a>
</p>

Navigation Features

Start Ride: Begins turn-by-turn navigation.

Auto Re-route: If you stray beyond `offRouteThreshold` (default 50 m) for two consecutive readings, it re-fetches the route — confirmation avoids false triggers from GPS noise.

Snap-to-road: The driver marker is projected onto the nearest route segment so it always rides on the road line.

Route progress: The traveled part of the polyline dims (grey) while the remaining part stays highlighted (blue), shrinking the route as you advance.

Next Step Instructions: Shows "Next: Turn left on XYZ road".

ETA & Distance: Shows estimated distance & time.

✅ Permissions Required

Location (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION)

Internet (for Directions API request)

🛠️ Customization

Replace icons with your own PNGs.

Change polyline color/width.

Modify UI overlays (ETA, instructions, buttons).

📌 Notes

Make sure your API key has Directions API enabled, otherwise routing won’t work.

Location permission must be granted by user at runtime.

On iOS simulator, location may not update unless you set a custom location in Debug > Location.

🎯 Roadmap

Add voice navigation (TTS).

Support walking & cycling modes.

Offline route caching.

