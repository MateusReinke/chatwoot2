require 'rails_helper'

describe Whatsapp::BaileysHandlers::MessagesUpsert do
  let(:webhook_verify_token) { 'valid_token' }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp,
           provider: 'baileys',
           provider_config: { webhook_verify_token: webhook_verify_token },
           validate_provider_config: false,
           received_messages: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:timestamp) { Time.current.to_i }

  before do
    stub_request(:get, /profile-picture-url/)
      .to_return(
        status: 200,
        body: { data: { profilePictureUrl: nil } }.to_json
      )
  end

  describe '#update_existing_contact_inbox' do
    context 'when updating contact inbox with LID information' do
      let(:phone) { '5511912345678' }
      let(:lid) { '12345678' }
      let(:source_id) { lid }
      let(:identifier) { "#{lid}@lid" }

      context 'when there is no conflict' do
        it 'updates existing contact_inbox source_id from phone to LID' do
          contact = create(:contact, account: inbox.account, phone_number: "+#{phone}", identifier: nil)
          contact_inbox = create(:contact_inbox, inbox: inbox, contact: contact, source_id: phone)

          raw_message = {
            key: { id: 'msg_123', remoteJid: "#{lid}@lid", remoteJidAlt: "#{phone}@s.whatsapp.net", fromMe: false, addressingMode: 'lid' },
            pushName: 'John Doe',
            messageTimestamp: timestamp,
            message: { conversation: 'Hello' }
          }
          params = {
            webhookVerifyToken: webhook_verify_token,
            event: 'messages.upsert',
            data: { type: 'notify', messages: [raw_message] }
          }

          expect do
            Whatsapp::IncomingMessageBaileysService.new(inbox: inbox, params: params).perform
          end.not_to raise_error

          expect(contact_inbox.reload.source_id).to eq(source_id)
          expect(contact.reload.identifier).to eq(identifier)
          expect(contact.phone_number).to eq("+#{phone}")
        end
      end

      context 'when identifier is already taken by a different contact (race condition)' do
        it 'does not raise validation error and skips the update' do
          original_contact = create(:contact, account: inbox.account, phone_number: nil, identifier: nil, name: 'Original Contact')
          original_contact_inbox = create(:contact_inbox, inbox: inbox, contact: original_contact, source_id: phone)

          conflicting_contact = create(:contact, account: inbox.account, phone_number: "+#{phone}", identifier: identifier,
                                                 name: 'Conflicting Contact')
          create(:contact_inbox, inbox: inbox, contact: conflicting_contact, source_id: source_id)

          raw_message = {
            key: { id: 'msg_123', remoteJid: "#{lid}@lid", remoteJidAlt: "#{phone}@s.whatsapp.net", fromMe: false, addressingMode: 'lid' },
            pushName: 'John Doe',
            messageTimestamp: timestamp,
            message: { conversation: 'Hello' }
          }
          params = {
            webhookVerifyToken: webhook_verify_token,
            event: 'messages.upsert',
            data: { type: 'notify', messages: [raw_message] }
          }

          expect do
            Whatsapp::IncomingMessageBaileysService.new(inbox: inbox, params: params).perform
          end.not_to raise_error

          expect(original_contact_inbox.reload.source_id).to eq(phone)
          expect(original_contact.reload.identifier).to be_nil

          message = inbox.messages.last
          expect(message).to be_present
          expect(message.sender).to eq(conflicting_contact)
          expect(message.conversation.contact).to eq(conflicting_contact)
        end
      end

      context 'when phone number is already taken by a different contact (race condition)' do
        it 'does not raise validation error and skips the update' do
          original_contact = create(:contact, account: inbox.account, phone_number: nil, identifier: nil)
          create(:contact_inbox, inbox: inbox, contact: original_contact, source_id: phone)

          different_lid = '87654321'
          different_identifier = "#{different_lid}@lid"
          conflicting_contact = create(:contact, account: inbox.account, phone_number: "+#{phone}", identifier: different_identifier)
          create(:contact_inbox, inbox: inbox, contact: conflicting_contact, source_id: different_lid)

          raw_message = {
            key: { id: 'msg_123', remoteJid: "#{lid}@lid", remoteJidAlt: "#{phone}@s.whatsapp.net", fromMe: false, addressingMode: 'lid' },
            pushName: 'John Doe',
            messageTimestamp: timestamp,
            message: { conversation: 'Hello' }
          }
          params = {
            webhookVerifyToken: webhook_verify_token,
            event: 'messages.upsert',
            data: { type: 'notify', messages: [raw_message] }
          }

          expect do
            Whatsapp::IncomingMessageBaileysService.new(inbox: inbox, params: params).perform
          end.not_to raise_error

          expect(original_contact.reload.phone_number).to be_nil
          expect(original_contact.identifier).to be_nil
        end
      end

      context 'when updating the same contact (no conflict)' do
        it 'successfully updates the contact' do
          contact = create(:contact, account: inbox.account, phone_number: "+#{phone}", identifier: nil)
          contact_inbox = create(:contact_inbox, inbox: inbox, contact: contact, source_id: phone)

          raw_message = {
            key: { id: 'msg_123', remoteJid: "#{lid}@lid", remoteJidAlt: "#{phone}@s.whatsapp.net", fromMe: false, addressingMode: 'lid' },
            pushName: 'John Doe',
            messageTimestamp: timestamp,
            message: { conversation: 'Hello' }
          }
          params = {
            webhookVerifyToken: webhook_verify_token,
            event: 'messages.upsert',
            data: { type: 'notify', messages: [raw_message] }
          }

          expect do
            Whatsapp::IncomingMessageBaileysService.new(inbox: inbox, params: params).perform
          end.not_to raise_error

          expect(contact_inbox.reload.source_id).to eq(source_id)
          expect(contact.reload.identifier).to eq(identifier)
          expect(contact.phone_number).to eq("+#{phone}")
        end
      end
    end
  end
end
