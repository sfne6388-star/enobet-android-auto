const {setGlobalOptions} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({
  maxInstances: 10,
  region: "europe-west1",
});

// Her gün Türkiye saatiyle 18:00'de
// bildirimleri açık olan tüm kullanıcılara
// nöbetçi eczane bildirimi gönderir.
exports.nobetciEczaneBildirimi = onSchedule(
    {
      schedule: "0 18 * * *",
      timeZone: "Europe/Istanbul",
    },
    async () => {
      const message = {
        topic: "eczane_notifications",
        notification: {
          title: "ENöbet - Nöbetçi Eczaneler",
          body: "Bugünkü nöbetçi eczaneleri görmek için dokunun.",
        },
        data: {
          type: "eczane",
          action: "nobetci_eczaneler",
        },
        android: {
          notification: {
            channelId: "eczane_notifications",
            priority: "high",
          },
        },
      };

      try {
        const response = await admin.messaging().send(message);

        logger.info(
            "Nöbetçi eczane bildirimi başarıyla gönderildi.",
            {
              messageId: response,
            },
        );

        return response;
      } catch (error) {
        logger.error(
            "Nöbetçi eczane bildirimi gönderilemedi.",
            error,
        );

        throw error;
      }
    },
);
