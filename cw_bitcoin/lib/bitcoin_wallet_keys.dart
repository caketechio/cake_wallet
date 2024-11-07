class BitcoinWalletKeys {
  const BitcoinWalletKeys(
      {required this.wif,
      required this.privateKey,
      required this.publicKey,
      this.p2wpkhMainnetPubKey,
      this.p2wpkhMainnetPrivKey});

  final String wif;
  final String privateKey;
  final String publicKey;
  final String? p2wpkhMainnetPubKey;
  final String? p2wpkhMainnetPrivKey;
}
