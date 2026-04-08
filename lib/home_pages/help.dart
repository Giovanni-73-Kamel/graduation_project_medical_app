import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  // Map controller
  GoogleMapController? _mapController;

  // Location state
  LatLng? _currentLocation;
  bool _isLoading = true;
  String _errorMsg = '';

  // Filter state
  bool _showPharmacies = true;
  bool _showHospitals = true;

  // Markers for nearby places
  final Set<Marker> _markers = {};

  // Google Places API key
  final String _googleApiKey = "AIzaSyCGgNCUoaFT-csz9Cx2Der8YZ1SuJW4VSs";

  @override
  void initState() {
    super.initState();
    _getCurrentLocationAndFetchPlaces();
  }

  /// Get current user location and fetch nearby places
  Future<void> _getCurrentLocationAndFetchPlaces() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMsg = '';
      });

      // Get current location
      final position = await _determinePosition();
      _currentLocation = LatLng(position.latitude, position.longitude);

      // Fetch nearby places
      await _fetchNearbyPlaces();

      if (mounted)
        setState(() {
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
    }
  }

  /// Determine the current position of the device
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please enable location services.',
      );
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permissions are denied. Please grant location permissions.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable permissions in app settings.',
      );
    }

    // Get the current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Fetch nearby places from Google Places API
  Future<void> _fetchNearbyPlaces() async {
    if (_currentLocation == null) return;

    try {
      final Set<Marker> newMarkers = {};

      // Add current location marker
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );

      // Fetch pharmacies if enabled
      if (_showPharmacies) {
        final pharmacies = await _fetchPlacesByType('pharmacy', 'pharmacy');
        newMarkers.addAll(pharmacies);
      }

      // Fetch hospitals if enabled
      if (_showHospitals) {
        final hospitals = await _fetchPlacesByType('hospital', 'hospital');
        newMarkers.addAll(hospitals);
      }

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(newMarkers);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Error fetching places: ${e.toString()}';
        });
      }
    }
  }

  /// Fetch places by type from Google Places API
  Future<Set<Marker>> _fetchPlacesByType(
    String placeType,
    String markerType,
  ) async {
    final Set<Marker> markers = {};

    try {
      final url =
          'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${_currentLocation!.latitude},${_currentLocation!.longitude}'
          '&radius=5000' // 5km radius
          '&type=$placeType'
          '&key=$_googleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'] != null) {
          final places = data['results'] as List;

          for (int i = 0; i < places.length && i < 20; i++) {
            // Limit to 20 places
            final place = places[i];
            final location = place['geometry']['location'];
            final name = place['name'] ?? 'Unknown';
            final vicinity = place['vicinity'] ?? '';

            final markerId = '$markerType${place['place_id']}';
            final color = markerType == 'pharmacy'
                ? BitmapDescriptor.hueBlue
                : BitmapDescriptor.hueRed;

            markers.add(
              Marker(
                markerId: MarkerId(markerId),
                position: LatLng(location['lat'], location['lng']),
                infoWindow: InfoWindow(title: name, snippet: vicinity),
                icon: BitmapDescriptor.defaultMarkerWithHue(color),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching $placeType: $e');
    }

    return markers;
  }

  /// Toggle filter for place types
  void _toggleFilter(String type) {
    setState(() {
      if (type == 'pharmacy') _showPharmacies = !_showPharmacies;
      if (type == 'hospital') _showHospitals = !_showHospitals;
    });
    _fetchNearbyPlaces();
  }

  /// Refresh location and places
  Future<void> _refresh() async {
    await _getCurrentLocationAndFetchPlaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map
            if (_currentLocation != null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 14,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: false, // We'll use our own button
                zoomControlsEnabled: false, // We'll use our own controls
                mapType: MapType.normal,
              )
            else
              const Center(
                child: Text(
                  'Getting location...',
                  style: TextStyle(fontSize: 18),
                ),
              ),

            // Error overlay
            if (_errorMsg.isNotEmpty)
              Container(
                color: Colors.white.withOpacity(0.9),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $_errorMsg',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Floating Header & Filters
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map, color: AppColors.primary),
                        const SizedBox(width: 8),
                        const CustomText(
                          text: 'Nearby Services',
                          color: Colors.black87,
                          size: 18,
                          weight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filters
                  Row(
                    children: [
                      _buildFilterChip(
                        'Pharmacies',
                        _showPharmacies,
                        Colors.blue,
                        'pharmacy',
                      ),
                      const SizedBox(width: 10),
                      _buildFilterChip(
                        'Hospitals',
                        _showHospitals,
                        Colors.red,
                        'hospital',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Refresh button
            Positioned(
              bottom: 100,
              right: 20,
              child: FloatingActionButton(
                onPressed: _refresh,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ),

            // Loading indicator
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isActive,
    Color color,
    String type,
  ) {
    return InkWell(
      onTap: () => _toggleFilter(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : Colors.grey.shade400),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Icon(Icons.check, color: Colors.white, size: 16)
            else
              Icon(Icons.circle, color: color, size: 12),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
