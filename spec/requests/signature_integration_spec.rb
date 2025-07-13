require 'rails_helper'

RSpec.describe 'Signature Integration', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:auth_headers) { agent.create_new_auth_token }

  describe 'Dual API call workflow' do
    context 'when updating signature content and UI settings' do
      it 'successfully updates profile with new signature' do
        put '/api/v1/profile',
            params: { profile: { message_signature: 'New signature content' } },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:success)
        profile_response = response.parsed_body
        expect(profile_response['message_signature']).to eq('New signature content')

        agent.reload
        expect(agent.message_signature).to eq('New signature content')
      end

      it 'successfully updates ui_settings with position and separator' do
        put '/api/v1/profile',
            params: { profile: { ui_settings: { signature_position: 'bottom', signature_separator: '--' } } },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:success)
        ui_response = response.parsed_body
        expect(ui_response['ui_settings']['signature_position']).to eq('bottom')
        expect(ui_response['ui_settings']['signature_separator']).to eq('--')

        agent.reload
        expect(agent.ui_settings['signature_position']).to eq('bottom')
        expect(agent.ui_settings['signature_separator']).to eq('--')
      end

      it 'handles partial failure gracefully when profile update fails' do
        # Simulate profile update failure by using invalid data
        put '/api/v1/profile',
            params: { profile: { message_signature: 'x' * 1001 } }, # Assuming there's a length limit
            headers: auth_headers,
            as: :json

        # Even if profile fails, UI settings should still work
        put '/api/v1/profile',
            params: { profile: { ui_settings: { signature_position: 'bottom' } } },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:success)
        ui_response = response.parsed_body
        expect(ui_response['ui_settings']['signature_position']).to eq('bottom')

        agent.reload
        expect(agent.ui_settings['signature_position']).to eq('bottom')
      end

      it 'preserves existing ui_settings when updating signature position/separator' do
        # Set initial ui_settings
        agent.update!(ui_settings: {
                        is_contact_sidebar_open: true,
                        theme: 'dark',
                        signature_position: 'top',
                        signature_separator: 'blank'
                      })

        # Update only signature-related settings
        put '/api/v1/profile',
            params: { profile: { ui_settings: { signature_position: 'bottom', signature_separator: '--' } } },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:success)
        agent.reload

        # Verify signature settings updated
        expect(agent.ui_settings['signature_position']).to eq('bottom')
        expect(agent.ui_settings['signature_separator']).to eq('--')

        # Verify other settings preserved
        expect(agent.ui_settings['is_contact_sidebar_open']).to be(true)
        expect(agent.ui_settings['theme']).to eq('dark')
      end
    end

    context 'when using User model signature methods' do
      it 'returns correct signature settings with defaults' do
        agent.update!(ui_settings: { signature_position: 'bottom', signature_separator: '--' })

        expect(agent.signature_position).to eq('bottom')
        expect(agent.signature_separator).to eq('--')
        expect(agent.signature_settings_with_defaults).to eq({
                                                               'position' => 'bottom',
                                                               'separator' => '--'
                                                             })
      end

      it 'returns default values when ui_settings is nil' do
        agent.update!(ui_settings: nil)

        expect(agent.signature_position).to eq('top')
        expect(agent.signature_separator).to eq('blank')
        expect(agent.signature_settings_with_defaults).to eq({
                                                               'position' => 'top',
                                                               'separator' => 'blank'
                                                             })
      end

      it 'returns mixed default and stored values' do
        agent.update!(ui_settings: { signature_position: 'bottom' })

        expect(agent.signature_position).to eq('bottom')
        expect(agent.signature_separator).to eq('blank') # default
        expect(agent.signature_settings_with_defaults).to eq({
                                                               'position' => 'bottom',
                                                               'separator' => 'blank'
                                                             })
      end
    end

    context 'when handling concurrent updates' do
      it 'handles rapid successive updates correctly' do
        # Simulate rapid updates that might happen in the UI
        3.times do |i|
          put '/api/v1/profile',
              params: { profile: { message_signature: "Signature #{i}" } },
              headers: auth_headers,
              as: :json
          expect(response).to have_http_status(:success)

          put '/api/v1/profile',
              params: { profile: { ui_settings: { signature_position: i.even? ? 'top' : 'bottom' } } },
              headers: auth_headers,
              as: :json
          expect(response).to have_http_status(:success)
        end

        agent.reload
        expect(agent.message_signature).to eq('Signature 2')
        expect(agent.ui_settings['signature_position']).to eq('top')
      end
    end

    context 'when checking authentication and authorization' do
      it 'requires authentication for both API calls' do
        put '/api/v1/profile',
            params: { profile: { message_signature: 'Test' } },
            as: :json

        expect(response).to have_http_status(:unauthorized)

        put '/api/v1/profile',
            params: { profile: { ui_settings: { signature_position: 'bottom' } } },
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'allows agents to update their own signature settings' do
        put '/api/v1/profile',
            params: { profile: { message_signature: 'Agent signature' } },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:success)

        put '/api/v1/profile',
            params: { profile: { ui_settings: { signature_position: 'bottom' } } },
            headers: auth_headers,
            as: :json

        expect(response).to have_http_status(:success)
      end
    end
  end
end
