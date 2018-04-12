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
      const user = Discourse.User.current();
      return user ? pushNotificationKeyValueStore.getItem(pushNotificationUserDismissedPrompt(user)) : false;
    }
  },

  @computed
  pushNotificationSubscribed: {
    set(value) {
      const user = this.currentUser;
      pushNotificationKeyValueStore.setItem(pushNotificationUserSubscriptionKey(user), value);
      return pushNotificationKeyValueStore.getItem(pushNotificationUserSubscriptionKey(user));
    },
    get() {
      const user = Discourse.User.current();
      return user ? pushNotificationKeyValueStore.getItem(pushNotificationUserSubscriptionKey(user)) : false;
    }
  },

  @computed
  consentPrompt() {
    return I18n.t('discourse_push_notifications.consent_prompt', {preferences: `${Discourse.BaseUri}/u/${this.currentUser.username}/preferences/notifications`});
  },

  @computed("pushNotificationSubscribed", "bannerDismissed")
  showPushNotificationPrompt(pushNotificationSubscribed, bannerDismissed) {
    return (this.siteSettings.push_notifications_enabled &&
            this.siteSettings.push_notifications_prompt &&
            isPushNotificationsSupported() &&
            this.currentUser &&
            this.currentUser.reply_count + this.currentUser.topic_count > 0 &&
            Notification.permission !== "denied" &&
            Notification.permission !== "granted" &&
            !pushNotificationSubscribed &&
            !bannerDismissed
           );
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
