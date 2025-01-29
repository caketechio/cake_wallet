class WiExtended {
  final String seed;
  final String spendPrivateKey;
  final String spendPublicKey;
  final String viewPrivateKey;
  final String viewPublicKey;

  WiExtended({required this.seed, required this.spendPrivateKey, required this.spendPublicKey, required this.viewPrivateKey, required this.viewPublicKey});

  factory WiExtended.fromJson(Map<String, dynamic> json) => WiExtended(
    seed: json['seed'] as String? ?? '',
    spendPrivateKey: json['spend_private_key'] as String? ?? '',
    spendPublicKey: json['spend_public_key'] as String? ?? '',
    viewPrivateKey: json['view_private_key'] as String? ?? '',
    viewPublicKey: json['view_public_key'] as String? ?? '',
  );
}