# name: discourse-push-notifications
# about: Plugin for integrating Chrome and FireFox push notifications
# version: 0.1.0
# authors: Alan Guo Xiang Tan
# url: https://github.com/discourse/discourse-push-notifications

gem 'hkdf', '0.2.0'
gem 'webpush', '0.3.1'

enabled_site_setting :push_notifications_enabled

after_initialize do
  module ::DiscoursePushNotifications
    PLUGIN_NAME ||= "discourse_push_notifications".freeze

    autoload :Pusher, "#{Rails.root}/plugins/discourse-push-notifications/services/discourse_push_notifications/pusher"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePushNotifications
    end
  end

  User.register_custom_field_type(DiscoursePushNotifications::PLUGIN_NAME, :json)

  if SiteSetting.vapid_public_key.blank? || SiteSetting.vapid_private_key.blank?
    vapid_key = Webpush.generate_key
    SiteSetting.vapid_public_key = vapid_key.public_key
    SiteSetting.vapid_private_key = vapid_key.private_key
  end

  SiteSetting.vapid_public_key_bytes = Base64.urlsafe_decode64(SiteSetting.vapid_public_key).bytes.join("|")

  DiscoursePushNotifications::Engine.routes.draw do
    post "/subscribe" => "push#subscribe"
    post "/unsubscribe" => "push#unsubscribe"
  end

  Discourse::Application.routes.append do
    mount ::DiscoursePushNotifications::Engine, at: "/push_notifications"
    get "/push-service-worker.js" => "discourse_push_notifications/service_worker#push"
  end

  require_dependency "application_controller"
  class DiscoursePushNotifications::ServiceWorkerController < ::ApplicationController
    requires_plugin DiscoursePushNotifications::PLUGIN_NAME

    layout false
    skip_before_action :preload_json, :check_xhr, :verify_authenticity_token

    def push
      response.cache_control[:max_age] = 1.year.to_i
      response.cache_control[:public] = true
      render file: "#{Rails.root}/plugins/discourse-push-notifications/assets/javascripts/push-service-worker.js", content_type: Mime[:js]
    end
  end

  class DiscoursePushNotifications::PushController < ::ApplicationController
    requires_plugin DiscoursePushNotifications::PLUGIN_NAME

    layout false
    before_action :ensure_logged_in
    skip_before_action :preload_json

    def subscribe
      DiscoursePushNotifications::Pusher.subscribe(current_user, push_params)
      render json: success_json
    end

    def unsubscribe
      DiscoursePushNotifications::Pusher.unsubscribe(current_user, push_params)
      render json: success_json
    end

    private

    def push_params
      params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
    end
  end

  DiscourseEvent.on(:post_notification_alert) do |user, payload|
    return unless SiteSetting.push_notifications_enabled?
    Jobs.enqueue(:send_push_notifications, user_id: user.id, payload: payload)
  end

  DiscourseEvent.on(:user_logged_out) do |user|
    return unless SiteSetting.push_notifications_enabled?
    DiscoursePushNotifications::Pusher.clear_subscriptions(user)
    user.save_custom_fields(true)
  end

  require_dependency "jobs/base"
  module ::Jobs
    class SendPushNotifications < Jobs::Base
      def execute(args)
        return if !SiteSetting.push_notifications_enabled?
        user = User.find(args[:user_id])
        DiscoursePushNotifications::Pusher.push(user, args[:payload])
      end
    end
  end
end
