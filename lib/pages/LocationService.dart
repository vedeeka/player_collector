import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  
  factory LocationService() => _instance;
  
  LocationService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  Position? currentPosition;
  bool isLocationServiceEnabled = false;
  LocationPermission? permissionStatus;
  String? currentAddress;
  
  // Initialize notifications
  Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }
  
  // Check and request location permissions
  Future<bool> checkLocationPermission(BuildContext context) async {
    isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services to use this feature'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    
    permissionStatus = await Geolocator.checkPermission();
    if (permissionStatus == LocationPermission.denied) {
      permissionStatus = await Geolocator.requestPermission();
      if (permissionStatus == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
    }
    
    if (permissionStatus == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied, please enable them in settings'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    
    return true;
  }
  
  // Get current location and update in Firestore
  Future<Position?> getCurrentLocation(String userEmail) async {
    try {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Save user location to Firestore
      await _updateUserLocation(userEmail, currentPosition!);
      
      return currentPosition;
    } catch (e) {
      debugPrint("Error getting location: $e");
      return null;
    }
  }
  
  // Update user location in Firestore
  Future<void> _updateUserLocation(String userEmail, Position position) async {
    try {
      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        currentAddress = "${place.street}, ${place.locality}";
        
        // Update user location in database
        await _firestore.collection('users').doc(userEmail).set({
          'location': GeoPoint(
            position.latitude,
            position.longitude,
          ),
          'address': currentAddress,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error updating user location: $e");
    }
  }
  
  // Calculate distance between two points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
  
  // Show notification for nearby activity
  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'nearby_activities',
      'Nearby Activities',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      color: Color(0xFF6200EA),
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond, // Unique ID based on current time
      title,
      body,
      platformChannelSpecifics,
    );
  }
  
  // Listen for nearby activities and send notifications
  Stream<List<QueryDocumentSnapshot>> listenForActivities() {
    return _firestore.collection('activities')
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs);
  }
  
  // Check if an activity is nearby and should trigger notification
  Future<void> checkAndNotifyNearbyActivities(List<QueryDocumentSnapshot> activities, String userEmail) async {
    if (currentPosition == null) return;
    
    for (var doc in activities) {
      var activity = doc.data() as Map<String, dynamic>;
      
      // Skip if this activity has already been processed or doesn't have location data
      if (!activity.containsKey('geopoint') || 
          activity.containsKey('notifiedUsers') && 
          (activity['notifiedUsers'] as List<dynamic>).contains(userEmail)) {
        continue;
      }
      
      // Skip if this activity was created by the current user
      if (activity['createdBy'] == userEmail) {
        continue;
      }
      
      GeoPoint activityLocation = activity['geopoint'];
      
      // Calculate distance
      double distanceInMeters = calculateDistance(
        currentPosition!.latitude,
        currentPosition!.longitude,
        activityLocation.latitude,
        activityLocation.longitude,
      );
      
      // If activity is within 500m, notify user
      if (distanceInMeters <= 500) {
        String distanceText = '${distanceInMeters.toInt()}m';
        
        await showNotification(
          'Nearby ${activity['activity']}',
          "New activity $distanceText away: ${activity['description']}",
        );
        
        // Mark this user as notified for this activity
        await doc.reference.update({
          'notifiedUsers': FieldValue.arrayUnion([userEmail]),
        });
      }
    }
  }
  
  // Format distance text for display
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toInt()}m away';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)}km away';
    }
  }
}