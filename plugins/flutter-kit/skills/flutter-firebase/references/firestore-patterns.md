# Firestore desenleri

## Timestamp dönüştürücü — core/firebase/timestamp_converter.dart

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class TimestampConverter implements JsonConverter<DateTime, Object> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object json) => switch (json) {
        Timestamp t => t.toDate(),
        String s => DateTime.parse(s),
        int ms => DateTime.fromMillisecondsSinceEpoch(ms),
        _ => throw ArgumentError('Geçersiz tarih: $json'),
      };

  @override
  Object toJson(DateTime date) => Timestamp.fromDate(date);
}

class NullableTimestampConverter implements JsonConverter<DateTime?, Object?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Object? json) =>
      json == null ? null : const TimestampConverter().fromJson(json);

  @override
  Object? toJson(DateTime? date) =>
      date == null ? null : const TimestampConverter().toJson(date);
}
```

> `serverTimestamp()` ile yazılan alan, yerel yazmanın hemen ardından gelen snapshot'ta geçici olarak `null` olabilir; bu yüzden böyle alanlarda `NullableTimestampConverter` kullan.

## Model

```dart
@freezed
abstract class Assessment with _$Assessment {
  const factory Assessment({
    @Default('') String id,
    required String title,
    required String ownerId,
    @Default(0) int score,
    @NullableTimestampConverter() DateTime? createdAt,
  }) = _Assessment;

  factory Assessment.fromJson(Map<String, dynamic> json) =>
      _$AssessmentFromJson(json);
}
```

## Service — features/assessments/data/services/assessments_service.dart

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:my_app/core/firebase/firebase_providers.dart';
import 'package:my_app/features/assessments/data/models/assessment.dart';

part 'assessments_service.g.dart';

class AssessmentsService {
  AssessmentsService(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Assessment> get _col =>
      _db.collection('assessments').withConverter<Assessment>(
            fromFirestore: (snap, _) =>
                Assessment.fromJson({...snap.data()!, 'id': snap.id}),
            toFirestore: (a, _) => a.toJson()..remove('id'),
          );

  Stream<List<Assessment>> watchByOwner(String ownerId) => _col
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((q) => q.docs.map((d) => d.data()).toList());

  Future<Assessment?> getById(String id) async =>
      (await _col.doc(id).get()).data();

  Future<String> create(Assessment a) async {
    // createdAt'i sunucu zamanıyla yazmak için converter'sız ham koleksiyon.
    final doc = await _db.collection('assessments').add({
      ...a.toJson()..remove('id'),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> update(Assessment a) =>
      _col.doc(a.id).set(a, SetOptions(merge: true));

  Future<void> delete(String id) => _col.doc(id).delete();
}

@riverpod
AssessmentsService assessmentsService(Ref ref) =>
    AssessmentsService(ref.watch(firestoreProvider));
```

## Repository + hata çevirme

```dart
// core/firebase/firebase_exception_mapper.dart
AppException mapFirebaseException(FirebaseException e) => switch (e.code) {
      'permission-denied' || 'unauthenticated' => const UnauthorizedException(
          'Bu işlem için yetkiniz yok.'),
      'not-found' => const NotFoundException(),
      'unavailable' || 'deadline-exceeded' => NetworkException(
          'Sunucuya ulaşılamıyor, bağlantınızı kontrol edin.', e),
      'invalid-argument' || 'failed-precondition' =>
        ValidationException(e.message ?? 'İşlem gerçekleştirilemedi.'),
      _ => UnknownException('Beklenmeyen bir hata oluştu.', e),
    };
```

```dart
class AssessmentsRepository {
  AssessmentsRepository(this._service);
  final AssessmentsService _service;

  Stream<List<Assessment>> watchMine(String uid) => _service
      .watchByOwner(uid)
      .handleError((Object e) =>
          throw e is FirebaseException ? mapFirebaseException(e) : e);

  Future<String> create(Assessment a) => _guard(() => _service.create(a));
  Future<void> delete(String id) => _guard(() => _service.delete(id));

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseException catch (e) {
      throw mapFirebaseException(e);
    }
  }
}

@riverpod
AssessmentsRepository assessmentsRepository(Ref ref) =>
    AssessmentsRepository(ref.watch(assessmentsServiceProvider));
```

## ViewModel (stream)

```dart
@riverpod
Stream<List<Assessment>> myAssessments(Ref ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(assessmentsRepositoryProvider).watchMine(uid);
}
```

Aksiyonlar (oluştur/sil) ayrı bir Notifier'da:

```dart
@riverpod
class AssessmentActions extends _$AssessmentActions {
  @override
  FutureOr<void> build() {}

  Future<bool> delete(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(assessmentsRepositoryProvider).delete(id),
    );
    return !state.hasError;
  }
}
```

Stream otomatik güncellendiği için silme sonrası listeyi yeniden çekmeye gerek yok.

## Batch ve transaction

```dart
// Atomik çoklu yazma
final batch = _db.batch();
for (final id in ids) {
  batch.update(_db.collection('assessments').doc(id), {'archived': true});
}
await batch.commit();

// Oku-hesapla-yaz
await _db.runTransaction((tx) async {
  final ref = _db.collection('counters').doc('assessments');
  final snap = await tx.get(ref);
  final current = (snap.data()?['count'] as int?) ?? 0;
  tx.set(ref, {'count': current + 1});
});
// Sadece sayaç artırma için transaction yerine FieldValue.increment(1) yeterli.
```

## Sayfalama

`startAfterDocument(lastDoc)` + `limit(n)`. Service son `DocumentSnapshot`'ı döndürmeli; ViewModel bunu state'te tutar (bkz. `flutter-api-data/references/patterns.md` sayfalama ViewModel'i — aynı yapı, `page` yerine `lastDoc`).

## Güvenlik kuralı şablonu (firestore.rules)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /assessments/{id} {
      allow read: if request.auth != null && resource.data.ownerId == request.auth.uid;
      allow create: if request.auth != null
                    && request.resource.data.ownerId == request.auth.uid
                    && request.resource.data.title is string
                    && request.resource.data.title.size() <= 200;
      allow update, delete: if request.auth != null && resource.data.ownerId == request.auth.uid;
    }
  }
}
```

Sorgu kurallarla uyumlu olmalı: kural `ownerId == uid` istiyorsa sorgu da `where('ownerId', isEqualTo: uid)` içermeli, yoksa `permission-denied` döner.
