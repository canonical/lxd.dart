import 'package:lxd/lxd.dart';

void main() async {
  var client = LxdClient();

  print('Looking for image...');
  var image = await client.findRemoteImage(
      'https://cloud-images.ubuntu.com/releases', '20.04');
  if (image == null) {
    print("Can't find image");
    return;
  }
  print('Creating instance...');
  var operation = await client.createInstance(image: image);
  operation = await client.waitOperation(operation.id);
  if (operation.status == 'Success') {
    print('Instance ${operation.resources['instances']} created.');
  } else {
    print('Failed: ${operation.error}');
  }

  client.close();
}
