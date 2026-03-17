import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared Firestore provider used across the app to avoid duplicate symbol
/// collisions when multiple provider files are imported together.
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);