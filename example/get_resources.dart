import 'package:lxd/lxd.dart';

void main() async {
  var client = LxdClient();

  var resources = await client.getResources();
  print('cpu:');
  print(' - architecture: ${resources.cpu.architecture}');
  print('memory:');
  print(' - used: ${resources.memory.used} bytes');
  print(' - total: ${resources.memory.total} bytes');
  print('gpu:');
  for (var card in resources.gpuCards) {
    print(' - ${card.vendor != '' ? card.vendor : card.vendorId}');
  }
  print('network:');
  for (var card in resources.networkCards) {
    print(' - ${card.vendor != '' ? card.vendor : card.vendorId}');
  }
  print('pci:');
  for (var device in resources.pciDevices) {
    print(' - ${device.product != '' ? device.product : device.productId}');
  }
  print('storage:');
  for (var disk in resources.storageDisks) {
    print(' - ${disk.model}');
    print('   - size: ${disk.size} bytes');
  }
  print('usb:');
  for (var device in resources.usbDevices) {
    print(' - ${device.product != '' ? device.product : device.productId}');
  }

  client.close();
}
