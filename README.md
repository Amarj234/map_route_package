# 🚗 Flutter Map Navigation (Custom Google Maps Route & Navigation)

A Flutter package that provides **real-time navigation with Google Maps**, including route drawing, turn-by-turn step instructions, re-routing when deviated, and live driver tracking.

---

## ✨ Features

- 🗺️ Draw driving route between pickup & destination using **Google Directions API**.
- 📍 Real-time **location tracking** with `geolocator`.
- 🎯 **Custom pickup, destination, and driver markers** with icons.
- 📏 Distance & ETA calculation.
- 🔄 Automatic **re-routing** if the driver goes off-route.
- 🧭 Step-by-step navigation instructions (like Google Maps).
- 🎨 Fully customizable UI & markers.

---

## 📦 Installation

Add dependency in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  maps_route: 


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
```dart

MapScreenRoute(
  apiKey: "YOUR_GOOGLE_MAPS_API_KEY",
  bikeIcon: 'assets/AppAsset/bike_icon.png',
  dropIcon: 'assets/AppAsset/destination_icon.png',
  pickupIcon: 'assets/AppAsset/pickup_icon.png',
  destinationLocation: LatLng(28.6139, 77.2090), // Example: Delhi
)

```


```yaml 
flutter:
  assets:
    - assets/AppAsset/bike_icon.png
    - assets/AppAsset/pickup_icon.png
    - assets/AppAsset/destination_icon.png
```



## Author

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

Auto Re-route: If you deviate from the polyline, it re-fetches route.

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

