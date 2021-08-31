import 'dart:convert';
import 'dart:io';

class SimplestreamProduct {
  final Set<String> aliases;
  final String? architecture;
  final String? crsn;
  final String? os;
  final String? release;
  final String? releaseCodename;
  final String? releaseTitle;
  final bool supported;
  final DateTime? supportEol;
  final String? version;
  final Map<String, Map<String, SimplestreamItem>> versions;

  SimplestreamProduct(
      {this.aliases = const {},
      this.architecture,
      this.crsn,
      this.os,
      this.release,
      this.releaseCodename,
      this.releaseTitle,
      this.supported = true,
      this.supportEol,
      this.version,
      required this.versions});
}

abstract class SimplestreamItem {}

class SimplestreamIdItem extends SimplestreamItem {
  final String? crsn;
  final String? id;
  final String? rootStore;
  final String? virt;

  SimplestreamIdItem(
      {required this.crsn,
      required this.id,
      required this.rootStore,
      required this.virt});
}

class SimplestreamDownloadItem extends SimplestreamItem {
  final String? combinedDisk1ImgSha256;
  final String? combinedSquashfsSha256;
  final String ftype;
  final String? md5;
  final String path;
  final String? sha256;
  final int size;

  SimplestreamDownloadItem(
      {this.combinedDisk1ImgSha256,
      this.combinedSquashfsSha256,
      required this.ftype,
      this.md5,
      required this.path,
      this.sha256,
      required this.size});

  @override
  String toString() =>
      'SimplestreamDownloadItem(combinedDisk1ImgSha256: $combinedDisk1ImgSha256, combinedSquashfsSha256: $combinedSquashfsSha256, ftype: $ftype, md5: $md5, path: $path, sha256: $sha256, size: $size)';
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

  /// Gets all the products this server provides.
  /// If provided, only gets products with the given [datatype].
  Future<List<SimplestreamProduct>> getProducts({String? datatype}) async {
    var products = <SimplestreamProduct>[];

    var body = await _getJson('streams/v1/index.json');
    var format = body['format'];
    if (format != 'index:1.0') {
      throw 'Unsupported simplestream index format $format';
    }
    var index = body['index'] as Map<String, dynamic>;
    for (var entry in index.entries) {
      var products_ = entry.value as Map<String, dynamic>;
      var format = products_['format'];
      if (format != 'products:1.0') {
        throw 'Unsupported simplestream products format $format';
      }
      if (datatype != null && products_['datatype'] != datatype) {
        continue;
      }
      var path = products_['path'];
      products.addAll(await _getProducts(path));
    }

    return products;
  }

  Future<List<SimplestreamProduct>> _getProducts(String path) async {
    var body = await _getJson(path);
    var format = body['format'];
    if (format != 'products:1.0') {
      throw 'Unsupported simplestream products format $format';
    }
    var products = <SimplestreamProduct>[];
    var datatype = body['datatype'];
    for (var entry in body['products'].entries) {
      var product = entry.value;
      var versions = <String, Map<String, SimplestreamItem>>{};
      for (var versionItem in product['versions'].entries) {
        var version = versionItem.value;
        var items = <String, SimplestreamItem>{};
        for (var itemEntry in version['items'].entries) {
          var item = itemEntry.value;

          SimplestreamItem i;
          switch (datatype) {
            case 'image-ids':
              i = SimplestreamIdItem(
                  crsn: item['crsn'],
                  id: item['id'],
                  rootStore: item['root_store'],
                  virt: item['virt']);
              break;
            case 'image-downloads':
              i = SimplestreamDownloadItem(
                  combinedDisk1ImgSha256: item['combined_disk1-img_sha256'],
                  combinedSquashfsSha256: item['combined_squashfs_sha256'],
                  ftype: item['ftype'],
                  md5: item['md5'],
                  path: item['path'],
                  sha256: item['sha256'],
                  size: item['size']);
              break;
            default:
              continue;
          }

          items[itemEntry.key] = i;
          versions[versionItem.key] = items;
        }
      }
      var aliases = <String>{};
      for (var alias in (product['aliases'] ?? '').split(',')) {
        aliases.add(alias);
      }
      products.add(SimplestreamProduct(
          aliases: aliases,
          architecture: product['arch'],
          crsn: product['crsn'],
          os: product['os'],
          release: product['release'],
          releaseCodename: product['release_codename'],
          releaseTitle: product['release_title'],
          supported: product['supported'] ?? true,
          supportEol: product.containsKey('support_eol')
              ? DateTime.parse(product['support_eol'])
              : null,
          version: product['version'],
          versions: versions));
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
