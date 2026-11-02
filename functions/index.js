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
 */
const REGION = "nam5";

/**
 * Sends a push notification to every device registered for `uid`.
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
    if (!snap.exists) return;

    const tokens = snap.get("fcmTokens");
    if (!Array.isArray(tokens) || tokens.length === 0) return;

    const valid = tokens.filter(
      (t) => typeof t === "string" && t.trim().length > 0
    );
    if (valid.length === 0) return;

    // Convert data values to strings for FCM payload compatibility
    const stringifiedData = {};
    if (data && typeof data === "object") {
      Object.keys(data).forEach((k) => {
        if (data[k] !== undefined && data[k] !== null) {
          stringifiedData[k] = String(data[k]);
        }
      });
    }

    const response = await messaging.sendEachForMulticast({
      tokens: valid,
      notification: { title, body },
      data: stringifiedData,
      android: {
        priority: "high",
        notification: {
          channelId: CHANNEL_ID,
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: "public",
          sound: "default",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
            badge: 1,
            contentAvailable: true,
          },
        },
      },
    });

    // Remove tokens FCM reports as permanently invalid
    const invalid = [];
    response.responses.forEach((r, i) => {
      if (
        !r.success &&
        r.error &&
        (r.error.code === "messaging/registration-token-not-registered" ||
          r.error.code === "messaging/invalid-registration-token")
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
 */
exports.notifyBuyerOnOrderUpdate = onDocumentUpdated(
  { document: "transactions/{txId}", region: REGION },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    if (before.status === after.status) return;

    const status = after.status;
    const listingTitle = (after.listingTitle || "").toString().trim();
    const item = listingTitle || "your item";

    const sellerId = after.sellerId;
    const buyerId = after.buyerId;
    const sellerName = (after.sellerName || "").toString().trim();

    if (!buyerId || buyerId === sellerId) return;

    const actedBy = (after.actedBy || "").toString();
    if (actedBy && actedBy === buyerId) return;

    let title;
    let body;

    if (status === "Accepted" || status === "Confirmed") {
      title = "Order accepted";
      body = `Your order for "${item}" was accepted.`;
    } else if (status === "Cancelled") {
      title = "Order declined";
      body = `Your order for "${item}" was declined or cancelled.`;
    } else if (status === "Completed") {
      title = "Order completed";
      body = `Your order for "${item}" is complete.`;
    } else {
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
    if (!convoSnap.exists) return;

    const participants = convoSnap.get("participants");
    if (!Array.isArray(participants) || participants.length === 0) return;

    const recipientId = participants.find(
      (p) => p !== senderId && typeof p === "string"
    );
    if (!recipientId) return;

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
