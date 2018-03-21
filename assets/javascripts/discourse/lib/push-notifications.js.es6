import { ajax } from 'discourse/lib/ajax';
import KeyValueStore from 'discourse/lib/key-value-store';

export const keyValueStore = new KeyValueStore("discourse_push_notifications_");

export function userSubscriptionKey(user) {
  return `subscribed-${user.get('id')}`;
}

function sendSubscriptionToServer(subscription) {
  ajax('/push_notifications/subscribe', {
    type: 'POST',
    data: { subscription: subscription.toJSON() }
  });
}

function userAgentVersionChecker(agent, version, mobileView) {
  const uaMatch = navigator.userAgent.match(new RegExp(`${agent}\/(\\d+)\\.\\d`));
  if (uaMatch && mobileView) return false;
  if (!uaMatch || parseInt(uaMatch[1]) < version) return false;
  return true;
}

export function isPushNotificationsSupported(mobileView) {
  if (!(('serviceWorker' in navigator) &&
     (ServiceWorkerRegistration &&
     (typeof(Notification) !== "undefined") &&
     ('showNotification' in ServiceWorkerRegistration.prototype) &&
     ('PushManager' in window)))) {

    return false;
  }

  if ((!userAgentVersionChecker('Firefox', 44, mobileView)) &&
     (!userAgentVersionChecker('Chrome', 50))) {
    return false;
  }

  return true;
}

export function register(user, mobileView, router) {
  if (!isPushNotificationsSupported(mobileView)) return;
    if (Notification.permission === 'denied' || !user) return;

  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager.getSubscription().then(subscription => {
      if (subscription) {
        sendSubscriptionToServer(subscription);
        // Resync localStorage
        keyValueStore.setItem(userSubscriptionKey(user), 'subscribed');
      }
    }).catch(e => Ember.Logger.error(e));
  });

  navigator.serviceWorker.addEventListener('message', (event) => {
    if ('url' in event.data) {
      const url = event.data.url;
      router.handleURL(url);
    }
  });
}

export function subscribe(callback, applicationServerKey) {
  if (!isPushNotificationsSupported()) return;

  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: new Uint8Array(applicationServerKey.split("|")) // eslint-disable-line no-undef
    }).then(subscription => {
      sendSubscriptionToServer(subscription);
      if (callback) callback();
    }).catch(e => Ember.Logger.error(e));
  });
}

export function unsubscribe(callback) {
  if (!isPushNotificationsSupported()) return;

  navigator.serviceWorker.ready.then(serviceWorkerRegistration => {
    serviceWorkerRegistration.pushManager.getSubscription().then(subscription => {
      if (subscription) {
        subscription.unsubscribe().then((successful) => {
          if (successful) {
            ajax('/push_notifications/unsubscribe', {
              type: 'POST',
              data: { subscription: subscription.toJSON() }
            });
          }
        });
      }
    }).catch(e => Ember.Logger.error(e));

    if (callback) callback();
  });
}
