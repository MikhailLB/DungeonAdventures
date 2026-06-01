/// Decoded response from the remote hub endpoint.
class HubReply {
  final bool granted;
  final String? destination;
  final String? note;
  final int? expiresAt;

  const HubReply._({
    required this.granted,
    this.destination,
    this.note,
    this.expiresAt,
  });

  factory HubReply.fromMap(Map<String, dynamic> raw) {
    final granted = (raw['ok'] as bool?)        ??
                    (raw['granted'] as bool?)    ??
                    (raw['accepted'] as bool?)   ??
                    false;

    final destination = raw['url'] as String?        ??
                        raw['link'] as String?       ??
                        raw['target'] as String?     ??
                        raw['destination'] as String?;

    final note = raw['message'] as String? ??
                 raw['note'] as String?    ??
                 raw['reason'] as String?;

    final dynamic ttl =
        raw['expires'] ?? raw['expires_at'] ?? raw['valid_until'];
    int? expires;
    if (ttl is int) {
      expires = ttl;
    } else if (ttl is num) {
      expires = ttl.toInt();
    } else if (ttl is String) {
      expires = int.tryParse(ttl);
    }

    return HubReply._(
      granted: granted,
      destination: destination,
      note: note,
      expiresAt: expires,
    );
  }

  factory HubReply.declined(String reason) =>
      HubReply._(granted: false, note: reason);
}
