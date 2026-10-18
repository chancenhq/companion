import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/chancen_country.dart';
import 'api_config.dart';
import 'log_service.dart';

class CountriesService {
  Future<List<ChancenCountry>> getCountries() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/countries');
      final response = await http
          .get(url, headers: ApiConfig.jsonHeaders())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw HttpException('Country list failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final countries = data['countries'] as List<dynamic>? ?? [];
      return countries
          .map((json) => ChancenCountry.fromJson(json as Map<String, dynamic>))
          .where((country) => country.live)
          .toList();
    } catch (e, stackTrace) {
      LogService.instance.error('CountriesService', 'Country fetch failed: $e\n$stackTrace');
      return const [
        ChancenCountry(
          code: 'KE',
          name: 'Kenya',
          live: true,
          privacyUrl: '/privacy/ke',
          termsUrl: '/terms/ke',
        ),
        ChancenCountry(
          code: 'RW',
          name: 'Rwanda',
          live: true,
          privacyUrl: '/privacy/rw',
          termsUrl: '/terms/rw',
        ),
        ChancenCountry(
          code: 'ZA',
          name: 'South Africa',
          live: true,
          privacyUrl: '/privacy/za',
          termsUrl: '/terms/za',
        ),
        ChancenCountry(
          code: 'GH',
          name: 'Ghana',
          live: true,
          privacyUrl: '/privacy/gh',
          termsUrl: '/terms/gh',
        ),
      ];
    }
  }
}
