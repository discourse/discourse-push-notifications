import { default as computed } from 'ember-addons/ember-computed-decorators';
import {
  keyValueStore
} from 'discourse/lib/push-notifications';

export default Ember.Component.extend({

  @computed
  showSetting() {
    return this.siteSettings.desktop_push_notifications_enabled;
  },

  actions: {
    change(enable) {
      if(enable) {
        this.currentUser.set('custom_fields.discourse_push_notifications_prefer_push', true);
        keyValueStore.setItem('prefer_push', 'true');
      }
      else {
        this.currentUser.set('custom_fields.discourse_push_notifications_prefer_push', false);
        keyValueStore.setItem('prefer_push', '');
      }
    }
  }
});
