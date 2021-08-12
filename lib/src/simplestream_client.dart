import 'dart:convert';
import 'dart:io';

class SimplestreamProduct {
  final List<String> aliases;
  final String architecture;
  final String os;
  final String release;
  final String releaseCodename;
  final String releaseTitle;
  final bool supported;
  final DateTime supportEol;
  final String version;
  final Map<String, Map<String, SimplestreamItem>> versions;

  SimplestreamProduct(
      {required this.aliases,
      required this.architecture,
      required this.os,
      required this.release,
      required this.releaseCodename,
      required this.releaseTitle,
      required this.supported,
      required this.supportEol,
      required this.version,
      required this.versions});
}

class SimplestreamItem {
  final String? combinedDisk1ImgSha256;
  final String? combinedSquashfsSha256;
  final String ftype;
  final String? md5;
  final String path;
  final String? sha256;
  final int size;

  SimplestreamItem(
      {this.combinedDisk1ImgSha256,
      this.combinedSquashfsSha256,
      required this.ftype,
      this.md5,
      required this.path,
      this.sha256,
      required this.size});
}

/// Manages a connection to the lxd server.
class SimplestreamClient {
  final HttpClient _client = HttpClient();
  final String url;
  String? _userAgent;

  SimplestreamClient(this.url, {String userAgent = 'lxd.dart'})
      : _userAgent = userAgent;

  /// Sets the user agent sent in requests to the simple streams server.
  set userAgent(String? value) => _userAgent = value;

  Future<void> getStreams() async {
    var body = await _getJson('streams/v1/index.json');
    var format = body['format'];
    if (format != 'index:1.0') {
      throw 'Unsupported simplestream index format $format';
    }
    var index = body['index'] as Map<String, dynamic>;
    for (var entry in index.entries) {
      var products = entry.value as Map<String, dynamic>;
      var format = products['format'];
      if (format != 'products:1.0') {
        throw 'Unsupported simplestream products format $format';
      }
      var datatype = products['datatype'];
      switch (datatype) {
        case 'image-ids':
          break;
        case 'image-downloads':
          break;
        default:
          continue;
      }
    }
  }

  Future<List<SimplestreamProduct>> getProducts(String path) async {
    var body = await _getJson(path);
    var format = body['format'];
    if (format != 'products:1.0') {
      throw 'Unsupported simplestream products format $format';
    }
    var products = <SimplestreamProduct>[];
    var datatype = body['datatype'];
    switch (datatype) {
      case 'image-ids':
        break;
      case 'image-downloads':
        for (var entry in body['products'].entries) {
          var product = entry.value;
          var versions = <String, Map<String, SimplestreamItem>>{};
          for (var versionItem in product['versions'].entries) {
            var version = versionItem.value;
            var items = <String, SimplestreamItem>{};
            for (var itemEntry in version['items'].entries) {
              var item = itemEntry.value;
              items[itemEntry.key] = SimplestreamItem(
                  combinedDisk1ImgSha256: item['combined_disk1-img_sha256'],
                  combinedSquashfsSha256: item['combined_squashfs_sha256'],
                  ftype: item['ftype'],
                  md5: item['md5'],
                  path: item['path'],
                  sha256: item['sha256'],
                  size: item['size']);
            }
            versions[versionItem.key] = items;
          }
          products.add(SimplestreamProduct(
              aliases: product['aliases'].split(','),
              architecture: product['arch'],
              os: product['os'],
              release: product['release'],
              releaseCodename: product['release_codename'],
              releaseTitle: product['release_title'],
              supported: product['supported'],
              supportEol: DateTime.parse(product['support_eol']),
              version: product['version'],
              versions: versions));
        }
        break;
    }
    return products;
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    var request = await _client.getUrl(Uri.parse('$url/$path'));
    _setHeaders(request);
    var response = await request.close();
    var body =
        await response.transform(utf8.decoder).transform(json.decoder).first;
    return body as Map<String, dynamic>;
  }

  /// Makes base HTTP headers to send.
  void _setHeaders(HttpClientRequest request) {
    if (_userAgent != null) {
      request.headers.set('User-Agent', _userAgent!);
    }
  }

  /// Terminates all active connections. If a client remains unclosed, the Dart process may not terminate.
  void close() {
    _client.close();
  }
}
