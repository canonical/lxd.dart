import 'package:lxd/lxd.dart';

void main() async {
  var client = LxdClient();

  var instances = await client.getInstances();
  print('NAME STATE TYPE');
  for (var instance in instances) {
    print('${instance.name} ${instance.status} ${instance.type}');
  }

  client.close();
}
