import 'package:qora/src/client/qora_client.dart';
import 'package:qora/src/config/qora_client_config.dart';
import 'package:qora/src/config/qora_options.dart';
import 'package:qora/src/key/qora_key.dart';
import 'package:qora/src/utils/qora_exception.dart';
import 'package:test/test.dart';

void main() {
  group('transform pipeline', () {
    late QoraClient client;

    setUp(() {
      client = QoraClient();
    });

    tearDown(() {
      client.clear();
    });

    group('transform', () {
      test('transform modifies data before caching', () async {
        final data = await client.fetchQuery<Map<String, dynamic>>(
          key: QoraKey(['user', 1]),
          fetcher: () async => <String, dynamic>{'name': 'Alice', 'age': 30},
          options: QoraOptions(
            transform: (raw) {
              final map = raw as Map<String, dynamic>;
              return <String, dynamic>{
                'fullName': map['name'],
                'yearsOld': map['age'],
              };
            },
          ),
        );

        expect(data, {'fullName': 'Alice', 'yearsOld': 30});
      });

      test('transform runs before structural sharing', () async {
        final key = QoraKey(['test']);

        // First fetch
        await client.fetchQuery<Map<String, dynamic>>(
          key: key,
          fetcher: () async => <String, dynamic>{'value': 1},
          options: QoraOptions(
            staleTime: const Duration(seconds: 10),
            transform: (raw) {
              final map = raw as Map<String, dynamic>;
              return <String, dynamic>{'transformed': map['value']};
            },
          ),
        );

        final firstData = client.getQueryData<Map<String, dynamic>>(key);
        expect(firstData, {'transformed': 1});

        // Invalidate so second fetch actually re-fetches
        client.invalidate(key);

        // Second fetch with same raw data → same transformed result
        await client.fetchQuery<Map<String, dynamic>>(
          key: key,
          fetcher: () async => <String, dynamic>{'value': 1},
          options: QoraOptions(
            staleTime: const Duration(seconds: 10),
            transform: (raw) {
              final map = raw as Map<String, dynamic>;
              return <String, dynamic>{'transformed': map['value']};
            },
          ),
        );

        // Structural sharing should preserve the old reference since
        // transformed data is deeply equal.
        final secondData = client.getQueryData<Map<String, dynamic>>(key);
        expect(identical(firstData, secondData), isTrue);
      });

      test('transform with changed data produces new reference', () async {
        final key = QoraKey(['test']);

        // First fetch
        await client.fetchQuery<Map<String, dynamic>>(
          key: key,
          fetcher: () async => <String, dynamic>{'value': 1},
          options: QoraOptions(
            staleTime: const Duration(seconds: 10),
            transform: (raw) {
              final map = raw as Map<String, dynamic>;
              return <String, dynamic>{'transformed': map['value']};
            },
          ),
        );

        final firstData = client.getQueryData<Map<String, dynamic>>(key);
        expect(firstData, {'transformed': 1});

        // Invalidate so second fetch actually re-fetches
        client.invalidate(key);

        // Second fetch with different raw data → different transformed result
        await client.fetchQuery<Map<String, dynamic>>(
          key: key,
          fetcher: () async => <String, dynamic>{'value': 2},
          options: QoraOptions(
            staleTime: const Duration(seconds: 10),
            transform: (raw) {
              final map = raw as Map<String, dynamic>;
              return <String, dynamic>{'transformed': map['value']};
            },
          ),
        );

        final secondData = client.getQueryData<Map<String, dynamic>>(key);
        expect(secondData, {'transformed': 2});
        expect(identical(firstData, secondData), isFalse);
      });

      test('transform corrects data to new shape', () async {
        final data = await client.fetchQuery<int>(
          key: QoraKey(['count']),
          fetcher: () async => 42,
          options: QoraOptions(
            transform: (raw) => (raw as int) * 2,
          ),
        );

        expect(data, 84);
        expect(data, isA<int>());
      });

      test('null transform is a no-op', () async {
        final data = await client.fetchQuery<String>(
          key: QoraKey(['test']),
          fetcher: () async => 'hello',
        );

        expect(data, 'hello');
      });
    });

    group('transformError', () {
      test('transformError transforms fetch errors', () async {
        try {
          await client.fetchQuery<String>(
            key: QoraKey(['test']),
            fetcher: () async => throw Exception('raw error'),
            options: QoraOptions(
              transformError: (error) =>
                  StateError('wrapped: ${error.toString()}'),
            ),
          );
          fail('Expected exception');
        } catch (e) {
          expect(e, isA<StateError>());
          expect(e.toString(), contains('wrapped'));
          expect(e.toString(), contains('raw error'));
        }
      });

      test('transformError error is stored in Failure state', () async {
        try {
          await client.fetchQuery<String>(
            key: QoraKey(['test']),
            fetcher: () async => throw Exception('db error'),
            options: QoraOptions(
              transformError: (error) =>
                  ArgumentError('normalised: ${error.toString()}'),
            ),
          );
        } catch (_) {}

        final state = client.getQueryState<String>(QoraKey(['test']));
        expect(state.errorOrNull, isA<ArgumentError>());
      });

      test('null transformError passes raw error through', () async {
        try {
          await client.fetchQuery<String>(
            key: QoraKey(['test']),
            fetcher: () async => throw Exception('raw'),
          );
          fail('Expected exception');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), contains('raw'));
        }
      });

      test('transformError runs before errorMapper', () async {
        final clientWithMapper = QoraClient(
          config: QoraClientConfig(
            errorMapper: (error, _) => QoraException('mapper: $error'),
          ),
        );

        try {
          await clientWithMapper.fetchQuery<String>(
            key: QoraKey(['test']),
            fetcher: () async => throw Exception('original'),
            options: QoraOptions(
              transformError: (error) => ArgumentError('transform: $error'),
            ),
          );
          fail('Expected exception');
        } catch (e) {
          // Should go through transform → then mapper
          expect(e, isA<QoraException>());
          expect(e.toString(), contains('mapper'));
          expect(e.toString(), contains('transform'));
        } finally {
          clientWithMapper.clear();
        }
      });
    });

    group('QoraOptions.merge', () {
      test('merge propagates transform', () {
        final base = QoraOptions(transform: (d) => d as Object);
        final merged = base.merge(null);
        expect(merged.transform, isNotNull);
      });

      test('merge propagates transformError', () {
        final base = QoraOptions(transformError: (e) => e);
        final merged = base.merge(null);
        expect(merged.transformError, isNotNull);
      });

      test('merge overrides transform', () {
        Object t1(Object? d) => d as Object;
        Object t2(Object? d) => 'overridden' as Object;
        final base = QoraOptions(transform: t1);
        final merged = base.merge(QoraOptions(transform: t2));
        expect(merged.transform, same(t2));
      });
    });
  });
}
