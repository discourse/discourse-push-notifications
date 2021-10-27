import { withPluginApi } from "discourse/lib/plugin-api";

import {
  isPushNotificationsSupported,
  keyValueStore,
} from "discourse/lib/push-notifications";

export default {
  name: "setup-push-notifications",
  initialize(container) {
    withPluginApi("0.1", (api) => {
      const siteSettings = container.lookup("site-settings:main");

      if (!Ember.testing && api.getCurrentUser()) {
        if (siteSettings.desktop_push_notifications_enabled) {
          //open class up, add property for saving on notifications
          api.modifyClass("controller:preferences/notifications", {
            pluginId: "discourse-push-notifications",
            saveAttrNames: [
              "muted_usernames",
              "new_topic_duration_minutes",
              "auto_track_topics_after_msecs",
              "notification_level_when_replying",
              "like_notification_frequency",
              "allow_private_messages",
              "custom_fields",
            ],
          });

          api.modifyClass("component:desktop-notification-config", {
            pluginId: "discourse-push-notifications",
            isPushNotificationsPreferred() {
              if (
                !this.site.mobileView &&
                !keyValueStore.getItem("prefer_push")
              ) {
                return false;
              }
              return isPushNotificationsSupported(this.site.mobileView);
            },
          });

          // add key, prefer push
          if (
            api.getCurrentUser().custom_fields[
              "discourse_push_notifications_prefer_push"
            ]
          ) {
            keyValueStore.setItem("prefer_push", "true");
          } else {
            keyValueStore.setItem("prefer_push", "");
          }
        } else {
          keyValueStore.setItem("prefer_push", "");
        }
      }
    });
  },
};
