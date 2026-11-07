import 'dart:convert';

import 'package:qora/qora.dart';
import 'package:test/test.dart';

const _stringSerializer = QoraSerializer<String>(
  toJson: _identity,
  fromJson: _fromJson,
);

dynamic _identity(String value) => value;
String _fromJson(dynamic json) => json as String;

void main() {
  late InMemoryStorageAdapter storage;

  setUp(() => storage = InMemoryStorageAdapter());

  PersistQoraClient newClient() => PersistQoraClient(storage: storage)
    ..registerSerializer<String>(_stringSerializer, name: 'String');

  test('leaves keys it did not write untouched', () async {
    await storage.write('settings.theme', 'dark');
    await storage.write('session', '{"token":"abc"}');
    await storage.write('[not json', 'x');

    await newClient().hydrate();

    expect(
      await storage.keys(),
      containsAll(['settings.theme', 'session', '[not json']),
    );
    expect(await storage.read('session'), '{"token":"abc"}');
  });

  test('restores a persisted query next to foreign keys', () async {
    await storage.write('settings.theme', 'dark');

    final writer = newClient();
    await writer
        .fetchQuery<String>(key: ['greeting'], fetcher: () async => 'hi');
    await writer.persistQuery<String>(['greeting']);
    expect(await storage.keys(), contains(jsonEncode(['greeting'])));

    final reader = newClient();
    await reader.hydrate();
    final value = await reader.fetchQuery<String>(
      key: ['greeting'],
      fetcher: () async => 'network',
      options: const QoraOptions(staleTime: Duration(minutes: 5)),
    );

    expect(value, 'hi');
    expect(await storage.read('settings.theme'), 'dark');
  });

  test('still deletes corrupt and unknown Qora entries', () async {
    await storage.write(jsonEncode(['corrupt']), 'not json');
    await storage.write(
      jsonEncode(['unknown']),
      jsonEncode({
        'typeName': 'NoSuchType',
        'data': 1,
        'persistedAtMs': DateTime.now().millisecondsSinceEpoch,
      }),
    );

    await newClient().hydrate();

    expect(await storage.keys(), isEmpty);
  });

  test('clearStorage deletes Qora entries and keeps foreign keys', () async {
    await storage.write('settings.theme', 'dark');
    final client = newClient();
    await client
        .fetchQuery<String>(key: ['greeting'], fetcher: () async => 'hi');
    await client.persistQuery<String>(['greeting']);

    await client.clearStorage();

    expect(await storage.keys(), ['settings.theme']);
  });

  test('clear wipes the cache and Qora entries only', () async {
    await storage.write('settings.theme', 'dark');
    final client = newClient();
    await client
        .fetchQuery<String>(key: ['greeting'], fetcher: () async => 'hi');
    await client.persistQuery<String>(['greeting']);

    client.clear();
    await Future<void>.delayed(Duration.zero);

    expect(client.getQueryData<String>(['greeting']), isNull);
    expect(await storage.keys(), ['settings.theme']);
  });
}
