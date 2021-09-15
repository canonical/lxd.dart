import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

import 'http_unix_client.dart';
import 'simplestream_client.dart';

const _certificatePath = '/1.0/certificates/';
const _instancePath = '/1.0/instances/';
const _imagePath = '/1.0/images/';
const _networkPath = '/1.0/networks/';
const _networkAclPath = '/1.0/network-acls/';
const _operationPath = '/1.0/operations/';
const _profilePath = '/1.0/profiles/';
const _projectPath = '/1.0/projects/';
const _storagePoolPath = '/1.0/storage-pools/';

/// General response from lxd.
abstract class _LxdResponse {
  /// Request result. Throws an exception if not a sync result.
  dynamic get result;

  /// Request operation. Throws an exception if not an async result.
  LxdOperation get operation;

  const _LxdResponse();
}

/// Response retuned when a sync request is completed.
class _LxdSyncResponse extends _LxdResponse {
  final int statusCode;

  final String status;

  final dynamic _result;

  @override
  dynamic get result => _result;

  @override
  LxdOperation get operation => throw 'Result is sync';

  _LxdSyncResponse(dynamic result,
      {required this.statusCode, required this.status})
      : _result = result;
}

/// Response retuned when an async request has been started.
class _LxdAsyncResponse extends _LxdResponse {
  final int statusCode;

  final String status;

  final LxdOperation _operation;

  @override
  dynamic get result => throw 'Result is async';

  @override
  LxdOperation get operation => _operation;

  _LxdAsyncResponse(LxdOperation operation,
      {required this.statusCode, required this.status})
      : _operation = operation;
}

/// Response retuned when an error occurred.
class _LxdErrorResponse extends _LxdResponse {
  // Error code.
  final int errorCode;

  /// Error message returned.
  final String error;

  @override
  dynamic get result => throw 'Result is error: $error';

  @override
  LxdOperation get operation => throw 'Result is error: $error';

  const _LxdErrorResponse({required this.errorCode, required this.error});
}

class LxdOperation {
  final DateTime createdAt;
  final String description;
  final String error;
  final String id;
  final List<String> instanceNames;
  final bool mayCancel;
  final String status;
  final int statusCode;
  final DateTime updatedAt;

  LxdOperation(
      {required this.createdAt,
      required this.description,
      this.error = '',
      required this.id,
      this.instanceNames = const [],
      this.mayCancel = false,
      required this.status,
      required this.statusCode,
      required this.updatedAt});

  @override
  String toString() =>
      'LxdOperation(createdAt: $createdAt, description: $description, error: $error, id: $id, instanceNames: $instanceNames, mayCancel: $mayCancel, status: $status, statusCode: $statusCode, updatedAt: $updatedAt)';
}

class LxdCpuResources {
  final String architecture;
  final List<String> sockets;

  LxdCpuResources({required this.architecture, required this.sockets});

  @override
  String toString() =>
      'LxdCpuResources(architecture: $architecture, sockets: $sockets)';
}

class LxdMemoryResources {
  final int used;
  final int total;

  LxdMemoryResources({required this.used, required this.total});

  @override
  String toString() => 'LxdMemoryResources(used: $used, total: $total)';
}

class LxdGpuCard {
  final String driver;
  final String driverVersion;

  LxdGpuCard({required this.driver, required this.driverVersion});

  @override
  String toString() => 'LxdGpuCard()';
}

class LxdNetworkCard {
  final String driver;
  final String driverVersion;

  LxdNetworkCard({required this.driver, required this.driverVersion});

  @override
  String toString() => 'LxdNetworkCard()';
}

class LxdStorageDisk {
  final int size;
  final String type;

  LxdStorageDisk({required this.size, required this.type});

  @override
  String toString() => 'LxdStorageDisk()';
}

class LxdUsbDevice {
  final String driver;
  final String driverVersion;

  LxdUsbDevice({required this.driver, required this.driverVersion});

  @override
  String toString() => 'LxdUsbDevice()';
}

class LxdPciDevice {
  final String driver;
  final String driverVersion;

  LxdPciDevice({required this.driver, required this.driverVersion});

  @override
  String toString() => 'LxdPciDevice()';
}

class LxdFirmware {
  final String date;
  final String vendor;
  final String version;

  LxdFirmware(
      {required this.date, required this.vendor, required this.version});

  @override
  String toString() =>
      'LxdFirmware(date: $date, vendor: $vendor, version: $version)';
}

class LxdChassis {
  final String serial;
  final String type;
  final String vendor;
  final String version;

  LxdChassis(
      {required this.serial,
      required this.type,
      required this.vendor,
      required this.version});

  @override
  String toString() =>
      'LxdChassis(serial: $serial, type: $type, vendor: $vendor, version: $version)';
}

class LxdMotherboard {
  final String product;
  final String serial;
  final String vendor;
  final String version;

  LxdMotherboard(
      {required this.product,
      required this.serial,
      required this.vendor,
      required this.version});

  @override
  String toString() =>
      'LxdMotherboard(product: $product, serial: $serial, vendor: $vendor, version: $version)';
}

class LxdSystemResources {
  final String uuid;
  final String vendor;
  final String product;
  final String family;
  final String version;
  final String sku;
  final String serial;
  final String type;
  final LxdFirmware firmware;
  final LxdChassis chassis;
  final LxdMotherboard motherboard;

  LxdSystemResources(
      {required this.uuid,
      required this.vendor,
      required this.product,
      required this.family,
      required this.version,
      required this.sku,
      required this.serial,
      required this.type,
      required this.firmware,
      required this.chassis,
      required this.motherboard});

  @override
  String toString() =>
      'LxdSystemResources(uuid: $uuid, vendor: $vendor, product: $product, family: $family, version: $version, sku: $sku, serial: $serial, type: $type, firmware: $firmware, chassis: $chassis, motherboar: $motherboard)';
}

class LxdResources {
  final LxdCpuResources cpu;
  final LxdMemoryResources memory;
  final List<LxdGpuCard> gpuCards;
  final List<LxdNetworkCard> networkCards;
  final List<LxdStorageDisk> storageDisks;
  final List<LxdUsbDevice> usbDevices;
  final List<LxdPciDevice> pciDevices;
  final LxdSystemResources system;

  LxdResources(
      {required this.cpu,
      required this.memory,
      required this.gpuCards,
      required this.networkCards,
      required this.storageDisks,
      required this.usbDevices,
      required this.pciDevices,
      required this.system});

  @override
  String toString() =>
      'LxdResources(cpu: $cpu, memory: $memory, gpuCards: $gpuCards, networkCards: $networkCards, storageDisks: $storageDisks, usbDevices: $usbDevices, pciDevices: $pciDevices, system: $system)';
}

class LxdCertificate {
  final String certificate;
  final String fingerprint;
  final String name;
  final List<String> projects;
  final bool restricted;
  final String type;

  LxdCertificate(
      {required this.certificate,
      required this.fingerprint,
      required this.name,
      required this.projects,
      required this.restricted,
      required this.type});
}

class LxdImage {
  final String architecture;
  final bool autoUpdate;
  final bool cached;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String filename;
  final String fingerprint;
  final DateTime lastUsedAt;
  final List<String> profiles;
  final Map<String, String> properties;
  final bool public;
  final int size;
  final String type;
  final DateTime uploadedAt;

  LxdImage({
    required this.architecture,
    required this.autoUpdate,
    required this.cached,
    required this.createdAt,
    required this.expiresAt,
    required this.filename,
    required this.fingerprint,
    required this.lastUsedAt,
    required this.profiles,
    required this.properties,
    required this.public,
    required this.size,
    required this.type,
    required this.uploadedAt,
  });

  @override
  String toString() =>
      'LxdImage(architecture: $architecture, autoUpdate: $autoUpdate, cached: $cached, createdAt: $createdAt, expiresAt: $expiresAt, filename: $filename, fingerprint: $fingerprint, lastUsedAt: $lastUsedAt, profiles: $profiles, properties: $properties, public: $public, size: $size, type: $type, uploadedAt: $uploadedAt)';
}

class LxdInstance {
  final String architecture;
  final Map<String, dynamic> config;
  final DateTime createdAt;
  final String description;
  final bool ephemeral;
  final DateTime lastUsedAt;
  final String location;
  final String name;
  final List<String> profiles;
  final bool stateful;
  final String status;
  final int statusCode;
  final String type;

  LxdInstance(
      {required this.architecture,
      required this.config,
      required this.createdAt,
      required this.description,
      required this.ephemeral,
      required this.lastUsedAt,
      required this.location,
      required this.name,
      required this.profiles,
      required this.stateful,
      required this.status,
      required this.statusCode,
      required this.type});

  @override
  String toString() =>
      "LxdInstance(architecture: $architecture, config: $config, createdAt: $createdAt, description: '$description', ephemeral: $ephemeral, lastUsedAt: $lastUsedAt, location: $location, name: $name, profiles: $profiles, stateful: $stateful, status: $status, statusCode: $statusCode, type: $type)";
}

class LxdInstanceState {
  final Map<String, LxdNetworkState> network;
  final int pid;
  final String status;
  final int statusCode;

  LxdInstanceState(
      {required this.network,
      required this.pid,
      required this.status,
      required this.statusCode});

  @override
  String toString() =>
      'LxdInstanceState(network: $network, pid: $pid, status: $status, statusCode: $statusCode)';
}

class LxdNetwork {
  final Map<String, dynamic> config;
  final String description;
  final bool managed;
  final String name;
  final String status;
  final String type;

  LxdNetwork(
      {required this.config,
      required this.description,
      required this.managed,
      required this.name,
      required this.status,
      required this.type});

  @override
  String toString() =>
      "LxdNetwork(config: $config, description: '$description', managed: $managed, name: $name, status: $status, type: $type)";
}

class LxdNetworkAddress {
  final String address;
  final String family;
  final String netmask;
  final String scope;

  LxdNetworkAddress(
      {required this.address,
      required this.family,
      required this.netmask,
      required this.scope});

  @override
  String toString() =>
      'LxdNetworkAddress(address: $address, family: $family, netmask: $netmask, scope: $scope)';

  @override
  bool operator ==(other) =>
      other is LxdNetworkAddress &&
      other.address == address &&
      other.family == family &&
      other.netmask == netmask &&
      other.scope == scope;
}

class LxdNetworkCounters {
  final int bytesReceived;
  final int bytesSent;
  final int packetsReceived;
  final int packetsSent;

  LxdNetworkCounters(
      {required this.bytesReceived,
      required this.bytesSent,
      required this.packetsReceived,
      required this.packetsSent});
}

class LxdNetworkState {
  final List<LxdNetworkAddress> addresses;
  final LxdNetworkCounters counters;
  final String hwaddr;
  final int mtu;
  final String state;
  final String type;

  LxdNetworkState(
      {required this.addresses,
      required this.counters,
      required this.hwaddr,
      required this.mtu,
      required this.state,
      required this.type});

  @override
  String toString() =>
      'LxdNetworkState(addresses: $addresses, hwaddr: $hwaddr, mtu: $mtu, state: $state, type: $type)';
}

class LxdNetworkLease {
  final String address;
  final String hostname;
  final String hwaddr;
  final String location;
  final String type;

  LxdNetworkLease(
      {required this.address,
      required this.hostname,
      required this.hwaddr,
      required this.location,
      required this.type});

  @override
  String toString() =>
      'LxdNetworkLease(address: $address, hostname: $hostname, hwaddr: $hwaddr, location: $location, type: $type)';
}

class LxdNetworkAcl {
  final Map<String, dynamic> config;
  final String description;
  final String name;

  LxdNetworkAcl(
      {required this.config, required this.description, required this.name});

  @override
  String toString() =>
      "LxdNetworkAcl(config: $config, description: '$description', name: $name)";
}

class LxdProfile {
  final Map<String, dynamic> config;
  final String description;
  final String name;

  LxdProfile(
      {required this.config, required this.description, required this.name});

  @override
  String toString() =>
      "LxdProfile(config: $config, description: '$description', name: $name)";
}

class LxdProject {
  final Map<String, dynamic> config;
  final String description;
  final String name;

  LxdProject(
      {required this.config, required this.description, required this.name});

  @override
  String toString() =>
      "LxdProject(config: $config, description: '$description', name: $name)";
}

class LxdStoragePool {
  final Map<String, dynamic> config;
  final String description;
  final String name;
  final String status;

  LxdStoragePool(
      {required this.config,
      required this.description,
      required this.name,
      required this.status});

  @override
  String toString() =>
      "LxdStoragePool(config: $config, description: '$description', name: $name, status: $status)";
}

enum LxdRemoteImageType { container, virtualMachine }

class LxdRemoteImage {
  final String architecture;
  final String description;
  final Set<String> aliases;
  final String fingerprint;
  final int size;
  final LxdRemoteImageType type;
  final String url;

  LxdRemoteImage(
      {required this.architecture,
      required this.description,
      required this.aliases,
      required this.fingerprint,
      required this.size,
      required this.type,
      required this.url});

  @override
  String toString() =>
      'LxdRemoteImage(architecture: $architecture, aliases: $aliases, description: $description, fingerprint: $fingerprint, size: $size, type: $type, url: $url)';
}

/// Manages a connection to the lxd server.
class LxdClient {
  HttpUnixClient? _client;
  String? _userAgent;
  final String? _socketPath;

  dynamic _hostInfo;

  LxdClient({String userAgent = 'lxd.dart', String? socketPath})
      : _userAgent = userAgent,
        _socketPath = socketPath;

  /// Sets the user agent sent in requests to lxd.
  set userAgent(String? value) => _userAgent = value;

  /// Get the operations in progress (keyed by type).
  Future<Map<String, List<String>>> getOperations() async {
    var operationPaths = await _requestSync('GET', '/1.0/operations');
    var operationIds = <String, List<String>>{};
    for (var type in operationPaths.keys) {
      var ids = <String>[];
      for (var path in operationPaths[type]) {
        if (path.startsWith(_operationPath)) {
          ids.add(path.substring(_operationPath.length));
        }
      }
      operationIds[type] = ids;
    }

    return operationIds;
  }

  /// Get the current state of the operation with [id].
  Future<LxdOperation> getOperation(String id) async {
    var response = await _requestSync('GET', '/1.0/operations/$id');
    return _parseOperation(response);
  }

  /// Wait for the operation with [id] to complete.
  Future<LxdOperation> waitOperation(String id) async {
    var response = await _requestSync('GET', '/1.0/operations/$id/wait');
    return _parseOperation(response);
  }

  /// Cancel the operation with [id].
  Future<void> cancelOperation(String id) async {
    await _requestSync('DELETE', '/1.0/operations/$id');
  }

  /// Gets system resources information.
  Future<LxdResources> getResources() async {
    var data = await _requestSync('GET', '/1.0/resources');
    var cpuData = data['cpu'];
    var memoryData = data['memory'];
    var gpu = data['gpu'];
    var network = data['network'];
    var storage = data['storage'];
    var usb = data['usb'];
    var pci = data['pci'];
    var systemData = data['system'];
    var firmwareData = systemData['firmware'];
    var chassisData = systemData['chassis'];
    var motherboardData = systemData['motherboard'];
    var gpuCards = <LxdGpuCard>[];
    for (var card in gpu['cards']) {
      gpuCards.add(LxdGpuCard(
          driver: card['driver'], driverVersion: card['driver_version']));
    }
    var networkCards = <LxdNetworkCard>[];
    for (var card in network['cards']) {
      networkCards.add(LxdNetworkCard(
          driver: card['driver'], driverVersion: card['driver_version']));
    }
    var storageDisks = <LxdStorageDisk>[];
    for (var disk in storage['disks']) {
      storageDisks.add(LxdStorageDisk(size: disk['size'], type: disk['type']));
    }
    var usbDevices = <LxdUsbDevice>[];
    for (var device in usb['devices']) {
      usbDevices.add(LxdUsbDevice(
          driver: device['driver'], driverVersion: device['driver_version']));
    }
    var pciDevices = <LxdPciDevice>[];
    for (var device in pci['devices']) {
      pciDevices.add(LxdPciDevice(
          driver: device['driver'], driverVersion: device['driver_version']));
    }
    return LxdResources(
        cpu: LxdCpuResources(
            architecture: cpuData['architecture'], sockets: []), // FIXME
        memory: LxdMemoryResources(
            used: memoryData['used'], total: memoryData['total']),
        gpuCards: gpuCards,
        networkCards: networkCards,
        storageDisks: storageDisks,
        usbDevices: usbDevices,
        pciDevices: pciDevices,
        system: LxdSystemResources(
            uuid: systemData['uuid'],
            vendor: systemData['vendor'],
            product: systemData['product'],
            family: systemData['family'],
            version: systemData['version'],
            sku: systemData['sku'],
            serial: systemData['serial'],
            type: systemData['type'],
            firmware: LxdFirmware(
                date: firmwareData['date'],
                vendor: firmwareData['vendor'],
                version: firmwareData['version']),
            chassis: LxdChassis(
                serial: chassisData['serial'],
                type: chassisData['type'],
                vendor: chassisData['vendor'],
                version: chassisData['version']),
            motherboard: LxdMotherboard(
                product: motherboardData['product'],
                serial: motherboardData['serial'],
                vendor: motherboardData['vendor'],
                version: motherboardData['version'])));
  }

  /// Gets the fingerprints of the certificates provided by the LXD server.
  Future<List<String>> getCertificates() async {
    var certificatePaths = await _requestSync('GET', '/1.0/certificates');
    var fingerprints = <String>[];
    for (var path in certificatePaths) {
      if (path.startsWith(_certificatePath)) {
        fingerprints.add(path.substring(_certificatePath.length));
      }
    }
    return fingerprints;
  }

  /// Gets information on a certificate with [fingerprint].
  Future<LxdCertificate> getCertificate(String fingerprint) async {
    var certificate =
        await _requestSync('GET', '/1.0/certificates/$fingerprint');
    return LxdCertificate(
        certificate: certificate['certificate'],
        fingerprint: certificate['fingerprint'],
        name: certificate['name'],
        projects: certificate['projects'].cast<String>(),
        restricted: certificate['restricted'],
        type: certificate['type']);
  }

  /// Gets the fingerprints of the images provided by the LXD server.
  Future<List<String>> getImages({String? project, String? filter}) async {
    var parameters = <String, String>{};
    if (project != null) {
      parameters['project'] = project;
    }
    if (filter != null) {
      parameters['filter'] = filter;
    }
    var imagePaths = await _requestSync('GET', '/1.0/images', parameters);
    var fingerprints = <String>[];
    for (var path in imagePaths) {
      if (path.startsWith(_imagePath)) {
        fingerprints.add(path.substring(_imagePath.length));
      }
    }
    return fingerprints;
  }

  /// Gets information on an image with [fingerprint].
  Future<LxdImage> getImage(String fingerprint) async {
    var image = await _requestSync('GET', '/1.0/images/$fingerprint');
    return LxdImage(
        architecture: image['architecture'],
        autoUpdate: image['auto_update'],
        cached: image['cached'],
        createdAt: DateTime.parse(image['created_at']),
        expiresAt: DateTime.parse(image['expires_at']),
        filename: image['filename'],
        fingerprint: image['fingerprint'],
        lastUsedAt: DateTime.parse(image['last_used_at']),
        profiles: image['profiles'].cast<String>(),
        properties: image['properties'].cast<String, String>(),
        public: image['public'],
        size: image['size'],
        type: image['type'],
        uploadedAt: DateTime.parse(image['uploaded_at']));
  }

  /// Gets the remote images available on the Simplestreams server at [url].
  Future<List<LxdRemoteImage>> getRemoteImages(String url) async {
    var s = SimplestreamClient(url);

    var images = <LxdRemoteImage>[];
    var products = await s.getProducts(datatype: 'image-downloads');
    for (var product in products) {
      images.addAll(_getRemoteImages(url, product));
    }

    s.close();

    return images;
  }

  /// Finds the image with [name] (alias or fingeprint) on the Simplestreams server at [url].
  Future<LxdRemoteImage?> findRemoteImage(String url, String name) async {
    await _connect();
    var architecture = _hostInfo['environment']['architectures'][0] ?? '';

    var s = SimplestreamClient(url);

    var products = await s.getProducts(datatype: 'image-downloads');
    for (var product in products) {
      if (!product.aliases.contains(name) ||
          _getArchitecture(product.architecture ?? '') != architecture) {
        continue;
      }

      var images = _getRemoteImages(url, product);
      if (images.isNotEmpty) {
        s.close();
        return images.first;
      }
    }

    s.close();
    return null;
  }

  List<LxdRemoteImage> _getRemoteImages(
      String url, SimplestreamProduct product) {
    var images = <LxdRemoteImage>[];

    for (var v in product.versions.values) {
      var lxdItem = v['lxd.tar.xz'] as SimplestreamDownloadItem?;
      if (lxdItem == null) {
        continue;
      }

      var description = '${product.os ?? ''} ${product.releaseTitle ?? ''}';

      if (lxdItem.combinedSquashfsSha256 != null) {
        var squashfsItem = v['squashfs'] as SimplestreamDownloadItem;
        images.add(LxdRemoteImage(
            architecture: product.architecture ?? '',
            aliases: product.aliases,
            description: description,
            fingerprint: lxdItem.combinedSquashfsSha256!,
            size: squashfsItem.size,
            type: LxdRemoteImageType.container,
            url: url));
      } else if (lxdItem.combinedDisk1ImgSha256 != null) {
        var disk1ImgItem = v['disk1.img'] as SimplestreamDownloadItem;
        images.add(LxdRemoteImage(
            architecture: product.architecture ?? '',
            aliases: product.aliases,
            description: description,
            fingerprint: lxdItem.combinedDisk1ImgSha256!,
            size: disk1ImgItem.size,
            type: LxdRemoteImageType.virtualMachine,
            url: url));
      }
    }

    return images;
  }

  /// Get the canonical name for [architecture].
  String _getArchitecture(String architecture) {
    const aliases = <String, List<String>>{
      'i686': ['i386', 'i586', '386', 'x86', 'generic_32'],
      'x86_64': ['amd64', 'generic_64'],
      'armv7l': [
        'armel',
        'armhf',
        'arm',
        'armhfp',
        'armv7a_hardfp',
        'armv7',
        'armv7a_vfpv3_hardfp'
      ],
      'aarch64': ['arm64', 'arm64_generic'],
      'ppc': ['powerpc'],
      'ppc64': ['powerpc64', 'ppc64'],
      'ppc64le': ['ppc64el'],
      's390x': ['mipsel'],
      'mips': ['mips64el'],
      'mips64': [],
      'riscv32': [],
      'riscv64': []
    };

    for (var name in aliases.keys) {
      if (architecture == name ||
          (aliases[name]?.contains(architecture) ?? false)) {
        return name;
      }
    }

    return architecture;
  }

  /// Gets the names of the instances provided by the LXD server.
  Future<List<String>> getInstances() async {
    var instancePaths = await _requestSync('GET', '/1.0/instances');
    var instanceNames = <String>[];
    for (var path in instancePaths) {
      if (path.startsWith(_instancePath)) {
        instanceNames.add(path.substring(_instancePath.length));
      }
    }
    return instanceNames;
  }

  /// Gets information on the instance with [name].
  Future<LxdInstance> getInstance(String name) async {
    var instance = await _requestSync('GET', '/1.0/instances/$name');
    // FIXME: 'devices', 'expanded_config', 'expanded_devices'
    return LxdInstance(
        architecture: instance['architecture'],
        config: instance['config'],
        createdAt: DateTime.parse(instance['created_at']),
        description: instance['description'],
        ephemeral: instance['ephemeral'],
        lastUsedAt: DateTime.parse(instance['last_used_at']),
        location: instance['location'],
        name: instance['name'],
        profiles: instance['profiles'].cast<String>(),
        stateful: instance['stateful'],
        status: instance['status'],
        statusCode: instance['status_code'],
        type: instance['type']);
  }

  /// Gets runtime state of the instance with [name].
  Future<LxdInstanceState> getInstanceState(String name) async {
    var state = await _requestSync('GET', '/1.0/instances/$name/state');
    return LxdInstanceState(
        network: (state['network'] ?? {}).map<String, LxdNetworkState>(
            (interface, state) =>
                MapEntry(interface as String, _parseNetworkState(state))),
        pid: state['pid'],
        status: state['status'],
        statusCode: state['status_code']);
  }

  /// Creates a new instance from [image].
  Future<LxdOperation> createInstance(
      {String? architecture,
      String? description,
      String? name,
      required LxdRemoteImage image}) async {
    var body = {};
    if (architecture != null) {
      body['architecture'] = architecture;
    }
    if (description != null) {
      body['description'] = description;
    }
    if (name != null) {
      body['name'] = name;
    }
    var s = {};
    s['type'] = 'image';
    s['fingerprint'] = image.fingerprint;
    s['protocol'] = 'simplestreams';
    s['server'] = image.url;
    body['source'] = s;
    return await _requestAsync('POST', '/1.0/instances', body);
  }

  /// Starts the instance with [name].
  Future<LxdOperation> startInstance(String name, {bool force = false}) async {
    return await _requestAsync('PUT', '/1.0/instances/$name/state',
        {'action': 'start', 'force': force});
  }

  /// Stops the instance with [name].
  Future<LxdOperation> stopInstance(String name, {bool force = false}) async {
    return await _requestAsync('PUT', '/1.0/instances/$name/state',
        {'action': 'stop', 'force': force});
  }

  /// Restarts the instance with [name].
  Future<LxdOperation> restartInstance(String name,
      {bool force = false}) async {
    return await _requestAsync('PUT', '/1.0/instances/$name/state',
        {'action': 'restart', 'force': force});
  }

  /// Deletes the instance with [name].
  Future<LxdOperation> deleteInstance(String name) async {
    return await _requestAsync('DELETE', '/1.0/instances/$name');
  }

  /// Gets the names of the networks provided by the LXD server.
  Future<List<String>> getNetworks() async {
    var networkPaths = await _requestSync('GET', '/1.0/networks');
    var networkNames = <String>[];
    for (var path in networkPaths) {
      if (path.startsWith(_networkPath)) {
        networkNames.add(path.substring(_networkPath.length));
      }
    }
    return networkNames;
  }

  /// Gets information on the network with [name].
  Future<LxdNetwork> getNetwork(String name) async {
    var network = await _requestSync('GET', '/1.0/networks/$name');
    return LxdNetwork(
        config: network['config'],
        description: network['description'],
        managed: network['managed'],
        name: network['name'],
        status: network['status'],
        type: network['type']);
  }

  /// Gets DHCP leases on the network with [name].
  Future<List<LxdNetworkLease>> getNetworkLeases(String name) async {
    var leaseList = await _requestSync('GET', '/1.0/networks/$name/leases');
    var leases = <LxdNetworkLease>[];
    for (var lease in leaseList) {
      leases.add(LxdNetworkLease(
          address: lease['address'],
          hostname: lease['hostname'],
          hwaddr: lease['hwaddr'],
          location: lease['location'],
          type: lease['type']));
    }
    return leases;
  }

  /// Gets the current network state of the network with [name].
  Future<LxdNetworkState> getNetworkState(String name) async {
    var state = await _requestSync('GET', '/1.0/networks/$name/state');
    return _parseNetworkState(state);
  }

  LxdNetworkState _parseNetworkState(dynamic state) {
    var addresses = <LxdNetworkAddress>[];
    for (var address in state['addresses']) {
      addresses.add(LxdNetworkAddress(
          address: address['address'],
          family: address['family'],
          netmask: address['netmask'],
          scope: address['scope']));
    }
    var counters = state['counters'];
    return LxdNetworkState(
        addresses: addresses,
        counters: LxdNetworkCounters(
            bytesReceived: counters['bytes_received'],
            bytesSent: counters['bytes_sent'],
            packetsReceived: counters['packets_received'],
            packetsSent: counters['packets_sent']),
        hwaddr: state['hwaddr'],
        mtu: state['mtu'],
        state: state['state'],
        type: state['type']);
  }

  /// Gets the names of the network ACLs provided by the LXD server.
  Future<List<String>> getNetworkAcls() async {
    var aclPaths = await _requestSync('GET', '/1.0/network-acls');
    var aclNames = <String>[];
    for (var path in aclPaths) {
      if (path.startsWith(_networkAclPath)) {
        aclNames.add(path.substring(_networkAclPath.length));
      }
    }
    return aclNames;
  }

  /// Gets information on the network ACL with [name].
  Future<LxdNetworkAcl> getNetworkAcl(String name) async {
    var acl = await _requestSync('GET', '/1.0/network-acls/$name');
    return LxdNetworkAcl(
        config: acl['config'],
        description: acl['description'],
        name: acl['name']);
  }

  /// Gets the names of the profiles provided by the LXD server.
  Future<List<String>> getProfiles() async {
    var profilePaths = await _requestSync('GET', '/1.0/profiles');
    var profileNames = <String>[];
    for (var path in profilePaths) {
      if (path.startsWith(_profilePath)) {
        profileNames.add(path.substring(_profilePath.length));
      }
    }
    return profileNames;
  }

  /// Gets information on the profile with [name].
  Future<LxdProfile> getProfile(String name) async {
    var profile = await _requestSync('GET', '/1.0/profiles/$name');
    return LxdProfile(
        config: profile['config'],
        description: profile['description'],
        name: profile['name']);
  }

  /// Gets the names of the projects provided by the LXD server.
  Future<List<String>> getProjects() async {
    var projectPaths = await _requestSync('GET', '/1.0/projects');
    var projectNames = <String>[];
    for (var path in projectPaths) {
      if (path.startsWith(_projectPath)) {
        projectNames.add(path.substring(_projectPath.length));
      }
    }
    return projectNames;
  }

  /// Gets information on the project with [name].
  Future<LxdProject> getProject(String name) async {
    var project = await _requestSync('GET', '/1.0/projects/$name');
    return LxdProject(
        config: project['config'],
        description: project['description'],
        name: project['name']);
  }

  /// Gets the names of the storage pools provided by the LXD server.
  Future<List<String>> getStoragePools() async {
    var poolPaths = await _requestSync('GET', '/1.0/storage-pools');
    var poolNames = <String>[];
    for (var path in poolPaths) {
      if (path.startsWith(_storagePoolPath)) {
        poolNames.add(path.substring(_storagePoolPath.length));
      }
    }
    return poolNames;
  }

  /// Gets information on the pool with [name].
  Future<LxdStoragePool> getStoragePool(String name) async {
    var pool = await _requestSync('GET', '/1.0/storage-pools/$name');
    return LxdStoragePool(
        config: pool['config'],
        description: pool['description'],
        name: pool['name'],
        status: pool['status']);
  }

  /// Terminates all active connections. If a client remains unclosed, the Dart process may not terminate.
  void close() {
    _client?.close();
  }

  Future<void> _connect() async {
    _hostInfo ??= await _requestSync('GET', '/1.0');
  }

  /// Get the HTTP client to communicate with lxd.
  Future<HttpUnixClient> _getClient() async {
    if (_client != null) {
      return _client!;
    }

    var socketPath = _socketPath;
    if (socketPath == null) {
      var lxdDir = Platform.environment['LXD_DIR'];
      var snapSocketPath = '/var/snap/lxd/common/lxd/unix.socket';
      if (lxdDir != null) {
        socketPath = lxdDir + '/unix.socket';
      } else if (await File(snapSocketPath).exists()) {
        socketPath = snapSocketPath;
      } else {
        socketPath = '/var/lib/lxd/unix.socket';
      }
    }

    _client = HttpUnixClient(socketPath);
    return _client!;
  }

  /// Does a synchronous request to lxd.
  Future<dynamic> _requestSync(String method, String path,
      [Map<String, String> queryParameters = const {}]) async {
    // Get host information first.
    if (method != 'GET' || path != '/1.0') {
      await _connect();
    }
    var client = await _getClient();
    var request = Request(method, Uri.http('localhost', path, queryParameters));
    _setHeaders(request);
    var response = await client.send(request);
    var lxdResponse = await _parseResponse(response);
    return lxdResponse.result;
  }

  /// Does an asynchronous request to lxd.
  Future<dynamic> _requestAsync(String method, String path,
      [dynamic body]) async {
    await _connect();
    var client = await _getClient();
    var request = Request(method, Uri.http('localhost', path));
    _setHeaders(request);
    request.headers['Content-Type'] = 'application/json';
    request.bodyBytes = utf8.encode(json.encode(body));
    var response = await client.send(request);
    var lxdResponse = await _parseResponse(response);
    return lxdResponse.operation;
  }

  /// Makes base HTTP headers to send.
  void _setHeaders(Request request) {
    if (_userAgent != null) {
      request.headers['User-Agent'] = _userAgent!;
    }
  }

  /// Decodes a response from lxd.
  Future<_LxdResponse> _parseResponse(StreamedResponse response) async {
    var body = await response.stream.bytesToString();
    var jsonResponse = json.decode(body);
    _LxdResponse lxdResponse;
    var type = jsonResponse['type'];
    if (type == 'sync') {
      var statusCode = jsonResponse['status_code'];
      var status = jsonResponse['status'];
      lxdResponse = _LxdSyncResponse(jsonResponse['metadata'],
          statusCode: statusCode, status: status);
    } else if (type == 'async') {
      var statusCode = jsonResponse['status_code'];
      var status = jsonResponse['status'];
      var metadata = jsonResponse['metadata'];
      lxdResponse = _LxdAsyncResponse(_parseOperation(metadata),
          statusCode: statusCode, status: status);
    } else if (type == 'error') {
      var errorCode = jsonResponse['error_code'];
      var error = jsonResponse['error'];
      lxdResponse = _LxdErrorResponse(errorCode: errorCode, error: error);
    } else {
      throw "Unknown lxd response '$type'";
    }

    return lxdResponse;
  }

  LxdOperation _parseOperation(dynamic data) {
    var instanceNames = <String>[];
    for (var path in data['resources']['instances'] ?? []) {
      if (path.startsWith(_instancePath)) {
        instanceNames.add(path.substring(_instancePath.length));
      }
    }
    return LxdOperation(
        createdAt: DateTime.parse(data['created_at']),
        description: data['description'],
        error: data['err'],
        id: data['id'],
        instanceNames: instanceNames,
        mayCancel: data['may_cancel'],
        status: data['status'],
        statusCode: data['status_code'],
        updatedAt: DateTime.parse(data['updated_at']));
  }
}
