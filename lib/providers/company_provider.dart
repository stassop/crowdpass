import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/image_provider.dart';
import 'package:crowdpass/models/company.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// 1. Data Stream Provider
final companyProvider = StreamProvider.family<Company?, String>((ref, companyId) {
  if (companyId.isEmpty) return Stream.value(null);

  return ref.watch(firestoreProvider)
      .collection('companies')
      .doc(companyId)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return Company.fromJson(snapshot.data()!).copyWith(id: snapshot.id);
      });
});

/// 2. Company Action Notifier
class CompanyAsyncNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createCompany(Company company, {String? logoURL}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      if (user == null) throw Exception('Authenticated user not found.');

      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('companies').doc(); 
      
      String? uploadedLogoURL;
      if (logoURL != null) {
        uploadedLogoURL = await ref
            .read(imageNotifier.notifier)
            .uploadImage(logoURL, 'companies/${docRef.id}/logo');
      }

      final newCompany = company.copyWith(
        id: docRef.id,
        ownerId: user.uid,
        logoURL: uploadedLogoURL,
      );

      await docRef.set(newCompany.toJson());
    });
  }

  Future<void> updateCompany(Company company, {String? logoURL}) async {
    if (company.id == null) throw ArgumentError('Company ID is required.');

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authProvider.future);
      final firestore = ref.read(firestoreProvider);
      final docRef = firestore.collection('companies').doc(company.id);

      final snapshot = await docRef.get();
      if (!snapshot.exists) throw Exception('Company not found.');

      final data = snapshot.data()!;
      final oldCompany = Company.fromJson(data);
      
      if (oldCompany.ownerId != user?.uid) {
        throw Exception('Access Denied: You do not own this company.');
      }
      
      String? finalLogoURL = oldCompany.logoURL;
      if (logoURL != null) {
        finalLogoURL = await ref.read(imageNotifier.notifier)
            .uploadImage(logoURL, 'companies/${company.id}/logo');
      }

      await docRef.update(company.copyWith(logoURL: finalLogoURL).toJson());
    });
  }
}

final companyNotifier = AsyncNotifierProvider<CompanyAsyncNotifier, void>(
  CompanyAsyncNotifier.new,
);