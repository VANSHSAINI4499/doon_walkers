import 'package:doon_walkers/features/registrations/data/models/registration_model.dart';
import 'package:doon_walkers/features/registrations/domain/entities/registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaymentStatus', () {
    test('fromString round-trips every enum value through toDbString', () {
      for (final status in PaymentStatus.values) {
        expect(PaymentStatus.fromString(status.toDbString()), status);
      }
    });

    test('unknown or null values fall back to pending (matches DB default)', () {
      expect(PaymentStatus.fromString('settled'), PaymentStatus.pending);
      expect(PaymentStatus.fromString(null), PaymentStatus.pending);
    });
  });

  group('GenderType', () {
    // Cannot use `.name` to round-trip like the other enums: Dart's
    // `preferNotToSay` != Postgres' `prefer_not_to_say`, so the explicit
    // mapping is the thing under test.
    test('round-trips every enum value through toDbString', () {
      for (final gender in GenderType.values) {
        expect(GenderType.fromString(gender.toDbString()), gender);
      }
    });

    test('maps the snake_case Postgres label, not the Dart identifier', () {
      expect(GenderType.fromString('prefer_not_to_say'), GenderType.preferNotToSay);
      expect(GenderType.preferNotToSay.toDbString(), 'prefer_not_to_say');
      // The Dart identifier must NOT be accepted as a DB value.
      expect(GenderType.fromString('preferNotToSay'), isNull);
    });

    test('unknown or null values return null (column is nullable)', () {
      expect(GenderType.fromString('unspecified'), isNull);
      expect(GenderType.fromString(null), isNull);
    });
  });

  group('RegistrationModel.toInsertJson', () {
    final payload = RegistrationModel.toInsertJson(
      trekId: 'trek-1',
      userId: 'user-1',
      age: 29,
      gender: GenderType.preferNotToSay,
      emergencyContact: 'Priya Sharma +91 90000 11111',
      medicalNotes: 'Mild asthma',
    );

    test('never sends payment_status — that column is admin-only', () {
      // prevent_payment_status_self_edit rejects a non-admin changing
      // this; the client must rely on the DB default instead of setting
      // it, so its presence in the payload would be a real bug.
      expect(payload.containsKey('payment_status'), isFalse);
    });

    test('sends the snake_case gender value Postgres expects', () {
      expect(payload['gender'], 'prefer_not_to_say');
    });

    test('carries trek, user and registrant detail', () {
      expect(payload['trek_id'], 'trek-1');
      expect(payload['user_id'], 'user-1');
      expect(payload['age'], 29);
      expect(payload['emergency_contact'], 'Priya Sharma +91 90000 11111');
      expect(payload['medical_notes'], 'Mild asthma');
    });

    test('omitted medical notes serialise as null, not an empty string', () {
      final noNotes = RegistrationModel.toInsertJson(
        trekId: 'trek-1',
        userId: 'user-1',
        age: 29,
        gender: GenderType.male,
        emergencyContact: 'Someone +91 90000 11111',
      );
      expect(noNotes['medical_notes'], isNull);
    });
  });

  group('RegistrationModel.fromJson', () {
    // Mirrors the PostgREST embedded-resource shape produced by
    // .select('*, users(name, email, phone), treks(title)') — the joined
    // rows arrive as nested maps, not flattened columns.
    final fullJson = {
      'id': 'reg-1',
      'trek_id': 'trek-1',
      'user_id': 'user-1',
      'payment_status': 'paid',
      'created_at': '2026-07-20T09:30:00.000Z',
      'age': 34,
      'gender': 'female',
      'emergency_contact': 'Priya Sharma +91 90000 11111',
      'medical_notes': 'Mild asthma — carries an inhaler',
      'users': {
        'name': 'Aarav Sharma',
        'email': 'aarav@example.com',
        'phone': '+91 98765 43210',
      },
      'treks': {'title': 'Nag Tibba Weekend Trek', 'trek_date': '2026-08-15'},
    };

    test('parses every field, flattening the joined user and trek', () {
      final registration = RegistrationModel.fromJson(fullJson);

      expect(registration.id, 'reg-1');
      expect(registration.trekId, 'trek-1');
      expect(registration.userId, 'user-1');
      expect(registration.paymentStatus, PaymentStatus.paid);
      expect(registration.createdAt, DateTime.parse('2026-07-20T09:30:00.000Z'));
      expect(registration.userName, 'Aarav Sharma');
      expect(registration.userEmail, 'aarav@example.com');
      expect(registration.userPhone, '+91 98765 43210');
      expect(registration.trekTitle, 'Nag Tibba Weekend Trek');
      expect(registration.trekDate, DateTime.parse('2026-08-15'));
    });

    test('a trek with no trek_date parses to a null trekDate', () {
      final json = {
        ...fullJson,
        'treks': {'title': 'Nag Tibba Weekend Trek'},
      };

      expect(RegistrationModel.fromJson(json).trekDate, isNull);
    });

    test('parses the sensitive registrant fields', () {
      final registration = RegistrationModel.fromJson(fullJson);

      expect(registration.age, 34);
      expect(registration.gender, GenderType.female);
      expect(registration.emergencyContact, 'Priya Sharma +91 90000 11111');
      expect(registration.medicalNotes, 'Mild asthma — carries an inhaler');
    });

    test('absent sensitive fields stay null rather than empty strings', () {
      // All four are nullable in the schema; the detail view renders a
      // distinct "Not provided" for null, so blank-vs-null matters.
      final json = Map<String, dynamic>.from(fullJson)
        ..remove('age')
        ..remove('gender')
        ..['emergency_contact'] = '   '
        ..['medical_notes'] = '';

      final registration = RegistrationModel.fromJson(json);

      expect(registration.age, isNull);
      expect(registration.gender, isNull);
      expect(registration.emergencyContact, isNull);
      expect(registration.medicalNotes, isNull);
    });

    test('a null phone stays null (column is nullable in the schema)', () {
      final json = {
        ...fullJson,
        'users': {'name': 'Aarav Sharma', 'email': 'aarav@example.com', 'phone': null},
      };

      expect(RegistrationModel.fromJson(json).userPhone, isNull);
    });

    test('a blank phone is normalised to null, not rendered as empty text', () {
      final json = {
        ...fullJson,
        'users': {'name': 'Aarav Sharma', 'email': 'aarav@example.com', 'phone': '   '},
      };

      expect(RegistrationModel.fromJson(json).userPhone, isNull);
    });

    test('missing joined rows degrade to placeholders instead of throwing', () {
      final json = {
        'id': 'reg-2',
        'trek_id': 'trek-2',
        'user_id': 'user-2',
        'payment_status': 'pending',
        'created_at': '2026-07-20T09:30:00.000Z',
      };

      final registration = RegistrationModel.fromJson(json);

      expect(registration.userName, 'Unknown member');
      expect(registration.userEmail, '—');
      expect(registration.userPhone, isNull);
      expect(registration.trekTitle, 'Unknown trek');
    });

    test('missing payment_status defaults to pending, not a crash', () {
      final json = Map<String, dynamic>.from(fullJson)..remove('payment_status');

      expect(RegistrationModel.fromJson(json).paymentStatus, PaymentStatus.pending);
    });
  });
}
