require_dependency 'webpush'

module DiscoursePushNotifications
  class Pusher
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

        subject =
          if !SiteSetting.contact_email.blank?
            "mailto:#{SiteSetting.contact_email}"
          elsif !SiteSetting.contact_url.blank?
            SiteSetting.contact_url
          else
            Discourse.base_url
          end

        begin
          response = Webpush.payload_send(
            endpoint: subscription["endpoint"],
            message: message.to_json,
            p256dh: subscription.dig("keys", "p256dh"),
            auth: subscription.dig("keys", "auth"),
            vapid: {
              subject: Discourse.base_url,
              public_key: SiteSetting.vapid_public_key,
              private_key: SiteSetting.vapid_private_key
            }
          )
        rescue Webpush::InvalidSubscription => e
          # Delete the subscription from Redis
          updated = true
          subscriptions(user).delete(extract_unique_id(subscription))
        end
      end

      user.save_custom_fields(true) if updated
    end

    SUBSCRIPTION_KEY = "subscriptions".freeze

    def self.subscriptions(user)
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME] ||= {}
      # this might be an array due to merging, so resovle the merge.
      if user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME].kind_of?(Array)
        merged_subscriptions = {}
        user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME].each do |subscription|
          merged_subscriptions = merged_subscriptions.merge(subscription[SUBSCRIPTION_KEY])
        end
        user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME] = merged_subscriptions
      end
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME][SUBSCRIPTION_KEY] ||= {}
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME][SUBSCRIPTION_KEY]
    end

    def self.clear_subscriptions(user)
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME] = {}
    end

    def self.subscribe(user, subscription)
      subscriptions(user)[extract_unique_id(subscription)] = subscription.to_json
      user.save_custom_fields(true)
    end

    def self.unsubscribe(user, subscription)
      subscriptions(user).delete(extract_unique_id(subscription))
      user.save_custom_fields(true)
    end

    protected

    def self.extract_unique_id(subscription)
      subscription["endpoint"].split("/").last
    end
  end
end
