// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lxd_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LxdImage _$LxdImageFromJson(Map<String, dynamic> json) => LxdImage(
      autoUpdate: json['auto_update'] as bool,
      properties: Map<String, String>.from(json['properties'] as Map),
      public: json['public'] as bool,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      profiles:
          (json['profiles'] as List<dynamic>).map((e) => e as String).toList(),
      aliases: (json['aliases'] as List<dynamic>)
          .map((e) => LxdImageAlias.fromJson(e as Map<String, dynamic>))
          .toList(),
      architecture: json['architecture'] as String,
      cached: json['cached'] as bool,
      filename: json['filename'] as String,
      fingerprint: json['fingerprint'] as String,
      size: json['size'] as int,
      updateSource: json['update_source'] == null
          ? null
          : LxdImageSource.fromJson(
              json['update_source'] as Map<String, dynamic>),
      type: $enumDecode(_$LxdImageTypeEnumMap, json['type']),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastUsedAt: DateTime.parse(json['last_used_at'] as String),
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );

Map<String, dynamic> _$LxdImageToJson(LxdImage instance) => <String, dynamic>{
      'auto_update': instance.autoUpdate,
      'properties': instance.properties,
      'public': instance.public,
      'expires_at': instance.expiresAt.toIso8601String(),
      'profiles': instance.profiles,
      'aliases': instance.aliases.map((e) => e.toJson()).toList(),
      'architecture': instance.architecture,
      'cached': instance.cached,
      'filename': instance.filename,
      'fingerprint': instance.fingerprint,
      'size': instance.size,
      'update_source': instance.updateSource?.toJson(),
      'type': _$LxdImageTypeEnumMap[instance.type],
      'created_at': instance.createdAt.toIso8601String(),
      'last_used_at': instance.lastUsedAt.toIso8601String(),
      'uploaded_at': instance.uploadedAt.toIso8601String(),
    };

const _$LxdImageTypeEnumMap = {
  LxdImageType.container: 'container',
  LxdImageType.virtualMachine: 'virtual-machine',
};

LxdImageAlias _$LxdImageAliasFromJson(Map<String, dynamic> json) =>
    LxdImageAlias(
      name: json['name'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$LxdImageAliasToJson(LxdImageAlias instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
    };

LxdImageSource _$LxdImageSourceFromJson(Map<String, dynamic> json) =>
    LxdImageSource(
      alias: json['alias'] as String,
      certificate: json['certificate'] as String?,
      protocol: json['protocol'] as String,
      server: json['server'] as String,
      imageType: $enumDecodeNullable(_$LxdImageTypeEnumMap, json['image_type'],
          unknownValue: JsonKey.nullForUndefinedEnumValue),
    );

Map<String, dynamic> _$LxdImageSourceToJson(LxdImageSource instance) =>
    <String, dynamic>{
      'alias': instance.alias,
      'certificate': instance.certificate,
      'protocol': instance.protocol,
      'server': instance.server,
      'image_type': _$LxdImageTypeEnumMap[instance.imageType],
    };
