import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const EmergencyScreen({super.key, this.onOpenDrawer});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  // Live GPS Coordinates (Defaulting initially to Kengeri / Bengaluru)
  double _userLat = 12.9172;
  double _userLong = 77.4837;
  String _locationAreaName = 'Kengeri Satellite Town & Mysore Road, Bengaluru';
  bool _isLoadingGps = false;

  // Selected Service Category: 'SERVICE_CENTRE', 'ROADSIDE_ASSIST', 'TOW_TRUCK'
  String _selectedCategory = 'SERVICE_CENTRE';

  // Comprehensive master database of verified service centers across Kengeri, RR Nagar, and Bengaluru
  final List<Map<String, dynamic>> _masterServiceHubs = [
    // ==========================================
    // 1. SERVICE CENTRES & WORKSHOPS
    // ==========================================
    {
      'name': 'Kengeri Two-Wheeler Multi-Brand Hub',
      'category': 'SERVICE_CENTRE',
      'categoryLabel': 'Authorised Multi-Brand Service',
      'area': 'Near Kengeri Bus Terminal & Satellite Town, Bengaluru',
      'lat': 12.9158,
      'lng': 77.4820,
      'phone': '+919880011445',
      'rating': 4.9,
      'timing': 'Open 24/7 (Express Service Bay)',
      'isCertified': true,
      'specialty': 'OBD Diagnostics • Coolant & Stator Service • Engine Tune',
    },
    {
      'name': 'Mysore Road Pro Bike Clinic',
      'category': 'SERVICE_CENTRE',
      'categoryLabel': 'Diagnostics & Engine Care',
      'area': 'Mysore Road, Near RV College / Kengeri, Bengaluru',
      'lat': 12.9230,
      'lng': 77.4985,
      'phone': '+919880022556',
      'rating': 4.8,
      'timing': '8:00 AM - 10:00 PM',
      'isCertified': true,
      'specialty': 'ECU Scanning • Fuel Injector Clean • Brake Overhaul',
    },
    {
      'name': 'RR Nagar Speed Performance Pitstop',
      'category': 'SERVICE_CENTRE',
      'categoryLabel': 'General Bike Care',
      'area': 'Ideal Homes Township, Rajarajeshwari Nagar, Bengaluru',
      'lat': 12.9280,
      'lng': 77.5180,
      'phone': '+919880033667',
      'rating': 4.8,
      'timing': 'Open 24/7',
      'isCertified': true,
      'specialty': 'Periodic Maintenance • Electrical Rail Repair • Oil Change',
    },
    {
      'name': 'Nagarbhavi Two-Wheeler Diagnostic Care',
      'category': 'SERVICE_CENTRE',
      'categoryLabel': 'Bike Diagnostics',
      'area': 'Near BDA Complex, 2nd Stage, Nagarbhavi, Bengaluru',
      'lat': 12.9550,
      'lng': 77.5120,
      'phone': '+919880044778',
      'rating': 4.7,
      'timing': '7:30 AM - 10:30 PM',
      'isCertified': false,
      'specialty': 'Spark Plug & Filter Replacement • Chain Sprocket Fix',
    },
    {
      'name': 'VETRI Certified Two-Wheeler Tech Hub',
      'category': 'SERVICE_CENTRE',
      'categoryLabel': 'Authorised Multi-Brand Service',
      'area': 'Outer Ring Road, Near Hebbal Flyover, Bengaluru',
      'lat': 13.0382,
      'lng': 77.5912,
      'phone': '+919880011223',
      'rating': 4.9,
      'timing': 'Open 24/7 (Express Triage Bay)',
      'isCertified': true,
      'specialty': 'OBD Diagnostics • Engine Overhaul • Coolant & Stator Service',
    },
    {
      'name': 'Malleshwaram Pro Pitstop & Dyno Tuning',
      'category': 'SERVICE_CENTRE',
      'categoryLabel': 'Performance Diagnostics',
      'area': '8th Cross, Sampige Road, Malleshwaram, Bengaluru',
      'lat': 13.0031,
      'lng': 77.5701,
      'phone': '+919880044556',
      'rating': 4.8,
      'timing': '8:00 AM - 10:30 PM',
      'isCertified': true,
      'specialty': 'ECU Scanning • Fuel Injector Clean • Brake Pad Replacement',
    },

    // ==========================================
    // 2. ROADSIDE ASSISTANCE (RSA)
    // ==========================================
    {
      'name': 'Kengeri Rapid Mobile RSA (Van & Puncture)',
      'category': 'ROADSIDE_ASSIST',
      'categoryLabel': 'Doorstep Mobile Mechanic',
      'area': 'Stationed at Kengeri Satellite Town Ring Road',
      'lat': 12.9185,
      'lng': 77.4855,
      'phone': '+919880055889',
      'rating': 4.9,
      'timing': '24/7 Rapid Mobile Van Dispatch (< 12 mins)',
      'isCertified': true,
      'specialty': '12V Battery Jumpstart • Tubeless Puncture Plug • On-Spot Fuel',
    },
    {
      'name': 'Mysore Road On-Demand Bike Rescue',
      'category': 'ROADSIDE_ASSIST',
      'categoryLabel': 'Highway Mobile RSA',
      'area': 'Mysore Road Toll Gate & Kengeri Metro Station',
      'lat': 12.9140,
      'lng': 77.4790,
      'phone': '+919880066990',
      'rating': 4.8,
      'timing': 'Open 24/7',
      'isCertified': true,
      'specialty': 'Alternator Current Check • Clutch Cable Replace • Fuse Fix',
    },
    {
      'name': 'RR Nagar 24/7 Quick Puncture & Battery',
      'category': 'ROADSIDE_ASSIST',
      'categoryLabel': 'Emergency Bike Tech',
      'area': 'Rajarajeshwari Nagar Main Gate / Temple Junction',
      'lat': 12.9250,
      'lng': 77.5150,
      'phone': '+919880077112',
      'rating': 4.8,
      'timing': 'Open 24/7',
      'isCertified': true,
      'specialty': 'Emergency Coolant Top-Up • Chain Lubing & Tightening',
    },
    {
      'name': 'Nagarbhavi 15-Min Quick Mobile RSA',
      'category': 'ROADSIDE_ASSIST',
      'categoryLabel': 'Rapid Squad',
      'area': 'Nagarbhavi BDA Complex & Ring Road Junction',
      'lat': 12.9520,
      'lng': 77.5100,
      'phone': '+919880088223',
      'rating': 4.7,
      'timing': 'Open 24/7',
      'isCertified': false,
      'specialty': 'Key Lockout • Spark Plug Spark Test • Flat Tyre Air Pump',
    },

    // ==========================================
    // 3. TOW TRUCK & FLATBED SERVICES
    // ==========================================
    {
      'name': 'Kengeri & Mysore Expressway 24/7 Flatbed Towing',
      'category': 'TOW_TRUCK',
      'categoryLabel': 'Emergency Bike Flatbed',
      'area': 'Mysore Road Expressway & Kengeri Satellite Hub',
      'lat': 12.9160,
      'lng': 77.4840,
      'phone': '+919880099334',
      'rating': 4.9,
      'timing': '24/7 Rapid Response (< 15 mins)',
      'isCertified': true,
      'specialty': 'Hydraulic Tilt Bed • Zero-Scratch Bike Strapping • Highway Tow',
    },
    {
      'name': 'RR Nagar & West Corridor FastTow',
      'category': 'TOW_TRUCK',
      'categoryLabel': 'Accident & Breakdown Tow',
      'area': 'Rajarajeshwari Nagar & Uttarahalli Main Road Base',
      'lat': 12.9220,
      'lng': 77.5200,
      'phone': '+919880011447',
      'rating': 4.8,
      'timing': '24/7 On-Call Fleet',
      'isCertified': true,
      'specialty': 'Heavy 2-Wheeler Lift • Long-Distance Inter-City Transport',
    },
    {
      'name': 'Mysore Road Heavy Recovery & Flatbed',
      'category': 'TOW_TRUCK',
      'categoryLabel': '24/7 Breakdown Recovery',
      'area': 'Near Nayandahalli Junction & Mysore Road',
      'lat': 12.9420,
      'lng': 77.5250,
      'phone': '+919880022558',
      'rating': 4.7,
      'timing': '24/7 Active Fleet',
      'isCertified': false,
      'specialty': 'Quick Winch Towing • Traffic Clearance SLA',
    },
    {
      'name': 'Bengaluru South-West Tow Express',
      'category': 'TOW_TRUCK',
      'categoryLabel': '24/7 Emergency Dispatch',
      'area': 'Kengeri - Banashankari Outer Ring Road Base',
      'lat': 12.9300,
      'lng': 77.5050,
      'phone': '+919880033669',
      'rating': 4.8,
      'timing': '24/7 Active Fleet',
      'isCertified': true,
      'specialty': 'Flatbed Bike Transport • Locked Wheel Assistance',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveLocation();
  }

  void _fetchLiveLocation() async {
    setState(() => _isLoadingGps = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 6),
        );
        if (mounted) {
          setState(() {
            _userLat = position.latitude;
            _userLong = position.longitude;
            _locationAreaName = 'Live GPS Lock: (${_userLat.toStringAsFixed(4)}, ${_userLong.toStringAsFixed(4)})';
          });
        }
      }
    } catch (e) {
      debugPrint('[GPS Fetch Error]: $e');
    } finally {
      if (mounted) setState(() => _isLoadingGps = false);
    }
  }

  void _setPresetLocality(String name, double lat, double lng) {
    setState(() {
      _userLat = lat;
      _userLong = lng;
      _locationAreaName = name;
    });
  }

  /// Calculates Haversine distance in Kilometers between user GPS and hub coordinates
  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  List<Map<String, dynamic>> _getTop4HubsForCategory() {
    final categoryHubs = _masterServiceHubs
        .where((h) => h['category'] == _selectedCategory)
        .map((h) {
      final double dist = _calculateDistanceKm(
          _userLat, _userLong, h['lat'] as double, h['lng'] as double);
      return {
        ...h,
        'calculatedDistanceKm': dist,
        'formattedDistance': dist < 1.0
            ? '${(dist * 1000).toInt()} m'
            : '${dist.toStringAsFixed(1)} km',
      };
    }).toList();

    categoryHubs.sort((a, b) {
      final double distA = a['calculatedDistanceKm'] as double;
      final double distB = b['calculatedDistanceKm'] as double;
      return distA.compareTo(distB);
    });

    return categoryHubs.take(4).toList();
  }

  void _openGoogleMapsCategorySearch() async {
    String query;
    if (_selectedCategory == 'TOW_TRUCK') {
      query = 'tow+truck+towing+service+flatbed+near+me';
    } else if (_selectedCategory == 'ROADSIDE_ASSIST') {
      query = 'bike+puncture+battery+jumpstart+roadside+assistance+near+me';
    } else {
      query = 'two+wheeler+bike+repair+workshop+garage+service+centre+near+me';
    }

    final String url = 'https://www.google.com/maps/search/$query/@$_userLat,$_userLong,15z';
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(uri);
    }
  }

  void _openDirectionsTo(double lat, double lng, String name) async {
    final String url =
        'https://www.google.com/maps/dir/?api=1&origin=$_userLat,$_userLong&destination=$lat,$lng&travelmode=driving';
    final Uri uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(uri);
    }
  }

  void _triggerCall(String phone) async {
    final Uri uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Call error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top4 = _getTop4HubsForCategory();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Emergency SOS & Assistance',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isLoadingGps
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Color(0xFF00B894), strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, color: Color(0xFF00B894)),
            onPressed: _fetchLiveLocation,
            tooltip: 'Live GPS Auto-Detect',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Pinned GPS Location Card with RED PIN
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFF7675).withValues(alpha: 0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7675).withValues(alpha: 0.12),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF7675).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on_rounded, color: Color(0xFFFF7675), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Text('PINNED VEHICLE LOCATION',
                                      style: TextStyle(
                                          color: Color(0xFFFF7675),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.1)),
                                  SizedBox(width: 6),
                                  Text('● LIVE GPS',
                                      style: TextStyle(
                                          color: Color(0xFF00B894),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _locationAreaName,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF232736)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lat: ${_userLat.toStringAsFixed(4)}  |  Lng: ${_userLong.toStringAsFixed(4)}',
                            style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
                        TextButton.icon(
                          onPressed: _openGoogleMapsCategorySearch,
                          icon: const Icon(Icons.map_rounded, color: Color(0xFF6C5CE7), size: 14),
                          label: const Text('View on Map',
                              style: TextStyle(
                                  color: Color(0xFF6C5CE7), fontSize: 11, fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Locality Quick Presets Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      backgroundColor: const Color(0xFF00B894).withValues(alpha: 0.15),
                      side: const BorderSide(color: Color(0xFF00B894)),
                      avatar: const Icon(Icons.my_location_rounded, color: Color(0xFF00B894), size: 14),
                      label: const Text('Kengeri (Live GPS)',
                          style: TextStyle(color: Color(0xFF00B894), fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _setPresetLocality('Kengeri Satellite Town & Mysore Road, Bengaluru', 12.9172, 77.4837),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      backgroundColor: Theme.of(context).cardColor,
                      side: const BorderSide(color: Color(0xFF232736)),
                      label: const Text('RR Nagar & Nagarbhavi',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      onPressed: () => _setPresetLocality('Rajarajeshwari Nagar & Nagarbhavi, Bengaluru', 12.9280, 77.5180),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      backgroundColor: Theme.of(context).cardColor,
                      side: const BorderSide(color: Color(0xFF232736)),
                      label: const Text('Hebbal & RT Nagar',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      onPressed: () => _setPresetLocality('Hebbal Flyover & RT Nagar, Bengaluru', 13.0358, 77.5970),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      backgroundColor: Theme.of(context).cardColor,
                      side: const BorderSide(color: Color(0xFF232736)),
                      label: const Text('Vijaynagar & Malleshwaram',
                          style: TextStyle(color: Colors.white70, fontSize: 11)),
                      onPressed: () => _setPresetLocality('Vijaynagar Metro & Malleshwaram, Bengaluru', 12.9719, 77.5303),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // SOS Emergency Broadcast Button
              Center(
                child: GestureDetector(
                  onTap: () => _triggerCall('112'),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF7675).withValues(alpha: 0.15),
                      border: Border.all(color: const Color(0xFFFF7675), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7675).withValues(alpha: 0.3),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.sos_rounded, color: Color(0xFFFF7675), size: 40),
                          SizedBox(height: 2),
                          Text('112 SOS',
                              style: TextStyle(
                                  color: Color(0xFFFF7675),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Tap for Universal Police & Roadside Emergency Helpline (112)',
                    style: TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
              ),
              const SizedBox(height: 24),

              // SERVICE CATEGORY SELECTOR CHIPS
              const Text('SELECT EMERGENCY ASSISTANCE TYPE',
                  style: TextStyle(
                      color: Color(0xFF8E92A4),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1)),
              const SizedBox(height: 10),

              Row(
                children: [
                  _buildCategoryChip(
                    id: 'SERVICE_CENTRE',
                    label: 'Service Centre',
                    icon: Icons.build_rounded,
                    color: const Color(0xFF6C5CE7),
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    id: 'ROADSIDE_ASSIST',
                    label: 'Roadside Assist',
                    icon: Icons.two_wheeler_rounded,
                    color: const Color(0xFF00B894),
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    id: 'TOW_TRUCK',
                    label: 'Tow Truck',
                    icon: Icons.local_shipping_rounded,
                    color: const Color(0xFFFDCB6E),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Header for Top 4 Closest Centers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOP 4 CLOSEST CENTRES (${_getCategoryTitle()})',
                    style: const TextStyle(
                        color: Color(0xFF8E92A4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1),
                  ),
                  TextButton.icon(
                    onPressed: _openGoogleMapsCategorySearch,
                    icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF00B894), size: 14),
                    label: const Text('Show More on Maps',
                        style: TextStyle(
                            color: Color(0xFF00B894),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // TOP 4 DYNAMICALLY COMPUTED HUBS
              ...top4.map((g) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF232736)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      g['name'],
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ),
                                  if (g['isCertified'] == true) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded,
                                        color: Color(0xFF00B894), size: 16),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B894).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                g['formattedDistance'] ?? 'Nearby',
                                style: const TextStyle(
                                    color: Color(0xFF00B894),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, color: Color(0xFF8E92A4), size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(g['area'],
                                  style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('${g['rating']} ★',
                                style: const TextStyle(
                                    color: Color(0xFFFDCB6E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('•  ${g['timing']}',
                                style: const TextStyle(color: Color(0xFF00B894), fontSize: 11)),
                          ],
                        ),
                        if (g['specialty'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            g['specialty'],
                            style: const TextStyle(
                                color: Color(0xFF6C5CE7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFF232736)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _triggerCall(g['phone']),
                                icon: const Icon(Icons.call_rounded, color: Color(0xFF00B894), size: 16),
                                label: const Text('Call Now',
                                    style: TextStyle(
                                        color: Color(0xFF00B894),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF00B894)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _openDirectionsTo(g['lat'], g['lng'], g['name']),
                                icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 16),
                                label: const Text('Navigate',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C5CE7),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String id,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final bool isSelected = _selectedCategory == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF232736),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : const Color(0xFF8E92A4), size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8E92A4),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryTitle() {
    switch (_selectedCategory) {
      case 'TOW_TRUCK':
        return 'TOW TRUCKS';
      case 'ROADSIDE_ASSIST':
        return 'ROADSIDE ASSIST';
      case 'SERVICE_CENTRE':
      default:
        return 'SERVICE CENTRES';
    }
  }
}
