json.payload do
  json.partial! 'api/v1/models/contact', formats: [:json], resource: @contact, with_contact_inboxes: true

  json.group_members do
    json.array!(@group_members) do |member|
      json.id member.id
      json.role member.role
      json.is_active member.is_active
      json.contact do
        json.id member.contact.id
        json.name member.contact.name
        json.phone_number member.contact.phone_number
        json.identifier member.contact.identifier
      end
    end
  end
end
