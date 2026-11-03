class ChancenCountry {
  final String code;
  final String name;
  final bool live;
  final String privacyUrl;
  final String termsUrl;

  const ChancenCountry({
    required this.code,
    required this.name,
    required this.live,
    required this.privacyUrl,
    required this.termsUrl,
  });

  factory ChancenCountry.fromJson(Map<String, dynamic> json) {
    return ChancenCountry(
      code: (json['code'] as String).toUpperCase(),
      name: json['name'] as String,
      live: json['live'] == true,
      privacyUrl: json['privacy_url'] as String? ?? '',
      termsUrl: json['terms_url'] as String? ?? '',
    );
  }

  Uri privacyUri(String baseUrl) => _absoluteUri(baseUrl, privacyUrl);
  Uri termsUri(String baseUrl) => _absoluteUri(baseUrl, termsUrl);

  Uri _absoluteUri(String baseUrl, String value) {
    final uri = Uri.parse(value);
    if (uri.hasScheme) return uri;
    return Uri.parse(baseUrl).resolve(value);
  }
}
