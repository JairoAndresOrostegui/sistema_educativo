import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? historyDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int && value >= 0) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return null;
}

class FilteredDocumentPage {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> documents;
  final bool hasNext;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  const FilteredDocumentPage({
    required this.documents,
    required this.hasNext,
    required this.lastDoc,
  });
}

Future<FilteredDocumentPage> scanFilteredPage({
  required Query<Map<String, dynamic>> query,
  required int pageSize,
  required bool Function(Map<String, dynamic>) matches,
  DocumentSnapshot<Map<String, dynamic>>? startAfter,
}) async {
  if (pageSize < 1) throw ArgumentError.value(pageSize, 'pageSize');
  final selected = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
  DocumentSnapshot<Map<String, dynamic>>? lastIncluded;
  final batchSize = math.max(50, pageSize * 2);

  while (true) {
    var batchQuery = query.limit(batchSize);
    if (cursor != null) batchQuery = batchQuery.startAfterDocument(cursor);
    final snapshot = await batchQuery.get();
    if (snapshot.docs.isEmpty) break;

    for (final document in snapshot.docs) {
      if (!matches(document.data())) continue;
      if (selected.length == pageSize) {
        return FilteredDocumentPage(
          documents: selected,
          hasNext: true,
          lastDoc: lastIncluded,
        );
      }
      selected.add(document);
      lastIncluded = document;
    }

    if (snapshot.docs.length < batchSize) break;
    cursor = snapshot.docs.last;
  }

  return FilteredDocumentPage(
    documents: selected,
    hasNext: false,
    lastDoc: lastIncluded,
  );
}

Future<int> countFilteredDocuments({
  required Query<Map<String, dynamic>> query,
  required bool Function(Map<String, dynamic>) matches,
}) async {
  var total = 0;
  DocumentSnapshot<Map<String, dynamic>>? cursor;
  const batchSize = 250;
  while (true) {
    var batchQuery = query.limit(batchSize);
    if (cursor != null) batchQuery = batchQuery.startAfterDocument(cursor);
    final snapshot = await batchQuery.get();
    if (snapshot.docs.isEmpty) break;
    total += snapshot.docs.where((item) => matches(item.data())).length;
    if (snapshot.docs.length < batchSize) break;
    cursor = snapshot.docs.last;
  }
  return total;
}
