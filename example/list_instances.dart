import 'package:lxd/lxd.dart';

void main() async {
  var client = LxdClient();

  var instanceNames = await client.getInstances();
  print('NAME STATE TYPE');
  for (var name in instanceNames) {
    var instance = await client.getInstance(name);
    print('${instance.name} ${instance.status} ${instance.type}');
  }

  client.close();
}
