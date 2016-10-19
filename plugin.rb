# name: discourse-push-notifications
# about: Plugin for integrating Chrome and FireFox push notifications
# version: 0.0.1
# authors: Alan Guo Xiang Tan
# url: https://github.com/discourse/discourse-push-notifications

gem 'hkdf', '0.2.0'
gem 'webpush', '0.2.3'

enabled_site_setting :push_notifications_enabled

after_initialize do
  module ::DiscoursePushNotifications
    PLUGIN_NAME ||= "discourse_push_notifications".freeze

    autoload :GCMPusher, "#{Rails.root}/plugins/discourse-push-notifications/services/discourse_push_notifications/gcm_pusher"
    autoload :MozillaPusher, "#{Rails.root}/plugins/discourse-push-notifications/services/discourse_push_notifications/mozilla_pusher"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePushNotifications
    end
  end

  User.register_custom_field_type(DiscoursePushNotifications::PLUGIN_NAME, :json)

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
    skip_before_filter :preload_json, :check_xhr, :verify_authenticity_token

    def push
      render file: "#{Rails.root}/plugins/discourse-push-notifications/assets/javascripts/push-service-worker.js", content_type: Mime::JS
    end
  end

  class DiscoursePushNotifications::PushController < ::ApplicationController
    requires_plugin DiscoursePushNotifications::PLUGIN_NAME

    layout false
    before_filter :ensure_logged_in
    skip_before_filter :preload_json

    def subscribe
      endpoint = push_params[:endpoint]

      if endpoint.start_with?(DiscoursePushNotifications::GCMPusher::ENDPOINT)
        DiscoursePushNotifications::GCMPusher.subscribe(current_user, push_params)
        render json: success_json
      elsif endpoint.start_with?(DiscoursePushNotifications::MozillaPusher::ENDPOINT)
        DiscoursePushNotifications::MozillaPusher.subscribe(current_user, push_params)
        render json: success_json
      else
        render json: failed_json
      end
    end

    def unsubscribe
      endpoint = push_params[:endpoint]

      if endpoint.start_with?(DiscoursePushNotifications::GCMPusher::ENDPOINT)
        DiscoursePushNotifications::GCMPusher.unsubscribe(current_user, push_params)
        render json: success_json
      elsif endpoint.start_with?(DiscoursePushNotifications::MozillaPusher::ENDPOINT)
        DiscoursePushNotifications::MozillaPusher.unsubscribe(current_user, push_params)
        render json: success_json
      else
        render json: failed_json
      end
    end

    private

    def push_params
      params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
    end
  end

  require_dependency "metadata_controller"
  class ::MetadataController
    def manifest
      if SiteSetting.push_notifications_enabled && !SiteSetting.gcm_sender_id.blank?
        manifest = default_manifest.merge({
          gcm_sender_id: SiteSetting.gcm_sender_id,
          gcm_user_visible_only: true # This is required for Chrome 42 up to Chrome 44
        })

        render json: manifest.to_json
      else
        render json: default_manifest.to_json
      end
    end
  end

  DiscourseEvent.on(:post_notification_alert) do |user, payload|
    return unless SiteSetting.push_notifications_enabled?
    Jobs.enqueue(:send_push_notifications, { user_id: user.id, payload: payload })
  end

  DiscourseEvent.on(:user_logged_out) do |user|
    return unless SiteSetting.push_notifications_enabled?
    DiscoursePushNotifications::GCMPusher.clear_subscriptions(user)
    DiscoursePushNotifications::MozillaPusher.clear_subscriptions(user)
    user.save_custom_fields(true)
  end

  require_dependency "jobs/base"
  module ::Jobs
    class SendPushNotifications < Jobs::Base
      sidekiq_options retry: false

      def execute(args)
        return if !SiteSetting.push_notifications_enabled?

        user = User.find(args[:user_id])

        [
          DiscoursePushNotifications::GCMPusher,
          DiscoursePushNotifications::MozillaPusher
        ].each do |pusher|
          pusher.public_send(:push, user, args[:payload])
        end
      end
    end
  end
end
