import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/utils/sum_count_streams.dart';

void main() {
  test('no campuses emits zero', () async {
    expect(await sumCountStreams([]).single, 0);
  });
  test('aggregates and updates without partial totals', () async {
    final a = StreamController<int>();
    final b = StreamController<int>();
    final values = <int>[];
    final subscription = sumCountStreams([
      a.stream,
      b.stream,
    ]).listen(values.add);
    a.add(2);
    await Future<void>.delayed(Duration.zero);
    expect(values, isEmpty);
    b.add(3);
    await Future<void>.delayed(Duration.zero);
    a.add(4);
    await Future<void>.delayed(Duration.zero);
    expect(values, [5, 7]);
    await subscription.cancel();
    expect(a.hasListener, isFalse);
    expect(b.hasListener, isFalse);
    await a.close();
    await b.close();
  });
  test('errors propagate instead of presenting an incorrect zero', () async {
    await expectLater(
      sumCountStreams([Stream<int>.error(StateError('denied'))]),
      emitsError(isA<StateError>()),
    );
  });
}
