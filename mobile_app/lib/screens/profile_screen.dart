import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import 'subscription_screen.dart';
import 'ble_pairing_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const ProfileScreen({super.key, this.onOpenDrawer});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _showEditProfileDialog(AppStateProvider provider) {
    final nameCtrl = TextEditingController(text: provider.displayName);
    final emailCtrl = TextEditingController(text: provider.userEmail);
    final phoneCtrl = TextEditingController(text: provider.phoneNumber);
    final vehicleCtrl = TextEditingController(text: provider.vehicleName);
    final vinCtrl = TextEditingController(text: provider.vehicleVin);
    final odoCtrl = TextEditingController(text: provider.odometerKm.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Edit Profile & Vehicle',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: TextStyle(color: Color(0xFF8E92A4))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'name@gmail.com',
                      hintStyle: TextStyle(color: Color(0xFF5A5E73)),
                      labelStyle: TextStyle(color: Color(0xFF8E92A4))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Phone Number (SMS / OTP)',
                      hintText: '+91 9876543210',
                      hintStyle: TextStyle(color: Color(0xFF5A5E73)),
                      labelStyle: TextStyle(color: Color(0xFF8E92A4))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vehicleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Name',
                      labelStyle: TextStyle(color: Color(0xFF8E92A4))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vinCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'VIN',
                      labelStyle: TextStyle(color: Color(0xFF8E92A4))),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: odoCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      labelText: 'Odometer (km)',
                      labelStyle: TextStyle(color: Color(0xFF8E92A4))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E92A4))),
            ),
            ElevatedButton(
              onPressed: () {
                provider.updateUserProfile(
                  nameCtrl.text.trim(),
                  emailCtrl.text.trim(),
                  newPhone: phoneCtrl.text.trim(),
                );
                provider.updateVehicleDetails(
                  vehicleCtrl.text.trim(),
                  vinCtrl.text.trim(),
                  int.tryParse(odoCtrl.text) ?? provider.odometerKm,
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile saved successfully!'),
                    backgroundColor: Color(0xFF00B894),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
              child: const Text('Save Changes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final bool isDarkMode = provider.themeMode == ThemeMode.dark;

    final bool hasEmail = provider.userEmail.trim().isNotEmpty;
    final bool hasPhone = provider.phoneNumber.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
          onPressed: widget.onOpenDrawer ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Profile & Account',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF6C5CE7)),
            onPressed: () => _showEditProfileDialog(provider),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Card Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                      child: Text(
                        provider.displayName.isNotEmpty ? provider.displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                            color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.displayName,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasEmail
                                ? provider.userEmail
                                : (hasPhone ? provider.phoneNumber : 'Profile Incomplete'),
                            style: TextStyle(
                              color: (hasEmail || hasPhone)
                                  ? const Color(0xFF8E92A4)
                                  : const Color(0xFFFDCB6E),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B894).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              provider.subscriptionTier,
                              style: const TextStyle(
                                  color: Color(0xFF00B894),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Complete Profile Banner if phone or email missing
              if (provider.isProfileIncomplete) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDCB6E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDCB6E).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFDCB6E), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Complete Your Profile',
                                style: TextStyle(
                                    color: Color(0xFFFDCB6E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              'Missing: ${provider.missingProfileFields.join(", ")}. Add your mobile number for emergency SMS & verification.',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _showEditProfileDialog(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDCB6E),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Add',
                            style: TextStyle(
                                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Subscription Section Tile
              _buildSectionTitle('Subscription & Billing'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: Color(0xFF6C5CE7), size: 24),
                  ),
                  title: const Text('Subscription Plans',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text('Active: ${provider.subscriptionTier} • Tap to view duration plans',
                      style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF8E92A4), size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Contact & Personal Details
              _buildSectionTitle('Personal & Contact Info'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF6C5CE7)),
                      title: const Text('Full Name', style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12)),
                      subtitle: Text(provider.displayName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF6C5CE7), size: 18),
                        onPressed: () => _showEditProfileDialog(provider),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF232736)),
                    ListTile(
                      leading: const Icon(Icons.email_outlined, color: Color(0xFF6C5CE7)),
                      title: const Text('Email Address', style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12)),
                      subtitle: hasEmail
                          ? Text(provider.userEmail,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))
                          : const Text('⚠️ Not Set (Required for PDF Reports)',
                              style: TextStyle(
                                  color: Color(0xFFFDCB6E), fontWeight: FontWeight.w600, fontSize: 13)),
                      trailing: !hasEmail
                          ? TextButton(
                              onPressed: () => _showEditProfileDialog(provider),
                              child: const Text('Add',
                                  style: TextStyle(
                                      color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold)),
                            )
                          : null,
                    ),
                    const Divider(height: 1, color: Color(0xFF232736)),
                    ListTile(
                      leading: const Icon(Icons.phone_android_rounded, color: Color(0xFF00B894)),
                      title: const Text('Registered Phone (SMS / OTP)', style: TextStyle(color: Color(0xFF8E92A4), fontSize: 12)),
                      subtitle: hasPhone
                          ? Text(provider.phoneNumber,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))
                          : const Text('⚠️ Not Set (Required for Emergency SMS)',
                              style: TextStyle(
                                  color: Color(0xFFFDCB6E), fontWeight: FontWeight.w600, fontSize: 13)),
                      trailing: !hasPhone
                          ? TextButton(
                              onPressed: () => _showEditProfileDialog(provider),
                              child: const Text('Add',
                                  style: TextStyle(
                                      color: Color(0xFF00B894), fontWeight: FontWeight.bold)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Vehicle Details Section
              _buildSectionTitle('Registered Vehicle'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.directions_car_rounded, color: Color(0xFF00B894)),
                      title: Text(provider.vehicleName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(
                        'Type: ${provider.vehicleType}\nVIN: ${provider.vehicleVin}\nOdometer: ${provider.odometerKm} km',
                        style: const TextStyle(color: Color(0xFF8E92A4), fontSize: 12),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Color(0xFF6C5CE7), size: 18),
                        onPressed: () => _showEditProfileDialog(provider),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Notifications Settings
              _buildSectionTitle('Notification Preferences'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF232736)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF6C5CE7)),
                      title: const Text('Push Telemetry Alerts',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Real-time notification on DTC fault detection',
                          style: TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
                      value: provider.pushNotifications,
                      activeThumbColor: const Color(0xFF6C5CE7),
                      onChanged: (val) => provider.updateNotificationSettings(push: val),
                    ),
                    const Divider(height: 1, color: Color(0xFF232736)),
                    SwitchListTile(
                      secondary: const Icon(Icons.sms_outlined, color: Color(0xFF00B894)),
                      title: const Text('Emergency SMS Triage',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Send instant SMS alert to emergency contacts on CRITICAL risk',
                          style: TextStyle(color: Color(0xFF8E92A4), fontSize: 11)),
                      value: provider.criticalSmsAlerts,
                      activeThumbColor: const Color(0xFF00B894),
                      onChanged: (val) => provider.updateNotificationSettings(sms: val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    provider.signOut();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const BlePairingScreen()),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF7675)),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: Color(0xFFFF7675), fontWeight: FontWeight.bold, fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFF7675)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF8E92A4),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
    );
  }
}
