import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crowdpass/models/member.dart';

// Simple in-memory member list for demonstration
class MemberState {
  final List<Member> members;
  const MemberState({this.members = const []});

  MemberState copyWith({List<Member>? members}) =>
      MemberState(members: members ?? this.members);
}

class MemberNotifier extends Notifier<MemberState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _eventId;

  @override
  MemberState build() => const MemberState();

  Future<void> addMember(Member member) async {
    final docRef = _firestore
        .collection('events')
        .doc(_eventId)
        .collection('members')
        .doc(member.userId);

    await docRef.set(member.toJson());
    // Optionally update local state if needed
    addMemberLocal(member);
  }

  Future<void> removeMember(String userId) async {
    final docRef = _firestore
        .collection('events')
        .doc(_eventId)
        .collection('members')
        .doc(userId);

    await docRef.delete();
    removeMemberLocal(userId);
  }

  Future<void> updateMember(String userId, {MemberRole? role}) async {
    final docRef = _firestore
        .collection('events')
        .doc(_eventId)
        .collection('members')
        .doc(userId);

    if (role != null) {
      await docRef.update({'role': role.toJson()});
      // Optionally update local state if needed
      updateMemberLocal(userId, role: role);
    }
  }

  // Local state helpers (unchanged)
  void addMemberLocal(Member member) {
    if (state.members.any((m) => m.userId == member.userId)) return;
    state = state.copyWith(members: [...state.members, member]);
  }

  void removeMemberLocal(String userId) {
    state = state.copyWith(
      members: state.members.where((m) => m.userId != userId).toList(),
    );
  }

  void updateMemberLocal(String userId, {MemberRole? role}) {
    state = state.copyWith(
      members: state.members.map((m) {
        if (m.userId == userId && role != null) {
          return m.copyWith(role: role);
        }
        return m;
      }).toList(),
    );
  }
}

final memberProvider =
    NotifierProvider.family<MemberNotifier, MemberState, String>(
  (eventId) => MemberNotifier().._eventId = eventId,
);