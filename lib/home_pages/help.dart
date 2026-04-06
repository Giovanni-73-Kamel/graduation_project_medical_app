import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  bool _isLoading = true;
  String _errorMsg = '';

  // Filter state
  bool _showPharmacies = true;
  bool _showHospitals = true;

  // Placeholder for API key
  final String _googleApiKey = "AIzaSyCGgNCUoaFT-csz9Cx2Der8YZ1SuJW4VSs";

  @override
  void initState() {
    super.initState();
    _fetchNearbyPlaces();
  }

  /// Mocked API fetch without maps
  Future<void> _fetchNearbyPlaces() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMsg = '';
      });

      // Mock data since no Maps
      await Future.delayed(const Duration(seconds: 1)); // simulate API delay

      if (mounted) setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _errorMsg = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleFilter(String type) {
    setState(() {
      if (type == 'pharmacy') _showPharmacies = !_showPharmacies;
      if (type == 'hospital') _showHospitals = !_showHospitals;
    });
    _fetchNearbyPlaces();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _errorMsg.isNotEmpty
                  ? Text('Error: $_errorMsg')
                  : const Text(
                'Map feature removed',
                style: TextStyle(fontSize: 18),
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
                        )
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
                      _buildFilterChip('Pharmacies', _showPharmacies, Colors.blue, 'pharmacy'),
                      const SizedBox(width: 10),
                      _buildFilterChip('Hospitals', _showHospitals, Colors.red, 'hospital'),
                    ],
                  ),
                ],
              ),
            ),
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

  Widget _buildFilterChip(String label, bool isActive, Color color, String type) {
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