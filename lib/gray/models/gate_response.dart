class GateResponse {
  final bool ok;
  final String? url;
  final String? message;
  final int? expires;

  GateResponse({
    required this.ok,
    this.url,
    this.message,
    this.expires,
  });

  factory GateResponse.fromJson(Map<String, dynamic> json) {
    return GateResponse(
      ok: json['ok'] as bool? ?? false,
      url: json['url'] as String?,
      message: json['message'] as String?,
      expires: json['expires'] as int?,
    );
  }

  factory GateResponse.error(String message) {
    return GateResponse(ok: false, message: message);
  }
}
