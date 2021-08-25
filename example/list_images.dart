import 'package:lxd/lxd.dart';
import 'package:lxd/src/simplestream_client.dart';

void main(List<String> args) async {
  var remote = 'local';
  if (args.isNotEmpty) {
    remote = args[0];
  }

  switch (remote) {
    case 'local':
      var client = LxdClient();
      for (var image in await client.getImages()) {
        print(image);
      }
      client.close();
      break;

    case 'images':
      await listSimpleStreamImages('https://images.linuxcontainers.org');
      break;

    case 'ubuntu':
      await listSimpleStreamImages('https://cloud-images.ubuntu.com/releases');
      break;

    case 'ubuntu-daily':
      await listSimpleStreamImages('https://cloud-images.ubuntu.com/daily');
      break;

    default:
      print('Unknown remote $remote');
      break;
  }
}

Future<void> listSimpleStreamImages(String url) async {
  var s = SimplestreamClient(url);
  var products = await s.getProducts();
  for (var product in products) {
    for (var v in product.versions.values) {
      var lxdItem = v['lxd.tar.xz'];
      if (lxdItem == null) {
        continue;
      }

      var squashfsItem = v['squashfs'] ?? v['root.squashfs'];
      if (squashfsItem != null && lxdItem.combinedSquashfsSha256 != null) {
        print(
            '${product.aliases[0]} ${lxdItem.combinedSquashfsSha256?.substring(0, 12)} ${product.releaseTitle} ${product.architecture} CONTAINER ${squashfsItem.size}');
      }
      var disk1ImgItem = v['disk1.img'];
      if (disk1ImgItem != null && lxdItem.combinedDisk1ImgSha256 != null) {
        print(
            '${product.aliases[0]} ${lxdItem.combinedDisk1ImgSha256?.substring(0, 12)} ${product.releaseTitle} ${product.architecture} VIRTUAL-MACHINE ${disk1ImgItem.size}');
      }
    }
  }
  s.close();
}
