// DEMO ONLY:
// This client-side whitelist is suitable for the academic demo,
// but it is not a secure production authorization mechanism.
// Production should manage approved users using server-side
// authorization / Firestore Security Rules / Cloud Functions.

// BUP student emails use the pattern <student-id>@student.bup.edu.bd
// (e.g. 524202151@student.bup.edu.bd). We accept:
//   1. Any exact address listed in [approvedEmails] below (case-insensitive).
//   2. Any address ending in "@student.bup.edu.bd" — i.e. any real BUP
//      student email.
//
// Matching rules:
//   - Input is trimmed and converted to lowercase.
//   - Exact-match checks are case-insensitive (lowercased first).
//   - Suffix check requires the address to end with "@student.bup.edu.bd"
//     (not just "@bup.edu.bd" or "@bup.edu"), so random addresses from
//     a different BUP subdomain are still rejected.

const String studentEmailSuffix = '@student.bup.edu.bd';

// Optional named approval list. Useful for the viva demo to point at known
// test users. In addition, any *@student.bup.edu.bd is accepted.
const List<String> approvedEmails = [
  'student1@bup.edu.bd',
  'student2@bup.edu.bd',
  'student3@bup.edu.bd',
  'student4@bup.edu.bd',
];

/// Returns true if [email] is either on the explicit [approvedEmails]
/// list, or is a real BUP student email of the form
/// `<id>@student.bup.edu.bd`.
bool isApprovedEmail(String email) {
  final normalized = email.trim().toLowerCase();
  if (normalized.isEmpty) return false;

  // 1. Explicit list (kept for the demo).
  for (final approved in approvedEmails) {
    if (approved.toLowerCase() == normalized) return true;
  }

  // 2. Any genuine BUP student email format.
  return normalized.endsWith(studentEmailSuffix);
}
