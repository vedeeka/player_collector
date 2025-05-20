import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  LatLng myPoint = const LatLng(15.41, 73.49); // Default fallback
  bool userLocationSet = false;
  bool isLoading = true;

  // Track visible marker types
  List<Map<String, dynamic>> allPlaces = [];
  List<String> selectedFilters = ['restaurants', 'exchanges', 'attractions'];

  // Animation controllers
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Schedule location fetching after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePosition();
    });

    // Finish loading immediately to show markers
    Future.delayed(Duration.zero, () {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  void _loadPlacesData() {
    // Dummy restaurants
    allPlaces.addAll([
      {
        "name": "Goa Spice Kitchen",
        "location": LatLng(latitude + 0.001, longitude),
        "rating": 4.7,
        "type": "restaurants",
        "description": "Authentic Goan cuisine with seafood specialties"
      },
      {
        "name": "Beach Bites Café",
        "location": LatLng(latitude - 0.003, longitude - 0.002),
        "rating": 4.2,
        "type": "restaurants",
        "description": "Casual beachside dining with continental options"
      },
      {
        "name": "Coastal Flavors",
        "location": LatLng(latitude - 0.007, longitude - 0.003),
        "rating": 4.5,
        "type": "restaurants",
        "description": "Fresh seafood and local delicacies"
      },
    ]);

    // Dummy currency exchanges
    allPlaces.addAll([
      {
        "name": "Forex Express",
        "location": LatLng(latitude - 0.01, longitude - 0.002),
        "rating": 4.0,
        "type": "exchanges",
        "description": "Competitive rates with multiple currencies available"
      },
      {
        "name": "Global Exchange Hub",
        "location": LatLng(latitude - 0.02, longitude - 0.02),
        "rating": 4.1,
        "type": "exchanges",
        "description": "Fast service with no hidden fees"
      },
    ]);

    // Dummy tourist attractions
    allPlaces.addAll([
      {
        "name": "Sunset Beach Point",
        "location": LatLng(latitude - 0.05, longitude - 0.005),
        "rating": 4.9,
        "type": "attractions",
        "description": "Beautiful sunset views and water activities"
      },
      {
        "name": "Heritage Museum",
        "location": LatLng(latitude - 0.012, longitude - 0.02),
        "rating": 4.6,
        "type": "attractions",
        "description": "Exhibits showcasing local history and culture"
      },
    ]);
  }

  double latitude = 0.0, longitude = 0.0;

  Future<void> _determinePosition() async {
    try {
      final position =
          await html.window.navigator.geolocation.getCurrentPosition();
      latitude = position.coords?.latitude as double;
      longitude = position.coords?.longitude as double;
      _loadPlacesData();

      LatLng userLocation = LatLng(latitude, longitude);

      // Create a map entry for the user
      final userPlace = {
        "name": "Your Location",
        "location": userLocation,
        "type": "user",
        "description": "You are here"
      };

      // Remove any existing user location
      allPlaces.removeWhere((place) => place["type"] == "user");

      if (mounted) {
        setState(() {
          myPoint = userLocation;
          userLocationSet = true;
          allPlaces.add(userPlace);
        });

        mapController.move(userLocation, 16.5);
      }
    } catch (error) {
      print('Error fetching location: $error');
    }
  }

  // Create marker from place data
  Widget _createMarkerWidget(Map<String, dynamic> place) {
    final IconData icon;
    final Color color;

    // Determine icon and color based on place type
    switch (place["type"]) {
      case "restaurants":
        icon = Icons.restaurant;
        color = Colors.redAccent;
        break;
      case "exchanges":
        icon = Icons.currency_exchange;
        color = Colors.greenAccent;
        break;
      case "attractions":
        icon = Icons.photo_camera;
        color = Colors.purpleAccent;
        break;
      case "user":
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.3),
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.2 + (_pulseController.value * 0.2)),
                    blurRadius: 10 + (_pulseController.value * 5),
                    spreadRadius: 2 + (_pulseController.value * 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue,
                ),
                child: const Icon(
                  Icons.person_pin_circle,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            );
          },
        );
      default:
        icon = Icons.place;
        color = Colors.blueAccent;
    }

    return GestureDetector(
      onTap: () => _showPlaceDetails(place),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }

  List<Marker> _getVisibleMarkers() {
    List<Marker> visibleMarkers = [];

    for (var place in allPlaces) {
      if (place["type"] == "user" || selectedFilters.contains(place["type"])) {
        visibleMarkers.add(
          Marker(
            point: place["location"] as LatLng,
            width: 60,
            height: 60,
            child: _createMarkerWidget(place),
          ),
        );
      }
    }

    return visibleMarkers;
  }

  void _showPlaceDetails(Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bottom sheet handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // Place details
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getColorForType(place["type"]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForType(place["type"]),
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          place["name"],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (place["rating"] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                place["rating"].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (place["description"] != null)
                    Text(
                      place["description"],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _actionButton(
                        icon: Icons.directions,
                        label: "Directions",
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Directions feature coming soon!"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      _actionButton(
                        icon: Icons.bookmark_border,
                        label: "Save",
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Location saved!"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      _actionButton(
                        icon: Icons.share,
                        label: "Share",
                        color: Colors.deepPurple,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Sharing feature coming soon!"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case "restaurants":
        return Icons.restaurant;
      case "exchanges":
        return Icons.currency_exchange;
      case "attractions":
        return Icons.photo_camera;
      case "user":
        return Icons.person_pin_circle;
      default:
        return Icons.place;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case "restaurants":
        return Colors.redAccent;
      case "exchanges":
        return Colors.greenAccent;
      case "attractions":
        return Colors.purpleAccent;
      case "user":
        return Colors.blue;
      default:
        return Colors.blueAccent;
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the current markers each time we build
    final currentMarkers = _getVisibleMarkers();

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: myPoint,
              initialZoom: 16,
              backgroundColor: const Color(0xFFE0F2F1),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'dev.flutter_map.example',
                tileBuilder: (context, tileWidget, tile) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    position: DecorationPosition.foreground,
                    child: tileWidget,
                  );
                },
              ),
              // Use the markers calculated in build
              MarkerLayer(markers: currentMarkers),
            ],
          ),

          // Top app bar
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios, size: 22),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "Explore Nearby",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (userLocationSet) {
                          mapController.move(myPoint, 16.5);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Unable to locate your position"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location,
                          size: 22,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filter chips
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: "Restaurants",
                    icon: Icons.restaurant,
                    color: Colors.redAccent,
                    isSelected: selectedFilters.contains('restaurants'),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedFilters.add('restaurants');
                        } else {
                          selectedFilters.remove('restaurants');
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    label: "Currency",
                    icon: Icons.currency_exchange,
                    color: Colors.greenAccent,
                    isSelected: selectedFilters.contains('exchanges'),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedFilters.add('exchanges');
                        } else {
                          selectedFilters.remove('exchanges');
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    label: "Attractions",
                    icon: Icons.photo_camera,
                    color: Colors.purpleAccent,
                    isSelected: selectedFilters.contains('attractions'),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedFilters.add('attractions');
                        } else {
                          selectedFilters.remove('attractions');
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text("Loading map data..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Legend button
          Positioned(
            bottom: 32,
            right: 16,
            child: Column(
              children: [
                // Zoom buttons
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // Zoom in
                      InkWell(
                        onTap: () {
                          final currentZoom = mapController.camera.zoom;
                          mapController.move(
                            mapController.camera.center,
                            currentZoom + 1,
                          );
                        },
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(Icons.add),
                        ),
                      ),
                      const Divider(height: 1),
                      // Zoom out
                      InkWell(
                        onTap: () {
                          final currentZoom = mapController.camera.zoom;
                          mapController.move(
                            mapController.camera.center,
                            currentZoom - 1,
                          );
                        },
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(Icons.remove),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Search nearby button
                FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  elevation: 4,
                  child: const Icon(Icons.search),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Search feature coming soon!"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        color: isSelected ? Colors.white : color,
        size: 16,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      backgroundColor: Colors.white,
      selectedColor: color,
      elevation: 2,
      pressElevation: 4,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : color.withOpacity(0.3),
        ),
      ),
      onSelected: onSelected,
    );
  }
}
