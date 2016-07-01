import { withPluginApi } from 'discourse/lib/plugin-api';

import {
  register as registerPushNotifications
} from 'discourse/plugins/discourse-push-notifications/discourse/lib/push-notifications';

export default {
  name: 'setup-push-notifications',
  initialize() {
    withPluginApi('0.1', api => {
      if (!Ember.testing) {
        registerPushNotifications(api.getCurrentUser());
      }
    });
  }
};
