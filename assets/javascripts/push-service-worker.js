function showNotification(title, body, icon, badge, tag, baseUrl, url) {
  var notificationOptions = {
    body: body,
    icon: icon,
    badge: badge,
    data: { url: url, baseUrl: baseUrl },
    tag: tag
  }

  return self.registration.showNotification(title, notificationOptions);
}

self.addEventListener('push', function(event) {
  var payload = event.data.json();

  event.waitUntil(
    self.registration.getNotifications({ tag: payload.tag }).then(function(notifications) {
      if (notifications && notifications.length > 0) {
        notifications.forEach(function(notification) {
          notification.close();
        });
      }

      return showNotification(payload.title, payload.body, payload.icon, payload.badge, payload.tag, payload.base_url, payload.url);
    })
  );
});

self.addEventListener('notificationclick', function(event) {
  // Android doesn't close the notification when you click on it
  // See: http://crbug.com/463146
  event.notification.close();
  var url = event.notification.data.url;
  var baseUrl = event.notification.data.baseUrl;

  // This looks to see if the current window is already open and
  // focuses if it is
  event.waitUntil(
    clients.matchAll({ type: "window" })
      .then(function(clientList) {
        var reusedClientWindow = clientList.some(function(client) {
          if (client.url === baseUrl + url && 'focus' in client) {
            client.focus();
            return true;
          }

          if ('postMessage' in client && 'focus' in client) {
            client.focus();
            client.postMessage({ url: url });
            return true;
          }
          return false;
        });

        if (!reusedClientWindow && clients.openWindow) return clients.openWindow(baseUrl + url);
      })
  );
});
