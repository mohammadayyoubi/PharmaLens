import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pharmalens/services/moph_medicine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const header =
    'medicine_id,registration_number,brand_name,generic_name,active_ingredients,atc_code,brand_generic,strength,form,pack,company,agent,country,official_price_lbp,currency,last_updated,source,source_url,notes';

String csvWith(int count, {required String date, int price = 100000}) {
  final rows = [
    for (var i = 1; i <= count; i++)
      '$i,R$i,BRAND$i,Paracetamol,Paracetamol,N02BE01,B,500mg,Tablet,20,Co,,LB,${price + i},LBP,$date,MOPH,,',
  ];
  return '$header\n${rows.join('\n')}\n';
}

String manifest({required String version, required String published, required int rows, String generatedAt = '2027-01-01T00:00:00+00:00'}) {
  return jsonEncode(<String, Object>{
    'version': version,
    'list_date': published,
    'published': published,
    'rows': rows,
    'generated_at': generatedAt,
  });
}

/// Serves [manifestBody] and [csvBody] the way the GitHub-hosted files are.
MockClient server(String manifestBody, String csvBody, {List<String>? requests}) {
  return MockClient((request) async {
    requests?.add(request.url.pathSegments.last);
    if (request.url.path.endsWith('.json')) return http.Response(manifestBody, 200);
    if (request.url.path.endsWith('.csv')) return http.Response.bytes(utf8.encode(csvBody), 200);
    return http.Response('not found', 404);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MophDatasetManifest', () {
    MophDatasetManifest m(String published, {String version = 'v', String generatedAt = '1'}) =>
        MophDatasetManifest(version: version, published: published, listDate: published, generatedAt: generatedAt);

    test('a later publication is newer, including a corrected re-issue of the same list', () {
      expect(m('2026-11-02').isNewerThan(m('2026-10-19')), isTrue);
      expect(m('2026-10-19').isNewerThan(m('2026-11-02')), isFalse);
      expect(m('2026-10-19', version: 'a').isNewerThan(m('2026-10-19', version: 'a')), isFalse);
      // Same sheet rebuilt later (e.g. better ingredient matching).
      expect(m('2026-10-19', version: 'b', generatedAt: '2').isNewerThan(m('2026-10-19', version: 'a', generatedAt: '1')), isTrue);
    });

    test('the bundled manifest describes the bundled list', () async {
      final bundled = MophDatasetManifest.tryParse(await rootBundle.loadString('assets/medicines/lebanon_medicine_prices.json'))!;
      final dataset = parseMophDataset(await rootBundle.loadString('assets/medicines/lebanon_medicine_prices.csv'));

      expect(bundled.matches(dataset), isTrue, reason: 'row count in the manifest must equal the parsed list');
      expect(bundled.published.compareTo(bundled.listDate), greaterThanOrEqualTo(0));
    });
  });

  group('MophMedicineService updates', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await MophMedicineService().initialize();
    });

    test('downloads only the manifest when nothing changed', () async {
      final service = MophMedicineService();
      final requests = <String>[];
      final bundled = MophDatasetManifest.tryParse(await rootBundle.loadString('assets/medicines/lebanon_medicine_prices.json'))!;

      final result = await http.runWithClient(
        () => service.checkAndUpdateIfStale(force: true),
        () => server(bundled.toJsonString(), 'unused', requests: requests),
      );

      expect(result.status, MophSyncStatus.upToDate);
      expect(requests, <String>['lebanon_medicine_prices.json']);
    });

    test('rejects an incomplete download and keeps the current list', () async {
      final service = MophMedicineService();
      final before = service.totalMedicineCount;

      final result = await http.runWithClient(
        () => service.checkAndUpdateIfStale(force: true),
        // The manifest promises 5 medicines but only 3 arrive.
        () => server(manifest(version: 'next', published: '2099-01-01', rows: 5), csvWith(3, date: '2099-01-01')),
      );

      expect(result.status, MophSyncStatus.failed);
      expect(service.totalMedicineCount, before);
    });

    test('installs a newer published list and tells listeners', () async {
      final service = MophMedicineService();
      final revision = service.datasetRevision.value;

      final result = await http.runWithClient(
        () => service.checkAndUpdateIfStale(force: true),
        () => server(manifest(version: 'next', published: '2099-01-01', rows: 4), csvWith(4, date: '2099-01-01')),
      );

      expect(result.status, MophSyncStatus.updated);
      expect(service.totalMedicineCount, 4);
      expect(service.publishedDate, '2099-01-01');
      expect(service.datasetRevision.value, revision + 1);
      expect((await service.searchMedicines('BRAND2')).first.priceLbp, 100002);
    });

    test('without a forced check, the server is asked at most once an hour', () async {
      final requests = <String>[];

      final result = await http.runWithClient(
        () => MophMedicineService().checkAndUpdateIfStale(),
        () => server('{}', '', requests: requests),
      );

      expect(result.status, MophSyncStatus.upToDate);
      expect(requests, isEmpty);
    });
  });
}
