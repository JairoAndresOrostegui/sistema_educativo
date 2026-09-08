import 'dart:async';

/// Emits a total only after every campus has supplied its first count.
Stream<int> sumCountStreams(List<Stream<int>> streams) {
  if (streams.isEmpty) return Stream.value(0);
  final values = List<int?>.filled(streams.length, null);
  final subscriptions = <StreamSubscription<int>>[];
  var completed = 0;
  late StreamController<int> controller;
  controller = StreamController<int>(
    onListen: () {
      for (var index = 0; index < streams.length; index++) {
        final slot = index;
        subscriptions.add(
          streams[index].listen(
            (value) {
              values[slot] = value;
              if (values.every((value) => value != null)) {
                controller.add(values.fold(0, (sum, value) => sum + value!));
              }
            },
            onError: controller.addError,
            onDone: () {
              completed++;
              if (completed == streams.length) controller.close();
            },
          ),
        );
      }
    },
    onCancel: () async {
      await Future.wait(
        subscriptions.map((subscription) => subscription.cancel()),
      );
    },
  );
  return controller.stream;
}
