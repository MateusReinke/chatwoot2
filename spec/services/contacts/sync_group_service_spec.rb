require 'rails_helper'

RSpec.describe Contacts::SyncGroupService do
  describe '#perform' do
    it 'raises BadRequest when contact is not a group' do
      contact = create(:contact, group_type: :individual, identifier: 'group@g.us')

      expect { described_class.new(contact: contact).perform }.to raise_error(ActionController::BadRequest)
    end

    it 'raises BadRequest when contact has no identifier' do
      contact = create(:contact, group_type: :group, identifier: nil)

      expect { described_class.new(contact: contact).perform }.to raise_error(ActionController::BadRequest)
    end

    it 'calls sync_group on open and pending conversations only' do
      contact = create(:contact, group_type: :group, identifier: 'group@g.us')
      open_conv = instance_double(Conversation)
      pending_conv = instance_double(Conversation)
      allow(open_conv).to receive(:sync_group)
      allow(pending_conv).to receive(:sync_group)

      scope = instance_double(ActiveRecord::Relation)
      allow(scope).to receive(:find_each).and_yield(open_conv).and_yield(pending_conv)

      conversations = instance_double(ActiveRecord::Associations::CollectionProxy)
      allow(conversations).to receive(:where).with(status: %i[open pending]).and_return(scope)
      allow(contact).to receive(:conversations).and_return(conversations)
      allow(contact).to receive(:reload).and_return(contact)

      described_class.new(contact: contact).perform

      expect(open_conv).to have_received(:sync_group)
      expect(pending_conv).to have_received(:sync_group)
    end

    it 'dispatches contact_group_synced event' do
      contact = create(:contact, group_type: :group, identifier: 'group@g.us')

      expect(Rails.configuration.dispatcher).to receive(:dispatch)
        .with(Events::Types::CONTACT_GROUP_SYNCED, anything, contact: contact)

      described_class.new(contact: contact).perform
    end
  end
end
