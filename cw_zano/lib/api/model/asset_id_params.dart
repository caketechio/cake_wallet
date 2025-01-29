class AssetIdParams {
  final String assetId;

  AssetIdParams({required this.assetId});

  Map<String, dynamic> toJson() => {
    'asset_id': assetId,
  };
}