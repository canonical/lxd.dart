import 'package:lxd/lxd.dart';

void main() async {
  var client = LxdClient();

  var instanceNames = await client.getInstances();
  print('NAME STATE IPV4 IPV6 TYPE');
  for (var name in instanceNames) {
    var instance = await client.getInstance(name);
    var state = await client.getInstanceState(name);
    var addresses4 = <String>[];
    var addresses6 = <String>[];
    for (var interface in state.network.keys) {
      if (interface == 'lo') {
        continue;
      }
      for (var address in state.network[interface]!.addresses) {
        if (address.scope == 'link' || address.scope == 'local') {
          continue;
        }
        if (address.family == 'inet') {
          addresses4.add('${address.address} ($interface)');
        } else if (address.family == 'inet6') {
          addresses6.add('${address.address} ($interface)');
        }
      }
    }
    print(
        '${instance.name} ${instance.status} ${addresses4.join(',')} ${addresses6.join(',')} ${instance.type}');
  }

  client.close();
}
