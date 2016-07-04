import { withPluginApi } from 'discourse/lib/plugin-api';

import {
  register as registerPushNotifications
} from 'discourse/plugins/discourse-push-notifications/discourse/lib/push-notifications';

export default {
  name: 'setup-push-notifications',
  initialize(container) {
    withPluginApi('0.1', api => {
      const siteSettings = container.lookup('site-settings:main');
      const site = container.lookup('site:main');

      if (!Ember.testing && siteSettings.push_notifications_enabled) {
        const mobileView = site.mobileView;
        registerPushNotifications(api.getCurrentUser(), mobileView);
      }
    });
  }
};
