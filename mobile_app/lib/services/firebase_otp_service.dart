import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OTP Verification result model
class OtpVerificationResult {
  final bool success;
  final String? verificationId;
  final String? errorMessage;
  final String? internalOtpForTesting;

  const OtpVerificationResult({
    required this.success,
    this.verificationId,
    this.errorMessage,
    this.internalOtpForTesting,
  });
}

/// Official Twilio Verify Service Engine for VETRI App
class FirebaseOtpService {
  static final FirebaseOtpService _instance = FirebaseOtpService._internal();
  factory FirebaseOtpService() => _instance;
  FirebaseOtpService._internal();

  // ─── CONFIGURABLE TWILIO VERIFY CREDENTIALS ────────────────────────────
  // Can be injected via --dart-define or configured at runtime
  static String _twilioAccountSid = const String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: 'AC_MOCK_TWILIO_ACCOUNT_SID');
  static String _twilioAuthToken  = const String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: 'MOCK_TWILIO_AUTH_TOKEN');
  static String _verifyServiceSid = const String.fromEnvironment('TWILIO_VERIFY_SERVICE_SID', defaultValue: 'VA_MOCK_VERIFY_SERVICE_SID');

  static void configureCredentials({String? accountSid, String? authToken, String? verifySid}) {
    if (accountSid != null) _twilioAccountSid = accountSid;
    if (authToken != null) _twilioAuthToken = authToken;
    if (verifySid != null) _verifyServiceSid = verifySid;
  }
  // ─────────────────────────────────────────────────────────────────────────

  /// Formats raw 10-digit number to E.164 (+91XXXXXXXXXX)
  String formatE164(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return rawPhone.startsWith('+') ? rawPhone : '+$rawPhone';
  }

  /// Sends a REAL 6-digit OTP SMS to the phone number via Twilio Verify API
  Future<OtpVerificationResult> sendOtp(String phoneNumber) async {
    final e164 = formatE164(phoneNumber);

    try {
      final url = Uri.parse(
          'https://verify.twilio.com/v2/Services/$_verifyServiceSid/Verifications');

      final credentials = base64Encode(
          utf8.encode('$_twilioAccountSid:$_twilioAuthToken'));

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'To': e164,
              'Channel': 'sms',
            },
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      debugPrint('[Twilio Verify Send] Status: ${response.statusCode} | Body: $body');

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          body['status'] != null) {
        return OtpVerificationResult(
          success: true,
          verificationId: e164, // E.164 phone is the lookup key in Twilio Verify
        );
      } else {
        final errMsg = body['message']?.toString() ?? 'Failed to dispatch SMS verification.';
        return OtpVerificationResult(success: false, errorMessage: errMsg);
      }
    } on TimeoutException {
      return const OtpVerificationResult(
          success: false,
          errorMessage: 'SMS gateway timed out. Please check your network connection.');
    } catch (e) {
      return OtpVerificationResult(
          success: false, errorMessage: 'Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verifies the 6-digit SMS code with Twilio Verify API
  Future<OtpVerificationResult> verifyCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final cleanCode = smsCode.trim();
    if (cleanCode.length != 6) {
      return const OtpVerificationResult(
        success: false,
        errorMessage: 'Please enter the 6-digit verification code received via SMS.',
      );
    }

    // Developer instant bypass code for quick debugging
    if (cleanCode == '123456') {
      return OtpVerificationResult(success: true, verificationId: verificationId);
    }

    try {
      final url = Uri.parse(
          'https://verify.twilio.com/v2/Services/$_verifyServiceSid/VerificationCheck');

      final credentials = base64Encode(
          utf8.encode('$_twilioAccountSid:$_twilioAuthToken'));

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'To': verificationId, // Phone in E.164 format
              'Code': cleanCode,
            },
          )
          .timeout(const Duration(seconds: 15));

      final body = jsonDecode(response.body);
      debugPrint('[Twilio Verify Check] Status: ${response.statusCode} | Body: $body');

      if (response.statusCode == 200 && body['status'] == 'approved') {
        return OtpVerificationResult(
          success: true,
          verificationId: verificationId,
        );
      } else {
        final msg = body['message']?.toString() ?? 'Invalid verification code. Please check and retry.';
        return OtpVerificationResult(success: false, errorMessage: msg);
      }
    } on TimeoutException {
      return const OtpVerificationResult(
          success: false,
          errorMessage: 'Verification timed out. Please try again.');
    } catch (e) {
      return OtpVerificationResult(
          success: false, errorMessage: 'Verification error: ${e.toString()}');
    }
  }

  /// Sends an emergency breakdown SMS alert via Twilio Messages API
  Future<bool> sendEmergencySmsAlert(String toPhone, String alertMessage) async {
    final e164 = formatE164(toPhone);
    try {
      final url = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json');
      final credentials = base64Encode(
          utf8.encode('$_twilioAccountSid:$_twilioAuthToken'));

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {
              'From': '+17372508034',
              'To': e164,
              'Body': '[VETRI EMERGENCY ALERT] $alertMessage. Please pull over safely and consult the app triage guidance.',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[Twilio Alert SMS] Status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[Twilio Alert SMS Error]: $e');
      return false;
    }
  }
}
