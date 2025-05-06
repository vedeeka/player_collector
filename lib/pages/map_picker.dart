import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapPicker extends StatefulWidget {
  const MapPicker({Key? key}) : super(key: key);

  @override
  State<MapPicker> createState() => _MapPickerState();
}

class _MapPickerState extends State<MapPicker> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;

  Future<LatLng> _getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return LatLng(position.latitude, position.longitude);
  }

  Future<String> _getAddressFromLatLng(LatLng location) async {
    final placemarks = await placemarkFromCoordinates(
        location.latitude, location.longitude);
    final place = placemarks.first;
    return "${place.name}, ${place.locality}, ${place.country}";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LatLng>(
      future: _getCurrentPosition(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        return Scaffold(
          appBar: AppBar(title: const Text('Select Location')),
          body: GoogleMap(
            initialCameraPosition: CameraPosition(target: snapshot.data!, zoom: 15),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (LatLng latLng) async {
              setState(() {
                _pickedLocation = latLng;
              });
            },
            markers: _pickedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLocation!,
                    )
                  }
                : {},
          ),
          floatingActionButton: _pickedLocation != null
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final address = await _getAddressFromLatLng(_pickedLocation!);
                    Navigator.pop(context, address);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text("Select"),
                )
              : null,
        );
      },
    );
  }
}
