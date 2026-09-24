const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggered when a new document is created in the "notifications" collection.
 * Sends FCM push notifications to all subscribed devices (or targeted student tokens).
 */
exports.sendPushOnNotificationCreated = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const data = snapshot.data();
  const userId = data.userId || "all";
  const title = data.title || "EduRise Announcement";
  const body = data.body || "";
  const type = data.type || "announcement";

  const payload = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      notificationId: event.params.notificationId,
      type: type,
      route: "/notifications",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "edurise_announcements",
        icon: "@mipmap/ic_launcher",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
  };

  try {
    if (userId === "all") {
      // Broadcast to topic
      await admin.messaging().send({
        topic: "announcements",
        ...payload,
      });
      console.log(`Successfully broadcasted announcement ${event.params.notificationId} to topic: announcements`);
    } else {
      // Send to student specific tokens
      const studentDoc = await admin.firestore().collection("students").doc(userId).get();
      if (!studentDoc.exists) return;

      const studentData = studentDoc.data();
      const tokens = studentData.fcmTokens || [];

      if (tokens.length > 0) {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokens,
          ...payload,
        });
        console.log(`Sent notification to student ${userId}. Success: ${response.successCount}, Failures: ${response.failureCount}`);
      }
    }
  } catch (error) {
    console.error("Error sending FCM notification:", error);
  }
});
