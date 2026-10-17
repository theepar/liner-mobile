enum BrandingVariant {
  standard('default', 'Default'),
  spotify('spotify', 'Spotify'),
  discord('discord', 'Discord'),
  telegram('telegram', 'Telegram'),
  aurora('aurora', 'Aurora'),
  sunset('sunset', 'Sunset'),
  ocean('ocean', 'Ocean'),
  forest('forest', 'Forest'),
  berry('berry', 'Berry'),
  carbon('carbon', 'Carbon'),
  pixel('pixel', 'Pixel'),
  scanlines('scanlines', 'Scanlines'),
  chrome('vhs', 'Chrome');

  const BrandingVariant(this.id, this.label);

  final String id;
  final String label;

  String get assetPath => 'assets/branding/logos/$id.svg';

  static BrandingVariant fromId(String? id) => values.firstWhere(
    (variant) => variant.id == id,
    orElse: () => BrandingVariant.standard,
  );
}
