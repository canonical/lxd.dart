import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lxd/lxd.dart';
import 'package:test/test.dart';

class MockCertificate {
  final String certificate;
  final String name;
  final List<String> projects;
  final bool restricted;
  final String type;

  MockCertificate(
      {this.certificate = '',
      this.name = '',
      this.projects = const [],
      this.restricted = false,
      this.type = ''});
}

class MockImage {
  final String architecture;
  final bool autoUpdate;
  final bool cached;
  final String createdAt;
  final String expiresAt;
  final String filename;
  final String lastUsedAt;
  final List<String> profiles;
  final Map<String, String> properties;
  final bool public;
  final int size;
  final String type;
  final String uploadedAt;

  MockImage(
      {this.architecture = '',
      this.autoUpdate = false,
      this.cached = false,
      this.createdAt = '1970-01-01',
      this.expiresAt = '1970-01-01',
      this.filename = '',
      this.lastUsedAt = '1970-01-01',
      this.profiles = const [],
      this.properties = const {},
      this.public = false,
      this.size = 0,
      this.type = '',
      this.uploadedAt = '1970-01-01'});
}

class MockInstance {
  final String architecture;
  final Map<String, dynamic> config;
  final String createdAt;
  final String description;
  final bool ephemeral;
  final String lastUsedAt;
  final String location;
  final List<String> profiles;
  final bool stateful;
  final String status;
  final int statusCode;
  final String type;

  final Map<String, MockNetworkState> network;
  final int pid;

  MockInstance(
      {this.architecture = '',
      this.config = const {},
      this.createdAt = '1970-01-01',
      this.description = '',
      this.ephemeral = false,
      this.lastUsedAt = '1970-01-01',
      this.location = '',
      this.profiles = const [],
      this.stateful = false,
      this.status = '',
      this.statusCode = 0,
      this.type = '',
      this.network = const {},
      this.pid = 0});
}

class MockNetworkAddress {
  final String address;
  final String family;
  final String netmask;
  final String scope;

  MockNetworkAddress(
      {this.address = '',
      this.family = '',
      this.netmask = '',
      this.scope = ''});
}

class MockNetworkAcl {
  final Map<String, dynamic> config;
  final String description;

  MockNetworkAcl({this.config = const {}, this.description = ''});
}

class MockNetworkLease {
  final String address;
  final String hostname;
  final String hwaddr;
  final String location;
  final String type;

  MockNetworkLease(
      {this.address = '',
      this.hostname = '',
      this.hwaddr = '',
      this.location = '',
      this.type = ''});
}

class MockNetworkCounters {
  final int bytesReceived;
  final int bytesSent;
  final int packetsReceived;
  final int packetsSent;

  const MockNetworkCounters(
      {this.bytesReceived = 0,
      this.bytesSent = 0,
      this.packetsReceived = 0,
      this.packetsSent = 0});
}

class MockNetworkState {
  final List<MockNetworkAddress> addresses;
  final MockNetworkCounters counters;
  final String hwaddr;
  final int mtu;
  final String state;
  final String type;

  const MockNetworkState(
      {this.addresses = const [],
      this.counters = const MockNetworkCounters(),
      this.hwaddr = '',
      this.mtu = 0,
      this.state = '',
      this.type = ''});
}

class MockNetwork {
  final Map<String, dynamic> config;
  final String description;
  final bool managed;
  final String status;
  final String type;

  final MockNetworkState state;

  final List<MockNetworkLease> leases;

  MockNetwork(
      {this.config = const {},
      this.description = '',
      this.managed = false,
      this.status = '',
      this.type = '',
      this.state = const MockNetworkState(),
      this.leases = const []});
}

class MockProfile {
  final Map<String, dynamic> config;
  final String description;

  MockProfile({this.config = const {}, this.description = ''});
}

class MockProject {
  final Map<String, dynamic> config;
  final String description;

  MockProject({this.config = const {}, this.description = ''});
}

class MockStoragePool {
  final Map<String, dynamic> config;
  final String description;
  final String status;

  MockStoragePool(
      {this.config = const {}, this.description = '', this.status = ''});
}

class MockOperation {
  final String createdAt;
  final String description;
  final String? error;
  final String id;
  final bool mayCancel;
  final String status;
  final int statusCode;
  final String updatedAt;

  MockOperation(
      {this.createdAt = '1970-01-01',
      this.description = '',
      this.error,
      required this.id,
      this.mayCancel = false,
      this.status = '',
      this.statusCode = 0,
      this.updatedAt = '1970-01-01'});

  Map<String, dynamic> toJson() {
    return {
      'created_at': createdAt,
      'description': description,
      'err': error ?? '',
      'id': id,
      'resources': {},
      'may_cancel': false,
      'status': status,
      'status_code': statusCode,
      'updated_at': updatedAt
    };
  }
}

class MockLxdServer {
  Directory? _tempDir;
  String? _socketPath;
  HttpServer? _server;
  ServerSocket? _unixSocket;
  StreamSubscription<Socket>? _unixSubscription;
  StreamSubscription<HttpRequest>? _requestSubscription;
  final _tcpSockets = <Socket, Socket>{};

  final Map<String, MockCertificate> certificates;
  final Map<String, MockImage> images;
  final Map<String, MockInstance> instances;
  final Map<String, MockNetwork> networks;
  final Map<String, MockNetworkAcl> networkAcls;
  final operations = <String, MockOperation>{};
  final Map<String, MockProfile> profiles;
  final Map<String, MockProject> projects;
  final Map<String, MockStoragePool> storagePools;

  String get socketPath => _socketPath!;

  MockLxdServer(
      {this.certificates = const {},
      this.images = const {},
      this.instances = const {},
      this.networks = const {},
      this.networkAcls = const {},
      this.profiles = const {},
      this.projects = const {},
      this.storagePools = const {}});

  Future<void> start() async {
    _tempDir = await Directory.systemTemp.createTemp();
    _socketPath = '${_tempDir!.path}/unix.socket';

    // Due to a bug in HttpServer, bridge from a Unix socket to a TCP/IP socket
    // https://github.com/dart-lang/sdk/issues/45977
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _requestSubscription = _server?.listen(_processRequest);
    _unixSocket = await ServerSocket.bind(
        InternetAddress(_socketPath!, type: InternetAddressType.unix), 0);
    _unixSubscription = _unixSocket?.listen((socket) async {
      var tcpSocket = await Socket.connect(_server!.address, _server!.port);
      _tcpSockets[socket] = tcpSocket;
      socket.listen((data) => tcpSocket.add(data),
          onDone: () => tcpSocket.close());
      tcpSocket.listen((data) => socket.add(data),
          onDone: () => socket.close());
    });
  }

  void _processRequest(HttpRequest request) {
    var response = request.response;
    var path = request.uri.path.startsWith('/')
        ? request.uri.path.substring(1).split('/')
        : [];
    if (request.method == 'GET' && path.length == 1 && path[0] == '1.0') {
      _getHostInfo(response);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'resources') {
      _getResources(response);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'certificates') {
      _getCertificates(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'certificates') {
      var fingerprint = path[2];
      _getCertificate(response, fingerprint);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'images') {
      _getImages(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'images') {
      var fingerprint = path[2];
      _getImage(response, fingerprint);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'instances') {
      _getInstances(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'instances') {
      var name = path[2];
      _getInstance(response, name);
    } else if (request.method == 'GET' &&
        path.length == 4 &&
        path[0] == '1.0' &&
        path[1] == 'instances' &&
        path[3] == 'state') {
      var name = path[2];
      _getInstanceState(response, name);
    } else if (request.method == 'PUT' &&
        path.length == 4 &&
        path[0] == '1.0' &&
        path[1] == 'instances' &&
        path[3] == 'state') {
      var name = path[2];
      _putInstanceState(response, name);
    } else if (request.method == 'POST' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'instances') {
      _createInstance(response);
    } else if (request.method == 'DELETE' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'instances') {
      var name = path[2];
      _deleteInstance(response, name);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'operations') {
      _getOperations(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'operations') {
      var id = path[2];
      _getOperation(response, id);
    } else if (request.method == 'GET' &&
        path.length == 4 &&
        path[0] == '1.0' &&
        path[1] == 'operations' &&
        path[3] == 'wait') {
      var id = path[2];
      _waitOperation(response, id);
    } else if (request.method == 'DELETE' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'operations') {
      var id = path[2];
      _deleteOperation(response, id);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'networks') {
      _getNetworks(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'networks') {
      var name = path[2];
      _getNetwork(response, name);
    } else if (request.method == 'GET' &&
        path.length == 4 &&
        path[0] == '1.0' &&
        path[1] == 'networks' &&
        path[3] == 'leases') {
      var name = path[2];
      _getNetworkLeases(response, name);
    } else if (request.method == 'GET' &&
        path.length == 4 &&
        path[0] == '1.0' &&
        path[1] == 'networks' &&
        path[3] == 'state') {
      var name = path[2];
      _getNetworkState(response, name);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'network-acls') {
      _getNetworkAcls(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'network-acls') {
      var name = path[2];
      _getNetworkAcl(response, name);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'profiles') {
      _getProfiles(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'profiles') {
      var name = path[2];
      _getProfile(response, name);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'projects') {
      _getProjects(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'projects') {
      var name = path[2];
      _getProject(response, name);
    } else if (request.method == 'GET' &&
        path.length == 2 &&
        path[0] == '1.0' &&
        path[1] == 'storage-pools') {
      _getStoragePools(response);
    } else if (request.method == 'GET' &&
        path.length == 3 &&
        path[0] == '1.0' &&
        path[1] == 'storage-pools') {
      var name = path[2];
      _getStoragePool(response, name);
    } else {
      response.statusCode = HttpStatus.notFound;
      _writeErrorResponse(response, 'not found');
    }
    response.close();
  }

  void _getHostInfo(HttpResponse response) {
    _writeSyncResponse(response, {
      'config': {},
      'api_extensions': [],
      'api_status': 'stable',
      'api_version': '1.0',
      'auth': 'trusted',
      'public': false,
      'auth_methods': ['tls'],
      'environment': {}
    });
  }

  void _getResources(HttpResponse response) {
    _writeSyncResponse(response, {
      'cpu': {'architecture': 'arm64'},
      'memory': {'used': 4125806592, 'total': 17179869184},
      'gpu': {},
      'network': {},
      'storage': {},
      'usb': {},
      'pci': {},
      'system': {
        'uuid': 'SYSTEM-UUID',
        'vendor': 'SYSTEM-VENDOR',
        'product': 'SYSTEM-PRODUCT',
        'family': 'SYSTEM-FAMILY',
        'version': '1.0',
        'sku': 'SYSTEM-SKU',
        'serial': 'SYSTEM-SERIAL',
        'type': 'physical',
        'firmware': {
          'date': '10/08/2021',
          'vendor': 'FIRMWARE-VENDOR',
          'version': '1.0'
        },
        'chassis': {
          'serial': 'CHASSIS-SERIAL',
          'type': 'Notebook',
          'vendor': 'CHASSIS-VENDOR',
          'version': '1.0'
        },
        'motherboard': {
          'product': 'MOTHERBOARD-PRODUCT',
          'serial': 'MOTHERBOARD-SERIAL',
          'vendor': 'MOTHERBOARD-VENDOR',
          'version': '1.0'
        }
      }
    });
  }

  void _getCertificates(HttpResponse response) {
    _writeSyncResponse(
        response,
        certificates.keys
            .map((fingerprint) => '/1.0/certificates/$fingerprint')
            .toList());
  }

  void _getCertificate(HttpResponse response, String fingerprint) {
    var certificate = certificates[fingerprint]!;
    _writeSyncResponse(response, {
      'certificate': certificate.certificate,
      'name': certificate.name,
      'fingerprint': fingerprint,
      'projects': certificate.projects,
      'restricted': certificate.restricted,
      'type': certificate.type,
    });
  }

  void _getImages(HttpResponse response) {
    _writeSyncResponse(response,
        images.keys.map((fingerprint) => '/1.0/images/$fingerprint').toList());
  }

  void _getImage(HttpResponse response, String fingerprint) {
    var image = images[fingerprint]!;
    _writeSyncResponse(response, {
      'architecture': image.architecture,
      'auto_update': image.autoUpdate,
      'cached': image.cached,
      'created_at': image.createdAt,
      'expires_at': image.expiresAt,
      'filename': image.filename,
      'fingerprint': fingerprint,
      'last_used_at': image.lastUsedAt,
      'profiles': image.profiles,
      'properties': image.properties,
      'public': image.public,
      'size': image.size,
      'type': image.type,
      'uploaded_at': image.uploadedAt
    });
  }

  void _getInstances(HttpResponse response) {
    _writeSyncResponse(response,
        instances.keys.map((name) => '/1.0/instances/$name').toList());
  }

  void _getInstance(HttpResponse response, String name) {
    var instance = instances[name]!;
    _writeSyncResponse(response, {
      'architecture': instance.architecture,
      'config': instance.config,
      'created_at': instance.createdAt,
      'description': instance.description,
      'ephemeral': instance.ephemeral,
      'last_used_at': instance.lastUsedAt,
      'location': instance.location,
      'name': name,
      'profiles': instance.profiles,
      'stateful': instance.stateful,
      'status': instance.status,
      'status_code': instance.statusCode,
      'type': instance.type
    });
  }

  void _getInstanceState(HttpResponse response, String name) {
    var instance = instances[name]!;
    _writeSyncResponse(response, {
      'network': instance.network.map((name, state) => MapEntry(name, {
            'addresses': state.addresses
                .map((address) => {
                      'address': address.address,
                      'family': address.family,
                      'netmask': address.netmask,
                      'scope': address.scope
                    })
                .toList(),
            'counters': {
              'bytes_received': state.counters.bytesReceived,
              'bytes_sent': state.counters.bytesSent,
              'packets_received': state.counters.packetsReceived,
              'packets_sent': state.counters.packetsSent
            },
            'hwaddr': state.hwaddr,
            'mtu': state.mtu,
            'state': state.state,
            'type': state.type
          })),
      'pid': instance.pid,
      'status': instance.status,
      'status_code': instance.statusCode
    });
  }

  void _putInstanceState(HttpResponse response, String name) {
    var operation = _addOperation();
    _writeAsyncResponse(response, operation.toJson());
  }

  void _createInstance(HttpResponse response) {
    var operation = _addOperation();
    _writeAsyncResponse(response, operation.toJson());
  }

  void _deleteInstance(HttpResponse response, String name) {
    var operation = _addOperation();
    _writeAsyncResponse(response, operation.toJson());
  }

  void _getOperations(HttpResponse response) {
    _writeSyncResponse(response, {
      'running': operations.keys.map((id) => '/1.0/operations/$id').toList()
    });
  }

  void _getOperation(HttpResponse response, String id) {
    _writeSyncResponse(response, operations[id]!.toJson());
  }

  void _waitOperation(HttpResponse response, String id) {
    _writeSyncResponse(response, operations[id]!.toJson());
  }

  void _deleteOperation(HttpResponse response, String id) {
    _writeSyncResponse(response, {});
  }

  void _getNetworks(HttpResponse response) {
    _writeSyncResponse(
        response, networks.keys.map((name) => '/1.0/networks/$name').toList());
  }

  void _getNetwork(HttpResponse response, String name) {
    var network = networks[name]!;
    _writeSyncResponse(response, {
      'config': network.config,
      'description': network.description,
      'managed': network.managed,
      'name': name,
      'status': network.status,
      'type': network.type
    });
  }

  void _getNetworkLeases(HttpResponse response, String name) {
    var network = networks[name]!;
    _writeSyncResponse(
        response,
        network.leases
            .map((lease) => {
                  'address': lease.address,
                  'hostname': lease.hostname,
                  'hwaddr': lease.hwaddr,
                  'location': lease.location,
                  'type': lease.type
                })
            .toList());
  }

  void _getNetworkState(HttpResponse response, String name) {
    var state = networks[name]!.state;
    _writeSyncResponse(response, {
      'addresses': state.addresses
          .map((address) => {
                'address': address.address,
                'family': address.family,
                'netmask': address.netmask,
                'scope': address.scope
              })
          .toList(),
      'counters': {
        'bytes_received': state.counters.bytesReceived,
        'bytes_sent': state.counters.bytesSent,
        'packets_received': state.counters.packetsReceived,
        'packets_sent': state.counters.packetsSent
      },
      'hwaddr': state.hwaddr,
      'mtu': state.mtu,
      'state': state.state,
      'type': state.type
    });
  }

  void _getNetworkAcls(HttpResponse response) {
    _writeSyncResponse(response,
        networkAcls.keys.map((name) => '/1.0/network-acls/$name').toList());
  }

  void _getNetworkAcl(HttpResponse response, String name) {
    var acl = networkAcls[name]!;
    _writeSyncResponse(response,
        {'config': acl.config, 'description': acl.description, 'name': name});
  }

  void _getProfiles(HttpResponse response) {
    _writeSyncResponse(
        response, profiles.keys.map((name) => '/1.0/profiles/$name').toList());
  }

  void _getProfile(HttpResponse response, String name) {
    var profile = profiles[name]!;
    _writeSyncResponse(response, {
      'config': profile.config,
      'description': profile.description,
      'name': name
    });
  }

  void _getProjects(HttpResponse response) {
    _writeSyncResponse(
        response, projects.keys.map((name) => '/1.0/projects/$name').toList());
  }

  void _getProject(HttpResponse response, String name) {
    var project = projects[name]!;
    _writeSyncResponse(response, {
      'config': project.config,
      'description': project.description,
      'name': name
    });
  }

  void _getStoragePools(HttpResponse response) {
    _writeSyncResponse(response,
        storagePools.keys.map((name) => '/1.0/storage-pools/$name').toList());
  }

  void _getStoragePool(HttpResponse response, String name) {
    var pool = storagePools[name]!;
    _writeSyncResponse(response, {
      'config': pool.config,
      'description': pool.description,
      'name': name,
      'status': pool.status
    });
  }

  MockOperation _addOperation({String description = '', String status = ''}) {
    var id = operations.length.toString();
    var operation =
        MockOperation(description: description, id: id, status: status);
    operations[id] = operation;
    return operation;
  }

  void _writeSyncResponse(HttpResponse response, dynamic metadata) {
    _writeJson(response, {
      'type': 'sync',
      'status': 'Success',
      'status_code': response.statusCode,
      'metadata': metadata
    });
  }

  void _writeAsyncResponse(HttpResponse response, [dynamic metadata]) {
    _writeJson(response, {
      'type': 'async',
      'status': '',
      'status_code': response.statusCode,
      'metadata': metadata
    });
  }

  void _writeErrorResponse(HttpResponse response, String message) {
    _writeJson(response,
        {'type': 'error', 'error_code': response.statusCode, 'error': message});
  }

  void _writeJson(HttpResponse response, dynamic value) {
    var data = utf8.encode(json.encode(value));
    response.headers.contentType = ContentType('application', 'json');
    response.headers.contentLength = data.length;
    response.add(data);
  }

  Future<void> close() async {
    await _requestSubscription?.cancel();
    await _unixSubscription?.cancel();
    for (var socket in _tcpSockets.values) {
      await socket.close();
    }
    await _tempDir?.delete(recursive: true);
  }
}

void main() {
  test('get resources', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var resources = await client.getResources();
    expect(resources.cpu.architecture, equals('arm64'));
    expect(resources.memory.used, equals(4125806592));
    expect(resources.memory.total, equals(17179869184));
    expect(resources.system.uuid, equals('SYSTEM-UUID'));
    expect(resources.system.firmware.date, equals('10/08/2021'));
    expect(resources.system.firmware.vendor, equals('FIRMWARE-VENDOR'));
    expect(resources.system.firmware.version, equals('1.0'));
    expect(resources.system.chassis.serial, equals('CHASSIS-SERIAL'));
    expect(resources.system.chassis.type, equals('Notebook'));
    expect(resources.system.chassis.vendor, equals('CHASSIS-VENDOR'));
    expect(resources.system.chassis.version, equals('1.0'));
    expect(resources.system.motherboard.product, equals('MOTHERBOARD-PRODUCT'));
    expect(resources.system.motherboard.serial, equals('MOTHERBOARD-SERIAL'));
    expect(resources.system.motherboard.vendor, equals('MOTHERBOARD-VENDOR'));
    expect(resources.system.motherboard.version, equals('1.0'));

    client.close();
    await lxd.close();
  });

  test('get certificates', () async {
    var lxd = MockLxdServer(certificates: {
      '213394bb': MockCertificate(),
      '3402b8e1': MockCertificate()
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var certificates = await client.getCertificates();
    expect(certificates, equals(['213394bb', '3402b8e1']));

    client.close();
    await lxd.close();
  });

  test('get certificate', () async {
    var lxd = MockLxdServer(certificates: {
      '213394bb': MockCertificate(
          certificate: 'CERTIFICATE',
          name: 'NAME',
          restricted: true,
          type: 'TYPE')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var certificate = await client.getCertificate('213394bb');
    expect(certificate.certificate, equals('CERTIFICATE'));
    expect(certificate.fingerprint, equals('213394bb'));
    expect(certificate.name, equals('NAME'));
    expect(certificate.restricted, isTrue);
    expect(certificate.type, equals('TYPE'));

    client.close();
    await lxd.close();
  });

  test('get images', () async {
    var lxd = MockLxdServer(images: {
      '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb':
          MockImage(),
      '084dd79dd1360fd25a2479eb46674c2a5ef3022a40fe03c91ab3603e3402b8e1':
          MockImage()
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var fingerprints = await client.getImages();
    expect(
        fingerprints,
        equals([
          '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb',
          '084dd79dd1360fd25a2479eb46674c2a5ef3022a40fe03c91ab3603e3402b8e1'
        ]));

    client.close();
    await lxd.close();
  });

  test('get image', () async {
    var lxd = MockLxdServer(images: {
      '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb': MockImage(
          architecture: 'x86_64',
          autoUpdate: true,
          cached: true,
          createdAt: '2021-03-23T20:00:00-04:00',
          expiresAt: '2025-03-23T20:00:00-04:00',
          filename:
              '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb.rootfs',
          lastUsedAt: '2021-03-22T20:39:00.575185384-04:00',
          public: false,
          size: 272237676,
          type: 'container',
          uploadedAt: '2021-03-24T14:18:15.115036787-04:00')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var image = await client.getImage(
        '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb');
    expect(image.architecture, equals('x86_64'));
    expect(image.autoUpdate, isTrue);
    expect(image.cached, isTrue);
    expect(
        image.createdAt, equals(DateTime.parse('2021-03-23T20:00:00-04:00')));
    expect(
        image.expiresAt, equals(DateTime.parse('2025-03-23T20:00:00-04:00')));
    expect(
        image.filename,
        equals(
            '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb.rootfs'));
    expect(
        image.fingerprint,
        equals(
            '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb'));
    expect(image.lastUsedAt,
        equals(DateTime.parse('2021-03-22T20:39:00.575185384-04:00')));
    expect(image.profiles, equals([]));
    expect(image.public, isFalse);
    expect(image.size, equals(272237676));
    expect(image.type, equals('container'));
    expect(image.uploadedAt,
        equals(DateTime.parse('2021-03-24T14:18:15.115036787-04:00')));

    client.close();
    await lxd.close();
  });

  test('get instances', () async {
    var lxd = MockLxdServer(
        instances: {'foo': MockInstance(), 'bar': MockInstance()});
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var instanceNames = await client.getInstances();
    expect(instanceNames, equals(['foo', 'bar']));

    client.close();
    await lxd.close();
  });

  test('get instance', () async {
    var lxd = MockLxdServer(instances: {
      'foo': MockInstance(
          architecture: 'x86_64',
          config: {'security.nesting': 'true'},
          createdAt: '2021-03-23T20:00:00-04:00',
          description: 'My test instance',
          ephemeral: false,
          lastUsedAt: '2021-03-23T20:00:00-04:00',
          location: 'lxd01',
          profiles: ['default'],
          stateful: false,
          status: 'Running',
          statusCode: 0,
          type: 'container')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var instance = await client.getInstance('foo');
    expect(instance.architecture, equals('x86_64'));
    expect(instance.config, equals({'security.nesting': 'true'}));
    expect(instance.createdAt,
        equals(DateTime.parse('2021-03-23T20:00:00-04:00')));
    expect(instance.description, equals('My test instance'));
    expect(instance.ephemeral, isFalse);
    expect(instance.lastUsedAt,
        equals(DateTime.parse('2021-03-23T20:00:00-04:00')));
    expect(instance.location, equals('lxd01'));
    expect(instance.name, equals('foo'));
    expect(instance.profiles, equals(['default']));
    expect(instance.stateful, isFalse);
    expect(instance.status, equals('Running'));
    expect(instance.statusCode, equals(0));
    expect(instance.type, equals('container'));

    client.close();
    await lxd.close();
  });

  test('get instance state', () async {
    var lxd = MockLxdServer(instances: {
      'foo': MockInstance(
          status: 'Running',
          statusCode: 0,
          network: {
            'eth0': MockNetworkState(
                addresses: [
                  MockNetworkAddress(
                      address: 'fd42:4c81:5770:1eaf:216:3eff:fe0c:eedd',
                      family: 'inet6',
                      netmask: '64',
                      scope: 'global')
                ],
                counters: MockNetworkCounters(
                    bytesReceived: 192021,
                    bytesSent: 10888579,
                    packetsReceived: 1748,
                    packetsSent: 964),
                hwaddr: '00:16:3e:0c:ee:dd',
                mtu: 1500,
                state: 'up',
                type: 'broadcast')
          },
          pid: 7281)
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var state = await client.getInstanceState('foo');
    expect(state.network.keys, equals(['eth0']));
    var s = state.network['eth0']!;
    expect(
        s.addresses,
        equals([
          LxdNetworkAddress(
              address: 'fd42:4c81:5770:1eaf:216:3eff:fe0c:eedd',
              family: 'inet6',
              netmask: '64',
              scope: 'global')
        ]));
    expect(s.counters.bytesReceived, equals(192021));
    expect(s.counters.bytesSent, equals(10888579));
    expect(s.counters.packetsReceived, equals(1748));
    expect(s.counters.packetsSent, equals(964));
    expect(s.hwaddr, equals('00:16:3e:0c:ee:dd'));
    expect(s.mtu, equals(1500));
    expect(s.state, equals('up'));
    expect(s.type, equals('broadcast'));
    expect(state.pid, equals(7281));
    expect(state.status, equals('Running'));
    expect(state.statusCode, equals(0));

    client.close();
    await lxd.close();
  });

  test('create instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var operation = await client.createInstance(
        image: LxdRemoteImage(
            architecture: 'amd64',
            aliases: {},
            description: 'Test Image',
            fingerprint:
                '06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb',
            size: 272237676,
            type: LxdRemoteImageType.container,
            url: 'https://example.com'));
    operation = await client.waitOperation(operation.id);

    client.close();
    await lxd.close();
  });

  test('start instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var operation = await client.startInstance('test-instance');
    operation = await client.waitOperation(operation.id);

    client.close();
    await lxd.close();
  });

  test('stop instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var operation = await client.stopInstance('test-instance');
    operation = await client.waitOperation(operation.id);

    client.close();
    await lxd.close();
  });

  test('restart instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var operation = await client.restartInstance('test-instance');
    operation = await client.waitOperation(operation.id);

    client.close();
    await lxd.close();
  });

  test('delete instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var operation = await client.deleteInstance('test-instance');
    operation = await client.waitOperation(operation.id);

    client.close();
    await lxd.close();
  });

  test('get networks', () async {
    var lxd = MockLxdServer(networks: {'lxdbr0': MockNetwork()});
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var networkNames = await client.getNetworks();
    expect(networkNames, equals(['lxdbr0']));

    client.close();
    await lxd.close();
  });

  test('get network', () async {
    var lxd = MockLxdServer(networks: {
      'lxdbr0': MockNetwork(
          config: {
            'ipv4.address': '10.0.0.1/24',
            'ipv4.nat': 'true',
            'ipv6.address': 'none'
          },
          description: 'My new LXD bridge',
          managed: true,
          status: 'Created',
          type: 'bridge')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var network = await client.getNetwork('lxdbr0');
    expect(
        network.config,
        equals({
          'ipv4.address': '10.0.0.1/24',
          'ipv4.nat': 'true',
          'ipv6.address': 'none'
        }));
    expect(network.description, equals('My new LXD bridge'));
    expect(network.managed, isTrue);
    expect(network.name, equals('lxdbr0'));
    expect(network.status, equals('Created'));
    expect(network.type, equals('bridge'));

    client.close();
    await lxd.close();
  });

  test('get network leases', () async {
    var lxd = MockLxdServer(networks: {
      'lxdbr0': MockNetwork(leases: [
        MockNetworkLease(
            address: '10.0.0.98',
            hostname: 'c1',
            hwaddr: '00:16:3e:2c:89:d9',
            location: 'lxd01',
            type: 'dynamic')
      ])
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var leases = await client.getNetworkLeases('lxdbr0');
    expect(leases, hasLength(1));
    var lease = leases[0];
    expect(lease.address, equals('10.0.0.98'));
    expect(lease.hostname, equals('c1'));
    expect(lease.hwaddr, equals('00:16:3e:2c:89:d9'));
    expect(lease.location, equals('lxd01'));
    expect(lease.type, equals('dynamic'));

    client.close();
    await lxd.close();
  });

  test('get network state', () async {
    var lxd = MockLxdServer(networks: {
      'lxdbr0': MockNetwork(
          state: MockNetworkState(
              addresses: [
            MockNetworkAddress(
                address: '10.0.0.1',
                family: 'inet',
                netmask: '24',
                scope: 'global')
          ],
              counters: MockNetworkCounters(
                  bytesReceived: 250542118,
                  bytesSent: 17524040140,
                  packetsReceived: 1182515,
                  packetsSent: 1567934),
              hwaddr: '00:16:3e:5a:83:57',
              mtu: 1500,
              state: 'up',
              type: 'broadcast'))
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var state = await client.getNetworkState('lxdbr0');
    expect(
        state.addresses,
        equals([
          LxdNetworkAddress(
              address: '10.0.0.1',
              family: 'inet',
              netmask: '24',
              scope: 'global')
        ]));
    expect(state.counters.bytesReceived, equals(250542118));
    expect(state.counters.bytesSent, equals(17524040140));
    expect(state.counters.packetsReceived, equals(1182515));
    expect(state.counters.packetsSent, equals(1567934));
    expect(state.hwaddr, equals('00:16:3e:5a:83:57'));
    expect(state.mtu, equals(1500));
    expect(state.state, equals('up'));
    expect(state.type, equals('broadcast'));

    client.close();
    await lxd.close();
  });

  test('get network acls', () async {
    var lxd = MockLxdServer(
        networkAcls: {'foo': MockNetworkAcl(), 'bar': MockNetworkAcl()});
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var aclNames = await client.getNetworkAcls();
    expect(aclNames, equals(['foo', 'bar']));

    client.close();
    await lxd.close();
  });

  test('get network acl', () async {
    var lxd = MockLxdServer(networkAcls: {
      'foo': MockNetworkAcl(
          config: {'user.mykey': 'foo'}, description: 'Web servers')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var acl = await client.getNetworkAcl('foo');
    expect(acl.config, equals({'user.mykey': 'foo'}));
    expect(acl.description, equals('Web servers'));
    expect(acl.name, equals('foo'));

    client.close();
    await lxd.close();
  });

  test('get profiles', () async {
    var lxd = MockLxdServer(
        profiles: {'default': MockProfile(), 'foo': MockProfile()});
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var profileNames = await client.getProfiles();
    expect(profileNames, equals(['default', 'foo']));

    client.close();
    await lxd.close();
  });

  test('get profile', () async {
    var lxd = MockLxdServer(profiles: {
      'foo': MockProfile(
          config: {'limits.cpu': '4', 'limits.memory': '4GiB'},
          description: 'Medium size instances')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var profile = await client.getProfile('foo');
    expect(
        profile.config, equals({'limits.cpu': '4', 'limits.memory': '4GiB'}));
    expect(profile.description, equals('Medium size instances'));
    expect(profile.name, equals('foo'));

    client.close();
    await lxd.close();
  });

  test('get projects', () async {
    var lxd = MockLxdServer(
        projects: {'default': MockProject(), 'foo': MockProject()});
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var projectNames = await client.getProjects();
    expect(projectNames, equals(['default', 'foo']));

    client.close();
    await lxd.close();
  });

  test('get project', () async {
    var lxd = MockLxdServer(projects: {
      'foo': MockProject(
          config: {'features.networks': 'false', 'features.profiles': 'true'},
          description: 'My new project')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var project = await client.getProject('foo');
    expect(project.config,
        equals({'features.networks': 'false', 'features.profiles': 'true'}));
    expect(project.description, equals('My new project'));
    expect(project.name, equals('foo'));

    client.close();
    await lxd.close();
  });

  test('get storage pools', () async {
    var lxd = MockLxdServer(storagePools: {
      'local': MockStoragePool(),
      'remote': MockStoragePool()
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var poolNames = await client.getStoragePools();
    expect(poolNames, equals(['local', 'remote']));

    client.close();
    await lxd.close();
  });

  test('get storage pool', () async {
    var lxd = MockLxdServer(storagePools: {
      'local': MockStoragePool(
          config: {'volume.block.filesystem': 'ext4', 'volume.size': '50GiB'},
          description: 'Local SSD pool',
          status: 'Created')
    });
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var pool = await client.getStoragePool('local');
    expect(pool.config,
        equals({'volume.block.filesystem': 'ext4', 'volume.size': '50GiB'}));
    expect(pool.description, equals('Local SSD pool'));
    expect(pool.name, equals('local'));
    expect(pool.status, equals('Created'));

    client.close();
    await lxd.close();
  });

  test('get operations', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    var operation1 = await client.startInstance('test-instance1');
    var operation2 = await client.startInstance('test-instance2');
    var operation3 = await client.startInstance('test-instance3');

    var operations = await client.getOperations();
    expect(
        operations,
        equals({
          'running': [operation1.id, operation2.id, operation3.id]
        }));

    var operation = await client.getOperation(operation1.id);
    expect(operation.id, equals(operation1.id));

    client.close();
    await lxd.close();
  });
}
