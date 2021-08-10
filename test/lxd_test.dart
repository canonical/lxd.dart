import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lxd/lxd.dart';
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
    switch (request.uri.path) {
      case '/1.0':
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
        break;
      case '/1.0/resources':
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
        break;
      default:
        response.statusCode = HttpStatus.notFound;
        _writeErrorResponse(response, 'not found');
        break;
    }
    response.close();
  }

  void _writeSyncResponse(HttpResponse response, dynamic metadata) {
    _writeJson(response, {
      'type': 'sync',
      'status': 'Success',
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
}
