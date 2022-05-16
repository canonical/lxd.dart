import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

part 'lxd_image.g.dart';

@JsonEnum(fieldRename: FieldRename.kebab)
enum LxdImageType { container, virtualMachine }

@JsonSerializable(explicitToJson: true, fieldRename: FieldRename.snake)
class LxdImage {
  /// Whether the image should auto-update when a new build is available
  final bool autoUpdate;

  /// Descriptive properties
  ///
  /// Example:
  /// ```json
  /// {"os": "Ubuntu", "release": "jammy", "variant": "cloud"}
  final Map<String, String> properties;

  /// Whether the image is available to unauthenticated users
  final bool public;

  /// When the image becomes obsolete
  final DateTime expiresAt;

  /// List of profiles to use when creating from this image (if none provided by user)
  ///
  /// Example: ["default"]
  final List<String> profiles;

  /// List of aliases
  final List<LxdImageAlias> aliases;

  /// Architecture
  /// Example: x86_64
  final String architecture;

  /// Whether the image is an automatically cached remote image
  final bool cached;

  /// Original filename
  ///
  /// Example: 06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb.rootfs
  final String filename;

  /// Full SHA-256 fingerprint
  ///
  /// Example: 06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb
  final String fingerprint;

  /// Size of the image in bytes
  ///
  /// Example: 272237676
  final int size;

  /// Where the image came from
  final LxdImageSource? updateSource;

  /// Type of image (container or virtual-machine)
  final LxdImageType type;

  /// When the image was originally created
  final DateTime createdAt;

  /// Last time the image was used
  final DateTime lastUsedAt;

  /// When the image was added to this LXD server
  final DateTime uploadedAt;

  const LxdImage({
    required this.autoUpdate,
    required this.properties,
    required this.public,
    required this.expiresAt,
    required this.profiles,
    required this.aliases,
    required this.architecture,
    required this.cached,
    required this.filename,
    required this.fingerprint,
    required this.size,
    this.updateSource,
    required this.type,
    required this.createdAt,
    required this.lastUsedAt,
    required this.uploadedAt,
  });

  factory LxdImage.fromJson(Map<String, dynamic> json) =>
      _$LxdImageFromJson(json);

  Map<String, dynamic> toJson() => _$LxdImageToJson(this);

  @override
  String toString() =>
      'LxdImage(architecture: $architecture, autoUpdate: $autoUpdate, cached: $cached, createdAt: $createdAt, expiresAt: $expiresAt, filename: $filename, fingerprint: $fingerprint, lastUsedAt: $lastUsedAt, profiles: $profiles, properties: $properties, public: $public, size: $size, type: $type, uploadedAt: $uploadedAt)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final collectionEquals = const DeepCollectionEquality().equals;

    return other is LxdImage &&
        other.autoUpdate == autoUpdate &&
        collectionEquals(other.properties, properties) &&
        other.public == public &&
        other.expiresAt == expiresAt &&
        collectionEquals(other.profiles, profiles) &&
        collectionEquals(other.aliases, aliases) &&
        other.architecture == architecture &&
        other.cached == cached &&
        other.filename == filename &&
        other.fingerprint == fingerprint &&
        other.size == size &&
        other.updateSource == updateSource &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.lastUsedAt == lastUsedAt &&
        other.uploadedAt == uploadedAt;
  }

  @override
  int get hashCode {
    final mapHash = const DeepCollectionEquality().hash;

    return Object.hash(
      autoUpdate,
      mapHash(properties),
      public,
      expiresAt,
      Object.hashAll(profiles),
      Object.hashAll(aliases),
      architecture,
      cached,
      filename,
      fingerprint,
      size,
      updateSource,
      type,
      createdAt,
      lastUsedAt,
      uploadedAt,
    );
  }
}

@JsonSerializable()
class LxdImageAlias {
  /// Name of the alias
  ///
  /// Example: ubuntu-22.04
  final String name;

  /// Description of the alias
  ///
  /// Example: Our preferred Ubuntu image
  final String description;

  const LxdImageAlias({required this.name, required this.description});

  factory LxdImageAlias.fromJson(Map<String, dynamic> json) =>
      _$LxdImageAliasFromJson(json);

  Map<String, dynamic> toJson() => _$LxdImageAliasToJson(this);

  @override
  String toString() => 'LxdImageAlias(name: $name, description: $description)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LxdImageAlias &&
        other.name == name &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(name, description);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class LxdImageSource {
  /// Source alias to download from
  ///
  /// Example: jammy
  final String alias;

  /// Source server certificate (if not trusted by system CA)
  ///
  /// Example: X509 PEM certificate
  final String? certificate;

  /// Source server protocol
  ///
  /// Example: simplestreams
  final String protocol;

  /// URL of the source server
  ///
  /// Example: https://images.linuxcontainers.org
  final String server;

  // Type of image (container or virtual-machine)
  // Example: container
  //
  // API extension: image_types
  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  final LxdImageType? imageType;

  const LxdImageSource({
    required this.alias,
    this.certificate,
    required this.protocol,
    required this.server,
    this.imageType,
  });

  factory LxdImageSource.fromJson(Map<String, dynamic> json) =>
      _$LxdImageSourceFromJson(json);

  Map<String, dynamic> toJson() => _$LxdImageSourceToJson(this);

  @override
  String toString() =>
      'LxdImageSource(alias: $alias, certificate: $certificate, protocol: $protocol, server: $server, imageType: $imageType)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LxdImageSource &&
        other.alias == alias &&
        other.certificate == certificate &&
        other.protocol == protocol &&
        other.server == server &&
        other.imageType == imageType;
  }

  @override
  int get hashCode {
    return Object.hash(
      alias,
      certificate,
      protocol,
      server,
      imageType,
    );
  }
}
