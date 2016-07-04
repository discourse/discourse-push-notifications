module DiscoursePushNotifications
  class Base
    def self.key_prefix
      raise "Not implemented."
    end

    def self.push(user, payload)
      raise "Not implemented."
    end

    def self.subscriptions(user)
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME] ||= {}
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME][key_prefix] ||= {}
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME][key_prefix]
    end

    def self.clear_subscriptions(user)
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME] ||= {}
      user.custom_fields[DiscoursePushNotifications::PLUGIN_NAME][key_prefix] = {}
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
