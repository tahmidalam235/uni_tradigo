# Firebase Setup Guide for Uni-Tradigo

This project uses **Firestore only** (no Firebase Storage). The selected image
is converted to a Base64 data URL and saved inside the Firestore document
directly, so the project works fully on the free Firebase Spark plan.

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

The rules look like:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /listings/{listingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.sellerId == request.auth.uid;
      allow update, delete: if request.auth != null
                            && resource.data.sellerId == request.auth.uid;
    }
    match /users/{userId} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null
                            && request.auth.uid == userId;
      allow delete: if false;
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Alternative: deploy rules via CLI

If you have the Firebase CLI installed and are logged in, just run:

```bash
cd /c/Users/Tahmid/StudioProjects/uni_tradigo
firebase deploy --only firestore:rules --project uni-tradigo-f12fe
```

You should see:
```
+  firestore: released rules firestore.rules to cloud.firestore
```

## Rebuild and test

```bash
flutter build apk --debug
flutter install
```

Now:
- Post a listing → it will appear on Home.
- Pick an image → it will be stored as Base64 inside the listing document
  and shown on the Item Details screen.
- Logout → Login → the listing is still there.
- Login as another user → the listing is visible on Home but NOT in that
  user's "My Listings".

## Why Firestore only (no Storage)?

Firebase Storage requires the paid Blaze plan on newer projects. To keep this
academic project fully on the free Spark plan, listing images are converted to
Base64 strings and stored directly in the Firestore document. This works
transparently: `Image.network(...)` accepts Base64 data URLs out of the box.

The Firestore per-document size limit is 1 MB, which is plenty for compressed
listing photos.
