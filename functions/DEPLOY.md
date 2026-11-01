# Deploying the push-notification Cloud Functions

The app's push notifications are delivered by three Cloud Functions that
live in `functions/`. They are triggered by Firestore writes, so a
notification is only ever sent **after** the underlying purchase or chat
write has already succeeded.

| Function | Trigger | Notifies | When |
|---|---|---|---|
| `notifySellerOnOrderPlaced` | `transactions/{txId}` **created** | the **seller** | a buyer places an order |
| `notifyBuyerOnOrderUpdate` | `transactions/{txId}` **updated** | the **buyer** | the seller accepts / rejects / cancels / completes the order |
| `notifyRecipientOnMessage` | `conversations/{id}/messages/{id}` **created** | the other participant | a chat message is sent |

## Why the app cannot send these itself

The Flutter `firebase_messaging` client SDK is **receive-only**. It has
`getToken`, `onMessage`, `onBackgroundMessage`, `getInitialMessage` and
`requestPermission` — but no `send` / `sendToToken` / `sendToTopic`.
Sending to a specific user's device token requires the Firebase Admin
SDK, which only runs on a trusted server. That is what these functions
are.

## One-time setup (project owner only)

Deploying Cloud Functions requires the **Blaze** plan. The project is
currently on the Spark (free) plan, which has no billing account linked,
so the deploy below stops with:

> Your project must be on the Blaze (pay-as-you-go) plan to complete this
> command.

To fix it:

1. Open <https://console.firebase.google.com/project/uni-tradigo-f12fe/usage/details>.
2. Click **Modify plan** and upgrade to **Blaze (pay as you go)**.
3. Link a Google Cloud billing account (the project has none yet — the
   upgrade prompts you to create or pick one).
4. Wait a few minutes for the billing link to propagate.

The **Cloud Functions API** is already enabled for this project; the
deploy enables the remaining required APIs (`cloudbuild`,
`artifactregistry`) automatically once Blaze is active.

## Deploying

From the project root:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions --project uni-tradigo-f12fe
```

## Checking that it worked

```bash
firebase functions:list --project uni-tradigo-f12fe
```

All three functions should appear.

To watch a notification being sent:

```bash
firebase functions:log --project uni-tradigo-f12fe
```

## Region

The triggers are deployed to **`nam5`** (Iowa), which is where this
project's Firestore database actually lives. A trigger deployed to a
different region never fires, so do not change `REGION` in
`functions/index.js` unless the database region changes too. Confirm the
current region with:

```bash
firebase firestore:databases:get --project uni-tradigo-f12fe
```

## Tokens

Device tokens are stored on the user's own Firestore document:

```
users/{uid}.fcmTokens = ["<token>", ...]
```

The app writes them on sign-in (and on token refresh) using a merge
update, so it never disturbs the rest of the profile. No Firestore rules
change was needed for this — `users/{userId}` already allows the owner
to update their own document.

If FCM reports a token as permanently invalid (the app was uninstalled,
or the token was regenerated), the function removes it from the list
automatically so the server stops retrying it.
