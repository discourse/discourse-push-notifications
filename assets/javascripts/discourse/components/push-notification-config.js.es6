import discourseComputed from "discourse-common/utils/decorators";
import { keyValueStore } from "discourse/lib/push-notifications";

export default Ember.Component.extend({
  @discourseComputed
  showSetting() {
    return this.siteSettings.desktop_push_notifications_enabled;
  },

  actions: {
    change(enable) {
      if (enable) {
        this.currentUser.set(
          "custom_fields.discourse_push_notifications_prefer_push",
          true
        );
        keyValueStore.setItem("prefer_push", "true");
      } else {
        this.currentUser.set(
          "custom_fields.discourse_push_notifications_prefer_push",
          false
        );
        keyValueStore.setItem("prefer_push", "");
      }
    },
  },
});
