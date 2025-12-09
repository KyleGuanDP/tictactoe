const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// 當 games/{gameId} 更新時觸發，通知下一位玩家
exports.notifyNextPlayerOnMove = functions.firestore
  .document("games/{gameId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // 如果 board 和 currentTurn 都沒變，就不用通知
    if (before.currentTurn === after.currentTurn &&
        JSON.stringify(before.board) === JSON.stringify(after.board)) {
      return null;
    }

    // 只有還在 active 的遊戲才要通知
    if (after.status !== "active") {
      return null;
    }

    const nextTurn = after.currentTurn; // "X" or "O"
    let nextPlayerUserId = null;

    if (nextTurn === "X" && after.playerX && after.playerX.userId) {
      nextPlayerUserId = after.playerX.userId;
    } else if (nextTurn === "O" && after.playerO && after.playerO.userId) {
      nextPlayerUserId = after.playerO.userId;
    }

    if (!nextPlayerUserId) {
      console.log("No next player userId, skip notification.");
      return null;
    }

    console.log(`Next turn: ${nextTurn}, userId: ${nextPlayerUserId}`);

    // 找出下一位玩家的 FCM token
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(nextPlayerUserId)
      .get();

    if (!userDoc.exists) {
      console.log("User doc not found for", nextPlayerUserId);
      return null;
    }

    const userData = userDoc.data() || {};
    const tokens = userData.fcmTokens || [];

    if (!tokens || tokens.length === 0) {
      console.log("No FCM tokens for user", nextPlayerUserId);
      return null;
    }

    const payload = {
      notification: {
        title: "Your move in Tic Tac Toe!",
        body: `It's your turn as ${nextTurn}.`,
      },
      data: {
        gameId: context.params.gameId,
        currentTurn: nextTurn,
      },
    };

    try {
      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log("Notification sent:", response);
    } catch (err) {
      console.error("Error sending notification:", err);
    }

    return null;
  });
