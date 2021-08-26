import 'package:lxd/lxd.dart';

void main() async {
  var client = LxdClient();

  var operation = await client.deleteInstance('dart-test');
  operation = await client.waitOperation(operation.id);
  print(operation);

  client.close();
}
