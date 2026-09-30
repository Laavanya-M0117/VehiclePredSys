import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/app_state_provider.dart';
import 'home_dashboard_screen.dart';
import 'diagnostics_screen.dart';
import 'alerts_screen.dart';
import 'history_screen.dart';
import 'subscription_screen.dart';
import 'profile_screen.dart';
import 'emergency_screen.dart';
import 'ble_pairing_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _requestInitialLocationPermission();
  }

  void _requestInitialLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      }
    } catch (e) {
      debugPrint('[Location Init]: $e');
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _navigateToIndex(int index) {
    Navigator.of(context).pop();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final isDark = provider.themeMode == ThemeMode.dark;

    final List<Widget> screens = [
      HomeDashboardScreen(onOpenDrawer: _openDrawer),
      DiagnosticsScreen(onOpenDrawer: _openDrawer),
      AlertsScreen(onOpenDrawer: _openDrawer),
      HistoryScreen(onOpenDrawer: _openDrawer),
      SubscriptionScreen(onOpenDrawer: _openDrawer, isRootPage: true),
      ProfileScreen(onOpenDrawer: _openDrawer),
      EmergencyScreen(onOpenDrawer: _openDrawer),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildNavigationDrawer(context, provider, isDark),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF232736) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex > 4 ? 0 : _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF6C5CE7),
          unselectedItemColor: const Color(0xFF8E92A4),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.speed_rounded),
              label: 'Diagnostics',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: provider.activeAlerts.isNotEmpty,
                label: Text('${provider.activeAlerts.length}'),
                backgroundColor: const Color(0xFFFF7675),
                child: const Icon(Icons.warning_amber_rounded),
              ),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_rounded),
              label: 'Plans',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context, AppStateProvider provider, bool isDark) {
    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161922) : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF232736) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.speed_rounded, color: Color(0xFF6C5CE7), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'VETRI',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    provider.displayName.isNotEmpty ? provider.displayName : 'VETRI Rider',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.userEmail.isNotEmpty
                        ? provider.userEmail
                        : (provider.phoneNumber.isNotEmpty ? provider.phoneNumber : 'Profile Incomplete'),
                    style: TextStyle(
                      color: (provider.userEmail.isNotEmpty || provider.phoneNumber.isNotEmpty)
                          ? const Color(0xFF8E92A4)
                          : const Color(0xFFFDCB6E),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D0E15) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF232736) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded, color: Color(0xFF00B894), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${provider.vehicleName} • ${provider.odometerKm} km',
                            style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Home Dashboard',
                    index: 0,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.speed_rounded,
                    title: 'Live Diagnostics & Graphs',
                    index: 1,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.warning_amber_rounded,
                    title: 'Fault Alerts & Triage',
                    index: 2,
                    badgeCount: provider.activeAlerts.length,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    title: 'History',
                    index: 3,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Subscription Plans',
                    index: 4,
                    highlightColor: const Color(0xFFFDCB6E),
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_rounded,
                    title: 'Profile & Vehicle Settings',
                    index: 5,
                    hasAlert: provider.isProfileIncomplete,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.emergency_rounded,
                    title: 'Emergency SOS & Garages',
                    index: 6,
                    highlightColor: const Color(0xFFFF7675),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Bottom Section: Theme toggle & Sign out
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161922) : const Color(0xFFF1F5F9),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF232736) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: const Color(0xFF6C5CE7),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isDark ? 'Dark Mode' : 'Light Mode',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isDark,
                        activeThumbColor: const Color(0xFF6C5CE7),
                        onChanged: (val) {
                          provider.toggleThemeMode(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        provider.signOut();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const BlePairingScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF7675), size: 18),
                      label: const Text('Sign Out & Unpair',
                          style: TextStyle(
                              color: Color(0xFFFF7675), fontSize: 13, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF7675)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
    Color? highlightColor,
    int? badgeCount,
    bool hasAlert = false,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final color = highlightColor ??
        (isSelected ? const Color(0xFF6C5CE7) : const Color(0xFF8E92A4));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.4))
            : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF6C5CE7)
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7675),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : (hasAlert
                ? const Icon(Icons.error_outline_rounded, color: Color(0xFFFDCB6E), size: 18)
                : null),
        onTap: () => _navigateToIndex(index),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
