import { mount } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import Index from '../Index.vue';
import ProfileAPI from 'dashboard/api/profile';
import AuthAPI from 'dashboard/api/auth';

vi.mock('dashboard/api/profile', () => ({
  default: {
    update: vi.fn(),
  },
}));

vi.mock('dashboard/api/auth', () => ({
  default: {
    updateUISettings: vi.fn(),
  },
}));

describe('Index.vue', () => {
  let wrapper;
  let mockProfileAPI;
  let mockAuthAPI;

  beforeEach(() => {
    vi.clearAllMocks();

    mockProfileAPI = ProfileAPI;
    mockAuthAPI = AuthAPI;

    mockProfileAPI.update.mockResolvedValue({
      data: { message_signature: 'Updated signature' },
    });
    mockAuthAPI.updateUISettings.mockResolvedValue({
      data: { ui_settings: {} },
    });

    const mockUser = {
      message_signature: 'Original signature',
      ui_settings: {
        signature_position: 'top',
        signature_separator: 'blank',
      },
    };

    wrapper = mount(Index, {
      global: {
        mocks: {
          $t: key => key,
          $store: {
            getters: {
              getCurrentUser: mockUser,
            },
            dispatch: vi.fn(),
          },
        },
      },
    });
  });

  describe('updateSignature method', () => {
    it('calls both updateProfile and updateUISettings APIs', async () => {
      await wrapper.vm.updateSignature('New signature', 'bottom', '--');

      expect(mockProfileAPI.update).toHaveBeenCalledWith({
        profile: { message_signature: 'New signature' },
      });

      expect(mockAuthAPI.updateUISettings).toHaveBeenCalledWith({
        uiSettings: {
          signature_position: 'bottom',
          signature_separator: '--',
        },
      });
    });

    it('calls APIs in the correct order (profile first, then ui_settings)', async () => {
      const callOrder = [];

      mockProfileAPI.update.mockImplementation(() => {
        callOrder.push('profile');
        return Promise.resolve({ data: {} });
      });

      mockAuthAPI.updateUISettings.mockImplementation(() => {
        callOrder.push('ui_settings');
        return Promise.resolve({ data: {} });
      });

      await wrapper.vm.updateSignature('Test', 'top', 'blank');

      expect(callOrder).toEqual(['profile', 'ui_settings']);
    });

    it('handles successful dual API calls', async () => {
      const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});

      await wrapper.vm.updateSignature('Success test', 'bottom', '--');

      expect(mockProfileAPI.update).toHaveBeenCalled();
      expect(mockAuthAPI.updateUISettings).toHaveBeenCalled();

      consoleSpy.mockRestore();
    });
  });

  describe('error handling', () => {
    it('handles profile API failure gracefully', async () => {
      mockProfileAPI.update.mockRejectedValue(new Error('Profile API failed'));
      const consoleSpy = vi
        .spyOn(console, 'error')
        .mockImplementation(() => {});

      await wrapper.vm.updateSignature('Test', 'top', 'blank');

      expect(mockProfileAPI.update).toHaveBeenCalled();
      expect(consoleSpy).toHaveBeenCalledWith(
        'Error updating profile:',
        expect.any(Error)
      );

      consoleSpy.mockRestore();
    });

    it('handles ui_settings API failure gracefully', async () => {
      mockAuthAPI.updateUISettings.mockRejectedValue(
        new Error('UI Settings API failed')
      );
      const consoleSpy = vi
        .spyOn(console, 'error')
        .mockImplementation(() => {});

      await wrapper.vm.updateSignature('Test', 'top', 'blank');

      expect(mockAuthAPI.updateUISettings).toHaveBeenCalled();
      expect(consoleSpy).toHaveBeenCalledWith(
        'Error updating UI settings:',
        expect.any(Error)
      );

      consoleSpy.mockRestore();
    });

    it('continues with ui_settings call even if profile call fails', async () => {
      mockProfileAPI.update.mockRejectedValue(new Error('Profile failed'));
      const consoleSpy = vi
        .spyOn(console, 'error')
        .mockImplementation(() => {});

      await wrapper.vm.updateSignature('Test', 'bottom', '--');

      expect(mockProfileAPI.update).toHaveBeenCalled();
      expect(mockAuthAPI.updateUISettings).toHaveBeenCalled();

      consoleSpy.mockRestore();
    });

    it('handles both API calls failing', async () => {
      mockProfileAPI.update.mockRejectedValue(new Error('Profile failed'));
      mockAuthAPI.updateUISettings.mockRejectedValue(
        new Error('UI Settings failed')
      );
      const consoleSpy = vi
        .spyOn(console, 'error')
        .mockImplementation(() => {});

      await wrapper.vm.updateSignature('Test', 'top', 'blank');

      expect(consoleSpy).toHaveBeenCalledTimes(2);
      expect(consoleSpy).toHaveBeenCalledWith(
        'Error updating profile:',
        expect.any(Error)
      );
      expect(consoleSpy).toHaveBeenCalledWith(
        'Error updating UI settings:',
        expect.any(Error)
      );

      consoleSpy.mockRestore();
    });
  });

  describe('parameter handling', () => {
    it('handles all signature parameters correctly', async () => {
      await wrapper.vm.updateSignature('Custom signature', 'bottom', '--');

      expect(mockProfileAPI.update).toHaveBeenCalledWith({
        profile: { message_signature: 'Custom signature' },
      });

      expect(mockAuthAPI.updateUISettings).toHaveBeenCalledWith({
        uiSettings: {
          signature_position: 'bottom',
          signature_separator: '--',
        },
      });
    });

    it('handles empty signature correctly', async () => {
      await wrapper.vm.updateSignature('', 'top', 'blank');

      expect(mockProfileAPI.update).toHaveBeenCalledWith({
        profile: { message_signature: '' },
      });
    });

    it('handles different separator options', async () => {
      await wrapper.vm.updateSignature('Test', 'top', '---');

      expect(mockAuthAPI.updateUISettings).toHaveBeenCalledWith({
        uiSettings: {
          signature_position: 'top',
          signature_separator: '---',
        },
      });
    });
  });
});
