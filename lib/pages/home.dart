import 'dart:async'; // For TimeoutException

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For PlatformException
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

import 'package:player_collector/pages/profile.dart'; // Assuming this page exists
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  final String email; // This is passed but not directly used in HomePage state
  const HomePage({Key? key, required this.email}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class MapPickerPage extends StatefulWidget {
  final Function(String) onPick;

  const MapPickerPage({super.key, required this.onPick});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng _pickedLocation = const LatLng(37.4219999, -122.0840575); // default (Googleplex)
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocationForInitialMap();
  }

  Future<void> _getCurrentLocationForInitialMap() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Use default if service disabled, or prompt user
        print("Location service disabled, using default map location.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
         // Use default if permission denied, or prompt user
        print("Location permission denied, using default map location.");
        return;
      }
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium
      );
      setState(() {
        _pickedLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_pickedLocation),
      );
    } catch (e) {
      print("Error getting current location for map init: $e");
      // Keep default location
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation,
              zoom: 15,
            ),
            onMapCreated: (controller) {
                _mapController = controller;
            },
            onTap: (latLng) {
              setState(() => _pickedLocation = latLng);
            },
            markers: {
              Marker(
                markerId: const MarkerId("selected"),
                position: _pickedLocation,
                infoWindow: InfoWindow(title: "Selected Location")
              ),
            },
            myLocationEnabled: true, // Show current location button if available
            myLocationButtonEnabled: true,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () async {
                if (_pickedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please pick a location on the map.")),
                  );
                  return;
                }
                try {
                  final placemarks = await placemarkFromCoordinates(
                    _pickedLocation.latitude,
                    _pickedLocation.longitude,
                  );
                  if (placemarks.isNotEmpty) {
                    final place = placemarks.first;
                    // Construct a more robust location name
                    String name = place.name ?? '';
                    String street = place.thoroughfare ?? '';
                    String subLocality = place.subLocality ?? '';
                    String locality = place.locality ?? ''; // City
                    
                    List<String> parts = [];
                    if (name.isNotEmpty && name != street && !street.contains(name)) parts.add(name);
                    if (street.isNotEmpty) parts.add(street);
                    if (subLocality.isNotEmpty && subLocality != locality) parts.add(subLocality);
                    if (locality.isNotEmpty) parts.add(locality);

                    String locationName = parts.where((p) => p.isNotEmpty).join(', ');
                    if (locationName.isEmpty) locationName = "Unnamed Location";

                    widget.onPick(locationName);
                    Navigator.pop(context);
                  } else {
                    widget.onPick("Unknown Location (no details)");
                     Navigator.pop(context);
                  }
                } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Could not get address: $e")),
                  );
                  widget.onPick("Error getting address"); // Fallback
                  Navigator.pop(context);
                }

              },
              child: const Text("Confirm Location"),
            ),
          ),
        ],
      ),
    );
  }
}

class LocationPickerSheet extends StatelessWidget {
  final Function(String) onLocationSelected;

  const LocationPickerSheet({super.key, required this.onLocationSelected});

  Future<void> _handleGetCurrentLocation(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled. Please enable them in settings.')),
      );
      onLocationSelected("Location services disabled"); // Provide feedback
      return;
    }

    // 2. Check for permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions were denied.')),
        );
        onLocationSelected("Permission denied"); // Provide feedback
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Location permissions are permanently denied. Please enable them in app settings.')),
      );
      onLocationSelected("Permission denied forever"); // Provide feedback
      Geolocator.openAppSettings(); // Optionally open app settings
      return;
    }

    // 3. When we reach here, permissions are granted (or were already granted).
    try {
      // Show a loading indicator if you want, before this call
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching current location...')),
      );

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 20), // Timeout after 20 seconds
      );

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String name = place.name ?? '';
        String street = place.thoroughfare ?? '';
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? ''; // City
        
        List<String> parts = [];
        if (name.isNotEmpty && name != street && !street.contains(name)) parts.add(name);
        if (street.isNotEmpty) parts.add(street);
        if (subLocality.isNotEmpty && subLocality != locality) parts.add(subLocality);
        if (locality.isNotEmpty) parts.add(locality);

        String locationName = parts.where((p) => p.isNotEmpty).join(', ');
        if (locationName.isEmpty) {
          locationName = "Current Location (details unavailable)";
           if (locality.isNotEmpty) locationName = locality;
           else if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) locationName = place.administrativeArea!;
        }

        onLocationSelected(locationName);
      } else {
        onLocationSelected("Could not determine address at current location");
      }
    } on TimeoutException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting location timed out. Please try again or select on map.')),
      );
      onLocationSelected("Location timeout");
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.message}. Ensure GPS is on and you have a clear view of the sky.')),
      );
      onLocationSelected("Error: ${e.code}");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
      onLocationSelected("Error   $e ");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        ListTile(
          leading: const Icon(Icons.my_location),
          title: const Text("Use Current Location"),
          onTap: () async {
            Navigator.pop(context); // Pop the sheet first
            await _handleGetCurrentLocation(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.map),
          title: const Text("Select on Map"),
          onTap: () {
            Navigator.pop(context); // Pop the sheet first
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapPickerPage(onPick: onLocationSelected),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _peopleNeededController = TextEditingController();
  // REMOVED: _HomePageState createState() => _HomePageState(); // This was a typo

  void _showCreateActivityDialog() {
    // Clear controllers when dialog is opened
    _clearControllers();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView( // Added SingleChildScrollView
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Create Activity",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _activityController,
                    decoration: InputDecoration(
                      labelText: "Activity Type",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.sports_soccer), // Changed icon
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      // Hide keyboard before showing bottom sheet
                      FocusScope.of(context).requestFocus(FocusNode());
                      showModalBottomSheet(
                        context: context, // Use the builder context for the sheet
                        builder: (sheetContext) => LocationPickerSheet(
                          onLocationSelected: (location) {
                            setState(() { // Ensure UI updates if needed
                              _locationController.text = location;
                            });
                          },
                        ),
                      );
                    },
                    child: AbsorbPointer( // Use AbsorbPointer instead of IgnorePointer for better practice here
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: "Location",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        readOnly: true, // Make it read-only as it's populated by picker
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _peopleNeededController,
                    decoration: InputDecoration(
                      labelText: "People Needed",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.people_alt_outlined), // Changed icon
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                       prefixIcon: const Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_activityController.text.isEmpty ||
                          _locationController.text.isEmpty ||
                          _peopleNeededController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill all required fields (Activity, Location, People Needed).')),
                        );
                        return;
                      }
                      if (int.tryParse(_peopleNeededController.text) == null || int.parse(_peopleNeededController.text) <=0) {
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('People needed must be a valid positive number.')),
                        );
                        return;
                      }


                      final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      if (currentUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You need to be logged in to post an activity.')),
                        );
                        return;
                      }

                      try {
                        await _firestore.collection('activities').add({
                          'activity': _activityController.text,
                          'description': _descriptionController.text,
                          'location': _locationController.text,
                          'peopleNeeded': int.parse(_peopleNeededController.text),
                          'timestamp': FieldValue.serverTimestamp(),
                          'creatorId': currentUserId, // Store creator ID
                          'joinedUsers': [currentUserId], // Creator auto-joins
                        });
                        Navigator.pop(context); // Pop the bottom sheet
                        _clearControllers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Activity posted successfully!')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error posting activity: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0), // Purple
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16, color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Post Activity",
                      style: TextStyle(color: Colors.white), // Ensure text is white
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _clearControllers() {
    _activityController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _peopleNeededController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF9C27B0), // Purple
        title: const Text('Activity Feed', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white), // For drawer icon if any
        actionsIconTheme: const IconThemeData(color: Colors.white), // For action icons
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle), // Changed to account_circle
            onPressed: () {
              // Assuming ProfilePage takes the current user's email or ID
              // You might want to fetch user data based on widget.email or currentUserId
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(name: widget.email), // Or pass user ID
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('activities').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No activities found. Be the first to create one!'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var activity = doc.data() as Map<String, dynamic>;
              var timestamp = activity['timestamp'] as Timestamp?;
              var joinedUsers = List<String>.from(activity['joinedUsers'] ?? []);
              var creatorId = activity['creatorId'] as String?;
              bool isCurrentUserJoined = currentUserId != null && joinedUsers.contains(currentUserId);
              bool isCurrentUserCreator = currentUserId != null && creatorId == currentUserId;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(
                        activity['activity'] ?? 'Unnamed Activity',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: timestamp != null
                          ? Text(DateFormat.yMMMd().add_jm().format(timestamp.toDate()), style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: isCurrentUserCreator ? PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          // Add 'edit' later if needed
                        ],
                        onSelected: (value) async {
                          if (value == 'delete') {
                            // Optional: Show confirmation dialog
                            await doc.reference.delete();
                             ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Activity deleted.')),
                            );
                          }
                        },
                      ) : null, // Only show menu if current user is the creator
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activity['location'] != null && (activity['location'] as String).isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[700]),
                                const SizedBox(width: 4),
                                Expanded(child: Text(activity['location'], style: TextStyle(color: Colors.grey[700]))),
                              ],
                            ),
                          const SizedBox(height: 8),
                          if (activity['description'] != null && (activity['description'] as String).isNotEmpty)
                             Text(activity['description']),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Chip(
                                avatar: Icon(Icons.group_add_outlined, size: 16, color: Colors.purple[700]),
                                label: Text("${activity['peopleNeeded']} needed", style: TextStyle(color: Colors.purple[700])),
                                backgroundColor: Colors.purple[50],
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 8),
                              Chip(
                                avatar: Icon(Icons.how_to_reg_outlined, size: 16, color: Colors.green[700]),
                                label: Text("${joinedUsers.length} joined", style: TextStyle(color: Colors.green[700])),
                                backgroundColor: Colors.green[50],
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16,0,16,8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Use spaceBetween
                        children: [
                          if (currentUserId != null && !isCurrentUserCreator) // Don't show join for creator
                            TextButton.icon(
                              icon: Icon(
                                isCurrentUserJoined ? Icons.person_remove_alt_1_outlined : Icons.person_add_alt_1_outlined,
                                color: isCurrentUserJoined ? Colors.redAccent : Theme.of(context).primaryColor,
                              ),
                              label: Text(isCurrentUserJoined ? "Leave" : "Join", style: TextStyle(color: isCurrentUserJoined ? Colors.redAccent : Theme.of(context).primaryColor)),
                              onPressed: () async {
                                if (currentUserId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please log in to join/leave activities.')),
                                  );
                                  return;
                                }
                                if (isCurrentUserJoined) {
                                  await doc.reference.update({
                                    'joinedUsers': FieldValue.arrayRemove([currentUserId])
                                  });
                                } else {
                                  await doc.reference.update({
                                    'joinedUsers': FieldValue.arrayUnion([currentUserId])
                                  });
                                }
                              },
                            ),
                           if (isCurrentUserCreator) // Placeholder for creator actions
                             Text("You created this", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),

                          TextButton.icon( // Keep comment and share for all
                            icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[600]),
                            label: Text("Comment", style: TextStyle(color: Colors.grey[600])),
                            onPressed: () { /* Add comment functionality */ },
                          ),
                          TextButton.icon(
                            icon: Icon(Icons.share_outlined, color: Colors.grey[600]),
                            label: Text("Share", style: TextStyle(color: Colors.grey[600])),
                            onPressed: () { /* Add share functionality */ },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateActivityDialog,
        backgroundColor: const Color(0xFF9C27B0), // Purple
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create Activity',
      ),
    );
  }

  @override
  void dispose() {
    _activityController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _peopleNeededController.dispose();
    super.dispose();
  }
}

