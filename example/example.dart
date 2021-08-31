import 'package:lxd/lxd.dart';

void main() async {
  var client = LxdClient();

  print('Looking for image...');
  var url = 'https://cloud-images.ubuntu.com/releases';
  var source = await client.findRemoteImage(url, '20.04');
  if (source == null) {
    print("Can't find image");
    return;
  }
  print('Creating instance...');
  var operation = await client.createInstance(url: url, source: source);
  operation = await client.waitOperation(operation.id);
  if (operation.status == 'Success') {
    print('Instance ${operation.instanceNames.first} created.');
  } else {
    print('Failed: ${operation.error}');
  }

  client.close();
}
