require 'rails_helper'

describe ::DiscoursePushNotifications::Pusher do
  let(:registration_id) { 'abcdefghi' }
  let(:endpoint) { "https://somemagic.endpoint/sometoken/#{registration_id}" }

  describe ".extract_unique_id" do
    it "extracts the registration id from the endpoint" do
      expect(described_class.send('extract_unique_id', "endpoint" => endpoint)).to eq(registration_id)
    end
  end
end
