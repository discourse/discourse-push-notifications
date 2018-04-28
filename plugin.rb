# name: discourse-push-notifications
# about: Plugin for integrating Chrome and FireFox push notifications
# version: 0.3.0
# authors: Alan Guo Xiang Tan, Jeff Wong
# url: https://github.com/discourse/discourse-push-notifications

enabled_site_setting :desktop_push_notifications_enabled

DiscoursePluginRegistry.serialized_current_user_fields << "discourse_push_notifications_prefer_push"

after_initialize do
  module ::DiscoursePushNotifications
    PLUGIN_NAME ||= "discourse_push_notifications".freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePushNotifications
    end
  end

  User.register_custom_field_type("#{DiscoursePushNotifications::PLUGIN_NAME}_prefer_push", :boolean)
end
