import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lxd/lxd.dart';
import 'package:lxd/src/simplestream_client.dart';
import 'package:test/test.dart';

class MockLxdServer {
  Directory? _tempDir;
  String? _socketPath;
  HttpServer? _server;
  ServerSocket? _unixSocket;
  StreamSubscription<Socket>? _unixSubscription;
  StreamSubscription<HttpRequest>? _requestSubscription;
  final _tcpSockets = <Socket, Socket>{};

  String get socketPath => _socketPath!;

  MockLxdServer();

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
    _writeSyncResponse(response, []);
  }

  void _getImages(HttpResponse response) {
    _writeSyncResponse(response, []);
  }

  void _getImage(HttpResponse response, String fingerprint) {
    _writeSyncResponse(response, {
      'architecture': '',
      'auto_update': false,
      'cached': false,
      'created_at': '2018-10-23T12:03:31.917735286+13:00',
      'expires_at': '2018-10-23T12:03:31.917735286+13:00',
      'filename': '',
      'fingerprint': '',
      'last_used_at': '2018-10-23T12:03:31.917735286+13:00',
      'profiles': [],
      'public': false,
      'size': 0,
      'type': '',
      'uploaded_at': '2018-10-23T12:03:31.917735286+13:00'
    });
  }

  void _getInstances(HttpResponse response) {
    _writeSyncResponse(response, []);
  }

  void _getInstance(HttpResponse response, String name) {
    _writeSyncResponse(response, {
      'architecture': '',
      'config': {},
      'created_at': '2018-10-23T12:03:31.917735286+13:00',
      'description': '',
      'ephemeral': false,
      'last_used_at': '2018-10-23T12:03:31.917735286+13:00',
      'location': '',
      'name': '',
      'profiles': [],
      'stateful': false,
      'status': '',
      'status_code': 0,
      'type': ''
    });
  }

  void _getInstanceState(HttpResponse response, String name) {
    _writeSyncResponse(
        response, {'network': {}, 'pid': 0, 'status': '', 'status_code': 0});
  }

  void _putInstanceState(HttpResponse response, String name) {
    _writeOperationResponse(response);
  }

  void _createInstance(HttpResponse response) {
    _writeOperationResponse(response);
  }

  void _deleteInstance(HttpResponse response, String name) {
    _writeOperationResponse(response);
  }

  void _getNetworks(HttpResponse response) {
    _writeSyncResponse(response, []);
  }

  void _getNetwork(HttpResponse response, String name) {
    _writeSyncResponse(response, {
      'config': {},
      'description': '',
      'managed': false,
      'name': '',
      'status': '',
      'type': ''
    });
  }

  void _getNetworkLeases(HttpResponse response, String name) {
    _writeSyncResponse(response, []);
  }

  void _getNetworkState(HttpResponse response, String name) {
    _writeSyncResponse(response,
        {'addresses': [], 'hwaddr': '', 'mtu': 0, 'state': '', 'type': ''});
  }

  void _getNetworkAcls(HttpResponse response) {
    _writeSyncResponse(response, []);
  }

  void _getProfiles(HttpResponse response) {
    _writeSyncResponse(response, []);
  }

  void _getProfile(HttpResponse response, String name) {
    _writeSyncResponse(response, {'config': {}, 'description': '', 'name': ''});
  }

  void _getProjects(HttpResponse response) {
    _writeSyncResponse(response, []);
  }

  void _getProject(HttpResponse response, String name) {
    _writeSyncResponse(response, {'config': {}, 'description': '', 'name': ''});
  }

  void _getStoragePools(HttpResponse response) {
    _writeSyncResponse(response, []);
  }

  void _getStoragePool(HttpResponse response, String name) {
    _writeSyncResponse(
        response, {'config': {}, 'description': '', 'name': '', 'status': ''});
  }

  void _writeOperationResponse(HttpResponse response) {
    _writeAsyncResponse(response, {
      'created_at': '2018-10-23T12:03:31.917735286+13:00',
      'description': '',
      'err': '',
      'id': '',
      'resources': {},
      'may_cancel': false,
      'status': '',
      'status_code': 0,
      'updated_at': '2018-10-23T12:03:31.917735286+13:00'
    });
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
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var certificates = */ await client.getCertificates();

    client.close();
    await lxd.close();
  });

  test('get images', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var fingerprints = */ await client.getImages();

    client.close();
    await lxd.close();
  });

  test('get image', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var image = */ await client.getImage('test-image');

    client.close();
    await lxd.close();
  });

  test('get instances', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var instanceNames = */ await client.getInstances();

    client.close();
    await lxd.close();
  });

  test('get instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var instance = */ await client.getInstance('test-instance');

    client.close();
    await lxd.close();
  });

  test('get instance state', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var state = */ await client.getInstanceState('test-instance');

    client.close();
    await lxd.close();
  });

  test('create instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var operation = */ await client.createInstance(
        source: SimplestreamDownloadItem(ftype: '', path: '', size: 0),
        url: 'https://example.com');

    client.close();
    await lxd.close();
  });

  test('start instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var operation = */ await client.startInstance('test-instance');

    client.close();
    await lxd.close();
  });

  test('stop instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var operation = */ await client.stopInstance('test-instance');

    client.close();
    await lxd.close();
  });

  test('restart instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var operation = */ await client.restartInstance('test-instance');

    client.close();
    await lxd.close();
  });

  test('delete instance', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var operation = */ await client.deleteInstance('test-instance');

    client.close();
    await lxd.close();
  });

  test('get networks', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var networkNames = */ await client.getNetworks();

    client.close();
    await lxd.close();
  });

  test('get network', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var network = */ await client.getNetwork('eth0');

    client.close();
    await lxd.close();
  });

  test('get network leases', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var leases = */ await client.getNetworkLeases('eth0');

    client.close();
    await lxd.close();
  });

  test('get network state', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var state = */ await client.getNetworkState('eth0');

    client.close();
    await lxd.close();
  });

  test('get network acls', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var aclNames = */ await client.getNetworkAcls();

    client.close();
    await lxd.close();
  });

  test('get network acl', () async {});

  test('get profiles', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var profileNames = */ await client.getProfiles();

    client.close();
    await lxd.close();
  });

  test('get profile', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var profile = */ await client.getProfile('test-profile');

    client.close();
    await lxd.close();
  });

  test('get projects', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var projectNames = */ await client.getProjects();

    client.close();
    await lxd.close();
  });

  test('get project', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var project = */ await client.getProject('test-project');

    client.close();
    await lxd.close();
  });

  test('get storage pools', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var poolNames = */ await client.getStoragePools();

    client.close();
    await lxd.close();
  });

  test('get storage pool', () async {
    var lxd = MockLxdServer();
    await lxd.start();

    var client = LxdClient(socketPath: lxd.socketPath);
    /*var pool = */ await client.getStoragePool('test-pool');

    client.close();
    await lxd.close();
  });
}
