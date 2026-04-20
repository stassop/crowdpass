import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/firestore_provider.dart';

import 'package:crowdpass/models/company.dart';
import 'package:crowdpass/models/location.dart';

import 'package:crowdpass/services/image_file_service.dart';

/// 1. Data Stream Provider
/// Returns a Company.
/// - If [companyId] is provided, fetches that specific company.
/// - If [companyId] is null/empty, fetches the company owned by the current user.
final companyProvider = StreamProvider.family<Company?, String?>((ref, companyId) {
  final user = ref.watch(authProvider).value;
  final firestore = ref.watch(firestoreProvider);

  // If a specific Company ID is provided, fetch that company
  if (companyId != null && companyId.isNotEmpty) {
    return firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return Company.fromJson(snapshot.data()!);
    });
  }

  // If no Company ID provided, look for a company owned by the current user
  if (user != null) {
    return firestore
        .collection('companies')
        .where('ownerId', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return Company.fromJson(doc.data());
    });
  }

  return Stream.value(null);
});

/// 2. Company Action Notifier
class CompanyAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createCompany({
    required Location address,
    required String email,
    required String name,
    required Industry industry,
    required String phone,
    required String vatNumber,
    String? iban,
    String? logoPath,
    String? website,
  }) async {
    state = const AsyncLoading();
    try {
      final user = ref.read(authProvider).value;
      if (user == null) throw Exception('Authenticated user not found.');

      final firestore = ref.read(firestoreProvider);

      // Check if user already has a company
      final existingCompany = ref.read(companyProvider(null)).value;
      if (existingCompany != null) throw Exception('User already has a company.');

      final docRef = firestore.collection('companies').doc();

      String? logoURL;
      if (logoPath != null) {
        logoURL = await ImageFileService.uploadImage(
          logoPath,
          'companies/${docRef.id}/logo',
        );
      }

      final newCompany = Company(
        address: address,
        createdBy: user.uid,
        email: email,
        iban: iban,
        id: docRef.id,
        industry: industry,
        logoURL: logoURL,
        name: name,
        ownerId: user.uid,
        phone: phone,
        vatNumber: vatNumber,
        website: website,
      );

      await docRef.set(newCompany.toJson());
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCompany({
    required String companyId,
    Location? address,
    String? email,
    String? iban,
    Industry? industry,
    String? logoPath,
    String? name,
    String? ownerId,
    String? phone,
    String? vatNumber,
    String? website,
  }) async {
    state = const AsyncLoading();

    try {
      final user = ref.read(authProvider).value;
      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('companies').doc(companyId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Company not found.');

      final data = snapshot.data()!;
      final oldCompany = Company.fromJson(data);

      if (oldCompany.ownerId != user?.uid) {
        throw Exception('Access Denied: You do not own this company.');
      }

      String? logoURL;
      if (logoPath != null) {
        logoURL = await ImageFileService.uploadImage(
          logoPath,
          'companies/${companyId}/logo',
        );
      }

      await docRef.update(oldCompany.copyWith(
        address: address,
        email: email ?? oldCompany.email,
        name: name,
        industry: industry,
        ownerId: ownerId,
        phone: phone,
        vatNumber: vatNumber,
        iban: iban,
        logoURL: logoURL,
        website: website,
      ).toJson());
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCompany(String companyId) async {
    if (companyId.isEmpty) throw ArgumentError('Company ID is required.');

    state = const AsyncLoading();
    try {
      final user = ref.read(authProvider).value;
      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('companies').doc(companyId);

      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Company not found.');

      final data = snapshot.data()!;
      final company = Company.fromJson(data);

      if (company.ownerId != user?.uid) {
        throw Exception('Access Denied: You do not own this company.');
      }

      await docRef.delete();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final companyNotifier = AsyncNotifierProvider<CompanyAsyncNotifier, void>(() {
  return CompanyAsyncNotifier();
});
