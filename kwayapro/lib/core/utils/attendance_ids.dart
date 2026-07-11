/// Shared composite-ID convention for the `attendance` collection, used by
/// both AttendanceRepository and RehearsalRepository (RSVP methods write to
/// the same collection under the same ID scheme). Previously each
/// repository independently rebuilt the `${sessionId}_${userId}` string —
/// harmless while both stayed in sync, but a maintainability landmine: a
/// future edit to one without the other would silently create orphaned or
/// duplicate attendance docs. Matches the same composite-ID convention
/// already used for `choir_memberships/{choirId}_{userId}` elsewhere in the
/// codebase.
class AttendanceIds {
  AttendanceIds._();

  static String compositeId(String sessionId, String userId) => '${sessionId}_$userId';
}
