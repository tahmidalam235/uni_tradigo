# Firebase Setup Guide for Uni-Tradigo

This project uses **Firebase Authentication** and **Cloud Firestore**.
Listing images are stored as Base64 data URLs **inside the Firestore
document** so the project works fully on the free Firebase Spark plan.
The Firebase Storage rules are included for future use but are not
required to run the app today.

## One-time setup

1. Open https://console.firebase.google.com/ → select project **`uni-tradigo-f12fe`**.
2. In the left menu, click **Build → Firestore Database**.
3. If Firestore has not been initialized yet, click **Create database**,
   choose **Production mode**, pick any region, click **Enable**.
4. Once the database exists, click the **Rules** tab at the top.
5. **Delete** everything in the editor.
6. **Copy** the entire contents of `firestore.rules` (from this project root)
   and **paste** it into the editor.
7. Click **Publish**.

If you also want the storage rules (not required today):
1. In the left menu, click **Build → Storage**.
2. Click the **Rules** tab.
3. Replace the contents with the contents of `storage.rules`.
4. Click **Publish**.

## Alternative: deploy rules via CLI

If you have the Firebase CLI installed and are logged in, just run:

```bash
cd /c/Users/Tahmid/StudioProjects/uni_tradigo
firebase deploy --only firestore:rules,storage --project uni-tradigo-f12fe
```

You should see:
```
+  firestore: released rules firestore.rules to cloud.firestore
+  storage:    released rules storage.rules to firebase.storage
```

## Configuring the first admin (one-time)

The Admin Dashboard is gated by an `admin` **custom claim** on the
caller's Firebase Auth ID token. The client app **cannot** grant this
claim to itself — that would defeat the purpose. You must set it from
a trusted environment using the Firebase Admin SDK.

### Option A — Firebase Cloud Functions (recommended for production)

Install the Firebase CLI and run:

```bash
firebase init functions   # one-time
```

Then in `functions/index.js`:

```js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Only an existing admin can promote other users.
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied', 'Only admins can grant admin role.');
  }
  const uid = data.uid;
  if (typeof uid !== 'string' || !uid) {
    throw new functions.https.HttpsError('invalid-argument', 'uid required');
  }
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  return { ok: true };
});
```

Deploy:

```bash
firebase deploy --only functions
```

Then call the function from a trusted environment (or from an existing
admin's account) to promote a user.

### Option B — Firebase Admin SDK from a Node script (one-time)

For the very first admin only, use a local script:

```js
// scripts/grant-admin.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const uid = process.argv[2];
admin.auth().setCustomUserClaims(uid, { admin: true })
   .then(() => {
     console.log('Granted admin to', uid);
     process.exit(0);
   });
```

Run:

```bash
node scripts/grant-admin.js <user-uid>
```

Download a service account JSON from
**Project Settings → Service Accounts → Generate new private key**.

After running the script, the user must **sign out and sign back in**
(or wait up to one hour) before the new `admin` claim appears in their
ID token.

## Firestore data model

| Collection | Path | Used for |
| --- | --- | --- |
| `users` | `users/{uid}` | Student profile, department, suspended flag |
| `listings` | `listings/{listingId}` | Marketplace listings (Sale/Rent/Exchange/Donation) |
| `users/{uid}/wishlist/{listingId}` | subcollection | Per-user saved items |
| `wantedPosts` | `wantedPosts/{postId}` | "I am looking for..." posts |
| `conversations` | `conversations/{conversationId}` | Chat summary, 2 participants |
| `conversations/{id}/messages/{msgId}` | subcollection | Chat messages |
| `transactions` | `transactions/{txId}` | Buyer/seller deals |
| `reviews` | `reviews/{reviewId}` | Ratings and feedback |
| `reports` | `reports/{reportId}` | User-submitted reports for admin review |

## Rebuild and test

```bash
flutter pub get
flutter analyze
flutter build apk --debug
flutter install
```

## Approved students

The login and register screens still consult a small client-side email
check (`lib/data/approved_emails.dart`) so the viva demo can limit who
can register. In production this should be replaced by either:

- a server-side allowlist (Cloud Function or custom backend), or
- a `users` collection document that admins must approve before the
  user can sign in.

The Firestore rules already enforce that *all* writes go through an
authenticated student account, so a random internet user cannot create
listings, post wanted items, or read other students' data.
