# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersController do
  let(:user) { Fabricate(:user) }

  before do
    SiteSetting.desktop_push_notifications_enabled = true
  end

  describe '#update' do
    describe 'updating custom fields to prefer push on desktop' do
      it 'should update the custom fields correctly' do
        sign_in(user)
        field_name = "#{DiscoursePushNotifications::PLUGIN_NAME}_prefer_push"

        put "/u/#{user.username}", params: {
          custom_fields: {
            field_name => true
          }
        }

        expect(response.status).to eq(200)
        expect(user.reload.custom_fields).to eq(field_name => true)
      end
    end
  end
end
