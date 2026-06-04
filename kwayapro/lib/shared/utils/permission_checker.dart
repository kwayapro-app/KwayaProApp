import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/choir/domain/choir_providers.dart';
import '../../features/choir/domain/models/choir_membership.dart';
import '../models/enums.dart';

class PermissionChecker {
  final ChoirMembership? membership;
  const PermissionChecker(this.membership);

  bool get isLeader => membership?.role == MemberRole.leader;
  bool get isDirector => membership?.role == MemberRole.director;
  bool get isChorister => membership?.role == MemberRole.chorister;
  bool get isManagement => isLeader || isDirector;

  bool get canUploadAudio =>
      isManagement || _has('audio_uploader');

  bool get canManageScores =>
      isManagement || _has('score_librarian');

  bool get canPlanPrograms =>
      isManagement || _has('song_program_planner');

  bool get canMarkAttendance =>
      isManagement || _has('attendance_manager');

  bool get canPostAnnouncements =>
      isManagement || _has('announcements');

  bool get canManageMembers => isLeader;
  bool get canManageBilling => isLeader;
  bool get canDeleteSongs => isLeader;
  bool get canGrantPermissions => isLeader;

  bool _has(String key) =>
      membership?.permissions.contains(key) ?? false;
}

final permissionCheckerProvider = Provider<PermissionChecker>((ref) {
  final membership = ref.watch(currentMembershipProvider).valueOrNull;
  return PermissionChecker(membership);
});