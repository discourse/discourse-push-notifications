require_relative 'base'
require_dependency 'webpush'

module DiscoursePushNotifications
  class GCMPusher < Base
    ENDPOINT = 'https://android.googleapis.com/gcm/send'.freeze

    def self.key_prefix
      "google-cloud-messaging".freeze
    end

    def self.subscriptions(user)
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME] ||= {}
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME][key_prefix] ||= {}
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME][key_prefix]
    end

    def self.subscribe(user, subscription)
      subscriptions(user)[extract_unique_id(subscription)] = subscription.to_json
      user.save_custom_fields(true)
    end

    def self.unsubscribe(user, subscription)
      subscriptions(user).delete(extract_unique_id(subscription))
      user.save_custom_fields(true)
    end

    def self.push(user, payload)
      return if SiteSetting.gcm_api_key.blank?

      updated = false

      subscriptions(user).each do |_, subscription|
        subscription = JSON.parse(subscription)

        message = {
          title: I18n.t(
            "discourse_push_notifications.popup.#{Notification.types[payload[:notification_type]]}",
            site_title: SiteSetting.title,
            topic: payload[:topic_title],
            username: payload[:username]
          ),
          body: payload[:excerpt],
          icon: SiteSetting.logo_small_url || SiteSetting.logo_url,
          tag: "#{Discourse.current_hostname}-#{payload[:topic_id]}",
          url: "#{Discourse.base_url}#{payload[:post_url]}"
        }

        begin
          Webpush.payload_send(
            endpoint: subscription["endpoint"],
            message: message.to_json,
            p256dh: subscription.dig("keys", "p256dh"),
            auth: subscription.dig("keys", "auth"),
            api_key: SiteSetting.gcm_api_key
          )
        rescue Webpush::InvalidSubscription
          # Delete the subscription from Redis
          updated = true
          subscriptions(user).delete(extract_unique_id(subscription))
        end
      end

      user.save_custom_fields(true) if updated
    end

    private

    def self.extract_unique_id(subscription)
      subscription["endpoint"].split("/").last
    end
  end
end
