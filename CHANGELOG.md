## 0.2.0

* Added **snap-to-road**: the driver marker is projected onto the nearest route segment so it rides on the road line instead of floating off it.
* Added **consuming route polyline**: the traveled portion dims (grey) while the remaining route stays highlighted (blue), shrinking the line as the ride progresses.
* Added `offRouteThreshold` parameter to configure the off-route distance (in meters, default `50`) that triggers an automatic re-route.
* More reliable auto re-routing: requires two consecutive off-route readings to avoid false triggers from GPS noise.
* Smoother marker movement: the animation duration now matches the GPS update rate, with a single rebuild per frame.
* Fixed competing location streams and a stacking compass listener that caused animation jank during rides.

## 0.1.4

* Added `bikeIconSize`, `pickupIconSize`, and `dropIconSize` parameters for custom marker sizes.
* Updated example and removed API key from the example for publishing.

## 0.1.3

* Initial release with route drawing, bike animation, and real-time navigation features.
* Fixed marker visibility during rides.
* Improved smooth bearing calculations for bike movements.
* Removed hardcoded API keys for security.

## 0.0.1

* Initial project setup.
