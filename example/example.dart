import 'package:lxd/lxd.dart';
import 'package:lxd/src/simplestream_client.dart';

void main() async {
  var client = LxdClient();

  print('Looking for image...');
  var url = 'https://cloud-images.ubuntu.com/releases';
  var download = await findLxdDownload(url, 'ubuntu', architecture: 'amd64');
  if (download == null) {
    print("Can't find image");
    return;
  }
  print('Creating instance...');
  var operation = await client.createInstance(
      url: url, source: download, status: 'Running');
  operation = await client.waitOperation(operation.id);
  if (operation.status == 'Success') {
    print('Instance ${operation.instanceNames.first} created.');
  } else {
    print('Failed: ${operation.error}');
  }

  client.close();
}

Future<SimplestreamDownloadItem?> findLxdDownload(String url, String name,
    {required String architecture}) async {
  var s = SimplestreamClient(url);
  var products = await s.getProducts();
  for (var product in products) {
    if (!product.aliases.contains(name) ||
        product.architecture != architecture) {
      continue;
    }

    var download = findLxdDownloadItem(product);
    if (download != null) {
      return download;
    }
  }

  return null;
}

SimplestreamDownloadItem? findLxdDownloadItem(SimplestreamProduct product) {
  var version = product.versions.values.first;

  for (var v in version.values) {
    if (v is SimplestreamDownloadItem && v.ftype == 'lxd.tar.xz') {
      return v;
    }
  }

  return null;
}
