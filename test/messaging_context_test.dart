import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/models/messaging/message_models.dart';
import 'package:sistema_educativo/utils/notification_destination.dart';

void main() {
  test('notificación solo admite un canal interno válido', () {
    expect(
      notificationDestination({'type': 'messaging', 'channelId': 'abc'}),
      '/messages?channelId=abc',
    );
    expect(
      notificationDestination({'type': 'files', 'channelId': 'abc'}),
      isNull,
    );
    expect(
      notificationDestination({'type': 'messaging', 'channelId': 'a/b'}),
      isNull,
    );
    expect(
      notificationDestination({'type': 'messaging', 'channelId': ''}),
      isNull,
    );
  });
  test('familia filtra grupos, privados y servicios por hijo', () {
    const child = MessagingChildContext(
      id: 'h1',
      fullName: 'Hijo',
      groupId: 'g1',
      groupName: 'Cuarto A',
    );
    bool visible(Map<String, dynamic> data) =>
        MessageThreadSummary.fromMap(data, 'chat').belongsToChild(child);
    expect(visible({'channelType': 'academic_group', 'groupId': 'g1'}), isTrue);
    expect(
      visible({'channelType': 'academic_group', 'groupId': 'g2'}),
      isFalse,
    );
    expect(
      visible({
        'channelType': 'private',
        'familyGroupId': 'g1',
        'contextStudentId': 'hijo-de-otro-familiar',
      }),
      isTrue,
    );
    expect(
      visible({'channelType': 'private', 'contextStudentId': 'h1'}),
      isTrue,
    );
    expect(
      visible({'channelType': 'private', 'contextStudentId': 'h2'}),
      isFalse,
    );
    expect(
      visible({
        'channelType': 'service',
        'targetGroupIds': ['g1', 'g2'],
      }),
      isTrue,
    );
    expect(
      visible({
        'channelType': 'service',
        'targetGroupIds': ['g2'],
      }),
      isFalse,
    );
  });
}
