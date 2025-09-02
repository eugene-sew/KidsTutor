import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/tts_config.dart';

/// Amazon Polly Text-to-Speech service
class PollyTtsService {
  static const String _endpoint = 'polly.us-east-1.amazonaws.com';
  static const String _service = 'polly';
  static const String _region = 'us-east-1';

  /// Synthesize speech using Amazon Polly
  static Future<Uint8List?> synthesizeSpeech({
    required String text,
    String voiceId = 'Joanna', // Child-friendly voice
    String outputFormat = 'mp3',
    String engine = 'neural', // Use neural engine for better quality
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final dateStamp = _formatDate(now);
      final amzDate = _formatDateTime(now);

      // Create the canonical request
      final canonicalUri = '/v1/speech';
      final canonicalQuerystring = '';
      final canonicalHeaders = 'host:$_endpoint\nx-amz-date:$amzDate\n';
      final signedHeaders = 'host;x-amz-date';

      final payload = jsonEncode({
        'Text': text,
        'VoiceId': voiceId,
        'OutputFormat': outputFormat,
        'Engine': engine,
      });

      final payloadHash = sha256.convert(utf8.encode(payload)).toString();

      final canonicalRequest = 'POST\n'
          '$canonicalUri\n'
          '$canonicalQuerystring\n'
          '$canonicalHeaders\n'
          '$signedHeaders\n'
          '$payloadHash';

      // Create the string to sign
      final algorithm = 'AWS4-HMAC-SHA256';
      final credentialScope = '$dateStamp/$_region/$_service/aws4_request';
      final stringToSign = '$algorithm\n'
          '$amzDate\n'
          '$credentialScope\n'
          '${sha256.convert(utf8.encode(canonicalRequest))}';

      // Calculate the signature
      final signature = _calculateSignature(
        TtsConfig.amazonAccessKey,
        dateStamp,
        _region,
        _service,
        stringToSign,
      );

      // Create authorization header
      final authorization = '$algorithm '
          'Credential=${TtsConfig.amazonKeyId}/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature';

      // Make the request
      final url = Uri.https(_endpoint, canonicalUri);
      final response = await http.post(
        url,
        headers: {
          'Authorization': authorization,
          'Content-Type': 'application/x-amz-json-1.0',
          'X-Amz-Date': amzDate,
          'X-Amz-Target': 'com.amazonaws.polly.service.Polly_20160610.SynthesizeSpeech',
        },
        body: payload,
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        if (kDebugMode) {
          print('[Polly] Error: ${response.statusCode} - ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Polly] Exception: $e');
      }
      return null;
    }
  }

  /// Get available child-friendly voices
  static List<Map<String, String>> getChildFriendlyVoices() {
    return [
      {'id': 'Joanna', 'name': 'Joanna (US)', 'gender': 'Female'},
      {'id': 'Matthew', 'name': 'Matthew (US)', 'gender': 'Male'},
      {'id': 'Ivy', 'name': 'Ivy (US Child)', 'gender': 'Female'},
      {'id': 'Justin', 'name': 'Justin (US Child)', 'gender': 'Male'},
      {'id': 'Emma', 'name': 'Emma (UK)', 'gender': 'Female'},
      {'id': 'Brian', 'name': 'Brian (UK)', 'gender': 'Male'},
    ];
  }

  // Helper methods for AWS signature calculation
  static String _formatDate(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}';
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)}T'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}Z';
  }

  static String _calculateSignature(
    String secretKey,
    String dateStamp,
    String region,
    String service,
    String stringToSign,
  ) {
    final kDate = _hmacSha256('AWS4$secretKey'.codeUnits, dateStamp.codeUnits);
    final kRegion = _hmacSha256(kDate, region.codeUnits);
    final kService = _hmacSha256(kRegion, service.codeUnits);
    final kSigning = _hmacSha256(kService, 'aws4_request'.codeUnits);
    final signature = _hmacSha256(kSigning, stringToSign.codeUnits);
    
    return signature.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }
}
