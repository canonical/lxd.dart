import 'dart:math';

import 'package:lxd/lxd.dart';

void main(List<String> args) async {
  var remote = 'local';
  if (args.isNotEmpty) {
    remote = args[0];
  }

  var rows = <List<String>>[
    [
      'ALIAS',
      'FINGERPRINT',
      'PUBLIC',
      'DESCRIPTION',
      'ARCHITECTURE',
      'TYPE',
      'SIZE',
      'UPLOAD DATE'
    ]
  ];
  if (remote == 'local') {
    var client = LxdClient();
    for (var fingerprint in await client.getImages()) {
      var image = await client.getImage(fingerprint);
      rows.add([
        '',
        image.fingerprint.substring(0, 12),
        'no',
        image.properties['description'] ?? '',
        image.architecture,
        image.type.name,
        image.size.toString(),
        image.uploadedAt.toString()
      ]);
    }
    client.close();
  } else {
    var url = {
      'images': 'https://images.linuxcontainers.org',
      'ubuntu': 'https://cloud-images.ubuntu.com/releases',
      'ubuntu-daily': 'https://cloud-images.ubuntu.com/daily'
    }[remote];
    if (url == null) {
      print('Unknown remote $remote');
      return;
    }

    var client = LxdClient();
    var images = await client.getRemoteImages(url);
    for (var image in images) {
      rows.add([
        image.aliases.first,
        image.fingerprint.substring(0, 12),
        'yes',
        image.description,
        image.architecture,
        {
              LxdRemoteImageType.container: 'CONTAINER',
              LxdRemoteImageType.virtualMachine: 'VIRTUAL-MACHINE'
            }[image.type] ??
            '',
        image.size.toString(),
        ''
      ]);
    }
    client.close();
  }

  var widths = <int>[];
  for (var i = 0; i < rows[0].length; i++) {
    widths.add(rows.fold(0, (width, row) => max(width, row[i].length)));
  }
  for (var row in rows) {
    var paddedRow = [];
    for (var i = 0; i < row.length; i++) {
      paddedRow.add(row[i].padLeft(widths[i]));
    }
    print(paddedRow.join(' | '));
  }
}
