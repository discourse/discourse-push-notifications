require_relative 'base'
require_dependency 'webpush'

module DiscoursePushNotifications
  class MozillaPusher < Base
    ENDPOINT = 'https://updates.push.services.mozilla.com/push'.freeze

    def self.key_prefix
      "push-services-mozilla".freeze
    end

    def self.push(user, payload)
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
          payload = Webpush::Encryption.encrypt(
            message.to_json,
            subscription.dig("keys", "p256dh"),
            subscription.dig("keys", "auth")
          )

          Webpush::Request.new(subscription["endpoint"], { payload: payload }).perform
        rescue Webpush::InvalidSubscription => e
          # Delete the subscription from Redis
          Rails.logger.warn(e)
          updated = true
          subscriptions(user).delete(extract_unique_id(subscription))
        end
      end

      user.save_custom_fields(true) if updated
    end
  end
end
