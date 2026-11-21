// Ruby's page.get_device_info and page.set_allowed_device_orientations: Page
// (control id 1) methods the Page control answers on both designs.
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ruflet/ruflet.dart';

import '../support/control_harness.dart';

/// Mounts the Page control with one View, as a Ruby session does.
Future<HarnessBackend> _mountPage(
    WidgetTester tester, HarnessDesign design) async {
  final backend = HarnessBackend(design)..isLoading = false;
  final view = Control.fromMap({
    '_c': 'View',
    '_i': 20,
    'route': '/',
    'controls': [
      {'_c': 'Text', '_i': 21, 'value': 'Home'}
    ],
  }, backend, parent: backend.page);
  backend.page.update({
    'platform': design.platform.name,
    'views': [view]
  }, shouldNotify: true);
  await tester.pumpWidget(ChangeNotifierProvider<RufletBackend>.value(
      value: backend, child: ControlWidget(control: backend.page)));
  await tester.pumpAndSettle();
  return backend;
}

/// Records SystemChrome.setPreferredOrientations calls.
List<Object?> _recordOrientationCalls(WidgetTester tester) {
  final calls = <Object?>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') {
      calls.add(call.arguments);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

LinuxDeviceInfo _linux() => LinuxDeviceInfo(
      name: 'Fedora Linux',
      version: '40 (Workstation Edition)',
      id: 'fedora',
      idLike: const ['rhel'],
      versionCodename: '',
      versionId: '40',
      prettyName: 'Fedora Linux 40 (Workstation Edition)',
      buildId: null,
      variant: 'Workstation Edition',
      variantId: 'workstation',
      machineId: 'abc123',
    );

// Flet's AndroidDeviceInfo, IosDeviceInfo, MacOsDeviceInfo,
// WindowsDeviceInfo, LinuxDeviceInfo and WebDeviceInfo field names, plus
// DeviceInfo.locales.
const _fletFields = {
  'android': [
    'available_ram_size', 'board', 'bootloader', 'brand', 'device', //
    'display', 'fingerprint', 'free_disk_size', 'hardware', 'host', 'id',
    'is_low_ram_device', 'is_physical_device', 'manufacturer', 'model',
    'name', 'physical_ram_size', 'product', 'supported_32_bit_abis',
    'supported_64_bit_abis', 'supported_abis', 'system_features', 'tags',
    'total_disk_size', 'type', 'version', 'locales',
  ],
  'ios': [
    'available_ram_size', 'free_disk_size', 'is_ios_app_on_mac', //
    'is_physical_device', 'localized_model', 'model', 'model_name', 'name',
    'physical_ram_size', 'system_name', 'system_version', 'total_disk_size',
    'utsname', 'identifier_for_vendor', 'locales',
  ],
  'macos': [
    'active_cpus', 'arch', 'computer_name', 'cpu_frequency', 'host_name', //
    'kernel_version', 'major_version', 'memory_size', 'minor_version',
    'model', 'model_name', 'os_release', 'patch_version', 'system_guid',
    'locales',
  ],
  'windows': [
    'computer_name', 'number_of_cores', 'system_memory', 'user_name', //
    'major_version', 'minor_version', 'build_number', 'platform_id',
    'csd_version', 'service_pack_major', 'service_pack_minor', 'suit_mask',
    'product_type', 'reserved', 'build_lab', 'build_lab_ex',
    'display_version', 'edition_id', 'install_date', 'product_id',
    'product_name', 'registered_owner', 'release_id', 'device_id', 'locales',
  ],
  'linux': [
    'name', 'id', 'pretty_name', 'version', 'id_like', 'version_code_name', //
    'version_id', 'build_id', 'variant', 'variant_id', 'machine_id',
    'locales',
  ],
  'web': [
    'browser_name', 'app_code_name', 'app_name', 'app_version', //
    'device_memory', 'language', 'languages', 'platform', 'product',
    'product_sub', 'user_agent', 'vendor', 'vendor_sub', 'max_touch_points',
    'hardware_concurrency', 'locales',
  ],
};

Map<String, BaseDeviceInfo> _records() => {
      'android': AndroidDeviceInfo.fromMap({
        'version': {
          'baseOS': '',
          'codename': 'REL',
          'incremental': '12345',
          'previewSdkInt': 0,
          'release': '15',
          'sdkInt': 35,
          'securityPatch': '2024-09-05',
        },
        'board': 'shiba',
        'bootloader': 'ripcurrent',
        'brand': 'google',
        'device': 'shiba',
        'display': 'AP2A.240905.003',
        'fingerprint': 'google/shiba',
        'hardware': 'shiba',
        'host': 'build',
        'id': 'AP2A',
        'manufacturer': 'Google',
        'model': 'Pixel 8',
        'product': 'shiba',
        'name': 'Pixel 8',
        'supported32BitAbis': <String>[],
        'supported64BitAbis': ['arm64-v8a'],
        'supportedAbis': ['arm64-v8a'],
        'tags': 'release-keys',
        'type': 'user',
        'isPhysicalDevice': true,
        'freeDiskSize': 1000,
        'totalDiskSize': 2000,
        'systemFeatures': ['android.hardware.camera'],
        'isLowRamDevice': false,
        'physicalRamSize': 8000,
        'availableRamSize': 4000,
      }),
      'ios': IosDeviceInfo.fromMap({
        'name': 'iPhone',
        'systemName': 'iOS',
        'systemVersion': '18.0',
        'model': 'iPhone',
        'modelName': 'iPhone 15',
        'localizedModel': 'iPhone',
        'identifierForVendor': 'vendor-id',
        'freeDiskSize': 1000,
        'totalDiskSize': 2000,
        'isPhysicalDevice': true,
        'physicalRamSize': 6000,
        'availableRamSize': 3000,
        'isiOSAppOnMac': false,
        'isiOSAppOnVision': false,
        'utsname': {
          'sysname': 'Darwin',
          'nodename': 'iPhone',
          'release': '24.0.0',
          'version': 'Darwin Kernel',
          'machine': 'iPhone16,1',
        },
      }),
      'macos': MacOsDeviceInfo.fromMap({
        'computerName': 'Mac',
        'hostName': 'mac.local',
        'arch': 'arm64',
        'model': 'Mac15,3',
        'modelName': 'MacBook Pro',
        'kernelVersion': 'Darwin 24',
        'osRelease': '15.0',
        'majorVersion': 15,
        'minorVersion': 0,
        'patchVersion': 0,
        'activeCPUs': 8,
        'memorySize': 16000,
        'cpuFrequency': 0,
        'systemGUID': 'guid',
      }),
      'windows': WindowsDeviceInfo(
        computerName: 'PC',
        numberOfCores: 8,
        systemMemoryInMegabytes: 16000,
        userName: 'user',
        majorVersion: 10,
        minorVersion: 0,
        buildNumber: 22631,
        platformId: 2,
        csdVersion: '',
        servicePackMajor: 0,
        servicePackMinor: 0,
        suitMask: 256,
        productType: 1,
        reserved: 0,
        buildLab: 'lab',
        buildLabEx: 'lab.ex',
        digitalProductId: Uint8List(0),
        displayVersion: '23H2',
        editionId: 'Professional',
        installDate: DateTime.utc(2024),
        productId: 'id',
        productName: 'Windows 11 Pro',
        registeredOwner: 'owner',
        releaseId: '2009',
        deviceId: 'device',
      ),
      'linux': _linux(),
      'web': WebBrowserInfo(
        appCodeName: 'Mozilla',
        appName: 'Netscape',
        appVersion: '5.0',
        deviceMemory: 8,
        language: 'en-US',
        languages: const ['en-US'],
        platform: 'MacIntel',
        product: 'Gecko',
        productSub: '20030107',
        userAgent: 'Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15 '
            '(KHTML, like Gecko) Version/18.0 Safari/605.1.15',
        vendor: 'Apple Computer, Inc.',
        vendorSub: '',
        maxTouchPoints: 0,
        hardwareConcurrency: 8,
      ),
    };

void main() {
  tearDown(() {
    debugDeviceInfoSource = null;
    debugDefaultTargetPlatformOverride = null;
  });

  test('every device record maps to Flet\'s field names', () {
    final records = _records();
    for (final entry in _fletFields.entries) {
      final map = records[entry.key]!.asMap();
      expect(map.keys.toSet(), entry.value.toSet(), reason: entry.key);
      expect(map['locales'], isA<List>(), reason: entry.key);
    }
    final android = records['android']!.asMap();
    expect(android['model'], 'Pixel 8');
    expect(android['version'], {
      'base_os': '',
      'sdk': 35,
      'release': '15',
      'code_name': 'REL',
      'incremental': '12345',
      'preview_sdk': 0,
      'security_patch': '2024-09-05',
    });
    expect(records['ios']!.asMap()['utsname'], {
      'machine': 'iPhone16,1',
      'node_name': 'iPhone',
      'release': '24.0.0',
      'sys_name': 'Darwin',
      'version': 'Darwin Kernel',
    });
    expect(records['web']!.asMap()['browser_name'], 'safari');
  });

  for (final design in HarnessDesign.values) {
    testWidgets('${design.name}: Page answers get_device_info with the record',
        (tester) async {
      debugDeviceInfoSource = () async => _linux();
      final backend = await _mountPage(tester, design);

      final outcome = await invokeOutcome(
          tester, backend.page, 'get_device_info',
          timeout: const Duration(seconds: 1));

      expect(outcome.error, isNull);
      final record = outcome.value as Map<String, dynamic>;
      expect(record['pretty_name'], 'Fedora Linux 40 (Workstation Edition)');
      expect(record['id_like'], ['rhel']);
      expect(record['machine_id'], 'abc123');
      expect(record['locales'], isA<List>());
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${design.name}: set_allowed_device_orientations sets the '
        'preferred orientations', (tester) async {
      final calls = _recordOrientationCalls(tester);
      final backend = await _mountPage(tester, design);

      Future<InvokeOutcome> set(Object? args) =>
          invokeOutcome(tester, backend.page, 'set_allowed_device_orientations',
              args: args, timeout: const Duration(seconds: 1));

      expect(
          (await set({
            'orientations': ['portraitUp', 'landscape_left', 'portraitUp']
          }))
              .error,
          isNull);
      expect((await set({'orientations': <String>[]})).error, isNull);
      expect((await set({})).error, isNull);
      final unknown = await set({
        'orientations': ['portraitUp', 'sideways']
      });

      expect(calls, [
        ['DeviceOrientation.portraitUp', 'DeviceOrientation.landscapeLeft'],
        <String>[],
        [
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.portraitDown',
          'DeviceOrientation.landscapeRight',
        ],
      ]);
      expect(unknown.error, isA<ArgumentError>());
      expect('${unknown.error}', contains('sideways'));
    });
  }

  for (final desktop in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux
  ]) {
    testWidgets(
        '${desktop.name}: set_allowed_device_orientations answers '
        'unsupported', (tester) async {
      final calls = _recordOrientationCalls(tester);
      final backend = await _mountPage(tester, HarnessDesign.android);
      debugDefaultTargetPlatformOverride = desktop;

      final outcome = await invokeOutcome(
          tester, backend.page, 'set_allowed_device_orientations',
          args: {
            'orientations': ['portraitUp']
          },
          timeout: const Duration(seconds: 1));
      debugDefaultTargetPlatformOverride = null;

      expect(outcome.error, isA<UnsupportedError>());
      expect((outcome.error as UnsupportedError).message,
          'set_allowed_device_orientations is only supported on mobile platforms');
      expect(calls, isEmpty);
    });
  }
}
