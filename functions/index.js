/**
 * Uni-Tradigo — Cloud Functions for push notifications.
 *
 * Three Firestore triggers send a push notification to a specific user:
 *
 *   1. notifySellerOnOrderPlaced
 *      Fires when a transaction document is created (status = Pending).
 *      Notifies the SELLER that a buyer placed an order.
 *
 *   2. notifyBuyerOnOrderUpdate
 *      Fires when a transaction's status changes.
 *      Notifies the BUYER when the seller accepts (Confirmed), rejects /
 *      cancels (Cancelled), or completes (Completed) the order.
 *
 *   3. notifyRecipientOnMessage
 *      Fires when a chat message is created.
 *      Notifies the other participant in the conversation.
 *
 * Why the sends live here and not in the app:
 *   The `firebase_messaging` Flutter SDK is receive-only — it cannot
 *   target a specific user's device token. Sending requires the Admin
 *   SDK, which only runs on a trusted server. Doing the send from a
 *   Firestore trigger also guarantees the notification is only ever
 *   sent after the underlying write has already succeeded.
 *
 * Tokens live on `users/{uid}.fcmTokens` (a list of device tokens).
 * The Flutter app writes them when the user signs in.
 */

const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

/** Must match `default_notification_channel_id` in AndroidManifest.xml. */
const CHANNEL_ID = "uni_tradigo_notifications";

/**
 * Firestore region the app's database lives in.
 *
 * This must match the database's actual location — a trigger deployed to
 * a different region never fires. The project's database reports
 * `locationId: nam5` (Iowa), so that is what the triggers use.
 */
const REGION = "nam5";

/**
 * Sends a push notification to every device registered for `uid`.
 *
 * Never throws. A notification failure is logged and swallowed so it can
 * never fail the Firestore trigger that caused it (which would make the
 * platform retry the trigger endlessly).
 *
 * @param {string} uid The recipient's Firebase Auth UID.
 * @param {string} title Notification title.
 * @param {string} body Notification body.
 * @param {Object} data Extra key/value payload delivered to the app.
 */
async function notifyUser(uid, title, body, data) {
  try {
    if (!uid) return;

    const snap = await db.collection("users").doc(uid).get();
    const tokens = snap.get("fcmTokens");
    if (!Array.isArray(tokens) || tokens.length === 0) return;

    const valid = tokens.filter(
      (t) => typeof t === "string" && t.length > 0
    );
    if (valid.length === 0) return;

    const response = await messaging.sendEachForMulticast({
      tokens: valid,
      notification: { title, body },
      data,
      android: {
        priority: "high",
        notification: { channelId: CHANNEL_ID },
      },
    });

    // Remove tokens FCM reports as permanently invalid (app uninstalled,
    // token regenerated, etc.) so we stop retrying them.
    const invalid = [];
    response.responses.forEach((r, i) => {
      if (
        !r.success &&
        r.error &&
        r.error.code === "messaging/registration-token-not-registered"
      ) {
        invalid.push(valid[i]);
      }
    });

    if (invalid.length > 0) {
      await db
        .collection("users")
        .doc(uid)
        .set(
          { fcmTokens: FieldValue.arrayRemove(...invalid) },
          { merge: true }
        );
    }
  } catch (err) {
    console.error("notifyUser failed:", err);
  }
}

/**
 * Order placed — notifies the SELLER.
 *
 * The app writes a transaction with status `Pending` the moment a buyer
 * places an order. This trigger watches for that *creation*, so the seller
 * learns about the order immediately rather than waiting for the buyer to
 * confirm it.
 *
 * A status transition to `Confirmed` is handled by
 * [notifyBuyerOnOrderUpdate] instead — that one notifies the buyer.
 */
exports.notifySellerOnOrderPlaced = onDocumentCreated(
  { document: "transactions/{txId}", region: REGION },
  async (event) => {
    const tx = event.data?.data();
    if (!tx) return;

    const sellerId = tx.sellerId;
    const buyerId = tx.buyerId;
    const buyerName = (tx.buyerName || "").toString().trim();
    const listingTitle = (tx.listingTitle || "").toString().trim();

    // Never notify a user about their own action.
    if (!sellerId || sellerId === buyerId) return;

    const who = buyerName || "A buyer";
    const what = listingTitle || "your listing";

    await notifyUser(
      sellerId,
      "New order!",
      `${who} placed an order for "${what}".`,
      {
        type: "order_placed",
        transactionId: event.params["txId"],
        listingTitle: listingTitle,
        buyerName: buyerName,
      }
    );
  }
);

/**
 * Order update — notifies the BUYER.
 *
 * Watches for a *status transition* on an existing transaction and tells
 * the buyer what the other side decided:
 *
 *   Confirmed  → the order was accepted.
 *   Cancelled  → the order was rejected or cancelled.
 *   Completed  → the order was completed.
 *
 * The client stamps every status write with `actedBy` (the uid of the
 * participant who acted). That is what lets this trigger tell a
 * seller-driven decision (accept / reject / cancel / complete) apart from
 * the buyer's own "Confirm Deal" tap — the latter is the buyer acting on
 * their own order and must never produce a notification. When `actedBy`
 * is absent (older documents written before this field existed) the
 * change is treated as seller-driven only if the actor is unknown, which
 * keeps legacy behaviour working.
 */
exports.notifyBuyerOnOrderUpdate = onDocumentUpdated(
  { document: "transactions/{txId}", region: REGION },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    // Only react to a real status change.
    if (before.status === after.status) return;

    const status = after.status;
    const listingTitle = (after.listingTitle || "").toString().trim();
    const item = listingTitle || "your item";

    const sellerId = after.sellerId;
    const buyerId = after.buyerId;
    const sellerName = (after.sellerName || "").toString().trim();

    // Never notify a user about their own action.
    if (!buyerId || buyerId === sellerId) return;

    // Who made this change? The buyer tapping "Confirm Deal" on their own
    // order is a buyer-driven change — that is not something the buyer
    // needs to be told about.
    const actedBy = (after.actedBy || "").toString();
    if (actedBy && actedBy === buyerId) return;

    let title;
    let body;

    if (status === "Confirmed") {
      title = "Order accepted";
      body = `Your order for "${item}" was accepted.`;
    } else if (status === "Cancelled") {
      title = "Order declined";
      body = `Your order for "${item}" was declined or cancelled.`;
    } else if (status === "Completed") {
      title = "Order completed";
      body = `Your order for "${item}" is complete.`;
    } else {
      // Any other status change is not a notification-worthy event.
      return;
    }

    await notifyUser(
      buyerId,
      title,
      body,
      {
        type: "order_update",
        transactionId: event.params["txId"],
        status: status,
        listingTitle: listingTitle,
        sellerName: sellerName,
      }
    );
  }
);

/**
 * Chat notification — notifies the recipient of a new message.
 *
 * The message document holds `senderId` but not the recipient, so the
 * recipient is derived from the parent conversation's `participants`
 * list: it is the participant who is *not* the sender. Deriving it this
 * way also makes it structurally impossible to notify the sender.
 */
exports.notifyRecipientOnMessage = onDocumentCreated(
  {
    document: "conversations/{conversationId}/messages/{messageId}",
    region: REGION,
  },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    const senderId = (msg.senderId || "").toString();
    const senderName = (msg.senderName || "").toString().trim();
    const text = (msg.text || "").toString().trim();
    const imageUrl = (msg.imageUrl || "").toString();

    const conversationId = event.params["conversationId"];
    const convoSnap = await db
      .collection("conversations")
      .doc(conversationId)
      .get();
    const participants = convoSnap.get("participants");
    if (!Array.isArray(participants) || participants.length === 0) return;

    // The recipient is the participant who is not the sender.
    const recipientId = participants.find(
      (p) => p !== senderId && typeof p === "string"
    );
    if (!recipientId) return;

    // Belt and braces — never notify the sender about their own message.
    if (recipientId === senderId) return;

    const body = text
      ? text
      : imageUrl
        ? "📷 Sent you a photo"
        : "New message";

    await notifyUser(
      recipientId,
      senderName || "New message",
      body,
      {
        type: "chat",
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
      }
    );
  }
);
