import { default as computed } from 'ember-addons/ember-computed-decorators';

import {
  subscribe as subscribePushNotification,
  unsubscribe as unsubscribePushNotification,
  isPushNotificationsSupported,
  keyValueStore as pushNotificationKeyValueStore,
  userSubscriptionKey as pushNotificationUserSubscriptionKey,
  userDismissedPrompt as pushNotificationUserDismissedPrompt,
} from 'discourse/plugins/discourse-push-notifications/discourse/lib/push-notifications';

import {
  context,
  unsubscribe as unsubscribeToNotificationAlert
} from 'discourse/lib/desktop-notifications';

import KeyValueStore from 'discourse/lib/key-value-store';
const desktopNotificationkeyValueStore = new KeyValueStore(context);

export default Ember.Component.extend({
  @computed
  bannerDismissed: {
    set(value) {
      const user = this.currentUser;
      pushNotificationKeyValueStore.setItem(pushNotificationUserDismissedPrompt(user), value);
      return pushNotificationKeyValueStore.getItem(pushNotificationUserDismissedPrompt(user));
    },
    get() {
      return pushNotificationKeyValueStore.getItem(pushNotificationUserDismissedPrompt(Discourse.User.current()));
    }
  },

  @computed
  showPushNotificationPrompt() {
    return (this.siteSettings.push_notifications_enabled &&
            this.siteSettings.push_notifications_prompt &&
            Notification.permission !== "denied" &&
              isPushNotificationsSupported() && this.currentUser
            );
  },

  @computed
  pushNotificationSubscribed: {
    set(value) {
      const user = this.currentUser;
      pushNotificationKeyValueStore.setItem(pushNotificationUserSubscriptionKey(user), value);
      return pushNotificationKeyValueStore.getItem(pushNotificationUserSubscriptionKey(user));
    },
    get() {
      return pushNotificationKeyValueStore.getItem(pushNotificationUserSubscriptionKey(Discourse.User.current()));
    }
  },

  actions: {
    subscribe() {
      subscribePushNotification(() => {
        desktopNotificationkeyValueStore.setItem('notifications-disabled', 'disabled');
        unsubscribeToNotificationAlert(this.messageBus, this.currentUser);
        this.setProperties({bannerDismissed: true, pushNotificationSubscribed: 'subscribed'});
      }, this.siteSettings.vapid_public_key_bytes);
    },
    dismiss() {
      this.set("bannerDismissed", true);
    }
  }
});
