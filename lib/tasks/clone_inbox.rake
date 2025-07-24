# frozen_string_literal: true

namespace :inbox do # rubocop:disable Metrics/BlockLength
  desc 'Clone all messages from a source inbox to a destination inbox'
  task :clone_messages, %i[source_inbox_id destination_inbox_id] => :environment do |_task, args| # rubocop:disable Metrics/BlockLength
    source_inbox_id = args[:source_inbox_id]
    destination_inbox_id = args[:destination_inbox_id]

    if source_inbox_id.blank? || destination_inbox_id.blank?
      puts 'Usage: rails inbox:clone_messages[<source_inbox_id>,<destination_inbox_id>]'
      next
    end

    source_inbox = Inbox.find_by(id: source_inbox_id)
    destination_inbox = Inbox.find_by(id: destination_inbox_id)

    unless source_inbox
      puts "Error: Source inbox with ID #{source_inbox_id} not found."
      next
    end

    unless destination_inbox
      puts "Error: Destination inbox with ID #{destination_inbox_id} not found."
      next
    end

    puts "Cloning messages from '#{source_inbox.name}' (ID: #{source_inbox.id}) to '#{destination_inbox.name}' (ID: #{destination_inbox.id})..."

    # Clone contact_inboxes and map old IDs to new ones
    old_to_new_contact_inbox = {}
    source_inbox.contact_inboxes.find_each do |ci|
      new_ci = ContactInboxWithContactBuilder.new(
        source_id: ci.source_id,
        inbox: destination_inbox,
        contact_attributes: { name: ci.contact.name, phone_number: ci.contact.phone_number }
      ).perform
      old_to_new_contact_inbox[ci.id] = new_ci.id
    end

    # Clone conversations and related data
    old_to_new_conversation = {}
    source_inbox.conversations.find_each do |conv|
      new_conv = destination_inbox.conversations.create!(
        account_id: destination_inbox.account_id,
        contact_id: conv.contact_id,
        contact_inbox_id: old_to_new_contact_inbox[conv.contact_inbox_id],
        assignee_id: conv.assignee_id,
        team_id: conv.team_id,
        campaign_id: conv.campaign_id,
        status: conv.status,
        priority: conv.priority,
        snoozed_until: conv.snoozed_until,
        waiting_since: conv.waiting_since,
        last_activity_at: conv.last_activity_at,
        additional_attributes: conv.additional_attributes,
        custom_attributes: conv.custom_attributes
      )
      old_to_new_conversation[conv.id] = new_conv.id

      # Clone participants
      conv.conversation_participants.find_each do |cp|
        new_conv.conversation_participants.create!(
          user_id: cp.user_id,
          account_id: new_conv.account_id
        )
      end

      # Clone CSAT survey response if present
      if (resp = conv.csat_survey_response)
        new_conv.create_csat_survey_response!(resp.attributes.except('id', 'conversation_id', 'created_at', 'updated_at'))
      end
    end

    cloned_messages_count = 0
    failed_messages_count = 0

    source_inbox.messages.find_each do |original_message|
      # Map to newly cloned conversation ID
      new_conv_id = old_to_new_conversation[original_message.conversation_id]
      new_message = destination_inbox.messages.new(
        account_id: destination_inbox.account_id,
        conversation_id: new_conv_id,
        message_type: original_message.message_type,
        content: original_message.content,
        private: original_message.private,
        content_type: original_message.content_type,
        content_attributes: original_message.content_attributes,
        sender_id: original_message.sender_id,
        sender_type: original_message.sender_type,
        external_source_ids: original_message.external_source_ids,
        source_id: original_message.source_id
      )

      if new_message.save
        cloned_messages_count += 1
        # Clone attachments if any
        original_message.attachments.each do |attachment|
          new_message.attachments.create(
            file_type: attachment.file_type,
            account_id: destination_inbox.account_id,
            file: attachment.file.blob
          )
        end
      else
        failed_messages_count += 1
        puts "Failed to clone message ID: #{original_message.id}. Errors: #{new_message.errors.full_messages.join(', ')}"
      end
      print "Cloned: #{cloned_messages_count} | Failed: #{failed_messages_count}\r"
    end

    puts "\nCloning complete."
    puts "Successfully cloned #{cloned_messages_count} messages."
    puts "Failed to clone #{failed_messages_count} messages."
  end
end
