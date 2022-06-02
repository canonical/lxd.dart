import 'dart:convert';
import 'dart:io';

/// A product available on a Simplestream server.
class SimplestreamProduct {
  /// Aliases of this product name.
  final Set<String> aliases;

  /// The architecture this product is for, e.g. 'amd64'.
  final String? architecture;

  /// The operating system provided.
  final String? os;

  /// The release of this product.
  final String? release;

  /// Human readable title for this product release.
  final String? releaseTitle;

  /// Versions available of this product.
  final Map<String, Map<String, SimplestreamDownloadItem>> versions;

  SimplestreamProduct(
      {this.aliases = const {},
      this.architecture,
      this.os,
      this.release,
      this.releaseTitle,
      required this.versions});
}

/// An item that can be downloaded for a [SimplestreamProduct].
class SimplestreamDownloadItem {
  /// The type of this download item, e.g. 'lxd.tar.gz' or 'squashfs'
  final String ftype;

  /// Path to the download item, e.g. 'images/ubuntu/bionic/amd64/default/20220530_07:46/lxd.tar.gz'
  final String path;

  /// Size of the item in bytes.
  final int size;

  /// SHA-256 checksum of this item.
  final String? sha256;

  /// SHA-256 of the disk.img item associated with this item.
  final String? combinedDisk1ImgSha256;

  /// SHA-256 of the squashfs item associated with this item.
  final String? combinedSquashfsSha256;

  SimplestreamDownloadItem(
      {required this.ftype,
      required this.path,
      required this.size,
      this.sha256,
      this.combinedDisk1ImgSha256,
      this.combinedSquashfsSha256});

  @override
  String toString() =>
      'SimplestreamDownloadItem(ftype: $ftype, path: $path, size: $size, sha256: $sha256, combinedDisk1ImgSha256: $combinedDisk1ImgSha256, combinedSquashfsSha256: $combinedSquashfsSha256)';
}

/// Manages a connection to the lxd server.
class SimplestreamClient {
  /// The URL this client is connected to.
  final String url;

  final HttpClient _client = HttpClient();
  final String? _userAgent;

  SimplestreamClient(this.url, {String? userAgent = 'lxd.dart'})
      : _userAgent = userAgent;

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
    if (datatype != 'image-downloads') {
      throw 'Unsupported simplestream products datatype $datatype';
    }

    for (var entry in body['products'].entries) {
      var product = entry.value;
      var versions = <String, Map<String, SimplestreamDownloadItem>>{};
      for (var versionItem in product['versions'].entries) {
        var version = versionItem.value;
        var items = <String, SimplestreamDownloadItem>{};
        for (var itemEntry in version['items'].entries) {
          var item = itemEntry.value;
          items[itemEntry.key] = SimplestreamDownloadItem(
              combinedDisk1ImgSha256: item['combined_disk1-img_sha256'],
              combinedSquashfsSha256: item['combined_squashfs_sha256'],
              ftype: item['ftype'],
              path: item['path'],
              sha256: item['sha256'],
              size: item['size']);
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
          os: product['os'],
          release: product['release'],
          releaseTitle: product['release_title'],
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
