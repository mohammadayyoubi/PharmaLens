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

    // tools/update_moph_dataset.py writes these; installed apps must accept
    // them whatever MOPH named the sheet.
    test('manifests written by the update script move installed apps forward', () {
      final october = MophDatasetManifest.tryParse(jsonEncode(<String, Object>{
        'version': '2026-10-19_WebMarketed20261005-19-10-2026',
        'list_date': '2026-10-05',
        'published': '2026-10-19',
        'rows': 5774,
        'sha256': 'dd68b194',
        'generated_at': '2026-10-27T02:44:58+00:00',
        'source_file': 'WebMarketed20261005-19-10-2026.xls',
      }))!;
      Map<String, Object> next({required String published, required String sheetName, required String csvHash, required String generatedAt}) =>
          <String, Object>{
            'version': '${published}_${sheetName}_$csvHash',
            'list_date': published,
            'published': published,
            'rows': 5739,
            'with_ingredients': 5709,
            'sha256': '${csvHash}0000',
            'generated_at': generatedAt,
            'source_file': '$sheetName.xls',
            'source_url': 'https://www.moph.gov.lb/x/$sheetName.xls',
            'source_sha256': 'abcd',
            'source_last_modified': '${published}T12:53:55+00:00',
            'source_size': 3080192,
          };

      final november = MophDatasetManifest.tryParse(jsonEncode(next(
          published: '2026-11-11', sheetName: 'WebMarketed20261111', csvHash: '4f7fbc23', generatedAt: '2026-11-12T23:58:19+00:00')))!;
      expect(november.isNewerThan(october), isTrue);
      expect(november.isNewerThan(november), isFalse);

      // MOPH re-uploads a corrected sheet under the same name the same day:
      // same published date, new content hash in the version, later build.
      final corrected = MophDatasetManifest.tryParse(jsonEncode(next(
          published: '2026-11-11', sheetName: 'WebMarketed20261111', csvHash: '9a1b2c3d', generatedAt: '2026-11-11T18:00:00+00:00')))!;
      expect(corrected.isNewerThan(MophDatasetManifest.tryParse(jsonEncode(next(
          published: '2026-11-11', sheetName: 'WebMarketed20261111', csvHash: '4f7fbc23', generatedAt: '2026-11-11T13:00:00+00:00')))!), isTrue);
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

    test('reports each stage with a growing percentage, then goes idle', () async {
      final service = MophMedicineService();
      final seen = <MophSyncProgress>[];
      void record() => seen.add(service.progress.value);
      service.progress.addListener(record);

      final pending = http.runWithClient(
        () => service.checkAndUpdateIfStale(force: true),
        () => server(manifest(version: 'later', published: '2099-02-01', rows: 6), csvWith(6, date: '2099-02-01')),
      );
      // The Sync buttons are disabled from the moment a sync starts.
      expect(service.isSyncing, isTrue);
      final result = await pending;
      service.progress.removeListener(record);

      expect(result.status, MophSyncStatus.updated);
      final stages = seen.map((p) => p.stage).toList();
      expect(stages, containsAllInOrder(<MophSyncStage>[
        MophSyncStage.checking,
        MophSyncStage.downloading,
        MophSyncStage.verifying,
        MophSyncStage.applying,
        MophSyncStage.idle,
      ]));
      final busy = seen.where((p) => p.busy).map((p) => p.percent).toList();
      expect(busy, orderedEquals(List<int>.of(busy)..sort()), reason: 'progress never goes backwards');
      expect(busy.last, greaterThanOrEqualTo(90));
      expect(service.isSyncing, isFalse);
      expect(service.progress.value.busy, isFalse);
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
