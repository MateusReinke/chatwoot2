import { mount } from '@vue/test-utils';
import { describe, it, expect } from 'vitest';
import MessageSignature from '../MessageSignature.vue';

describe('MessageSignature.vue', () => {
  const defaultProps = {
    signature: 'Best regards\nJohn Doe',
    signaturePosition: 'top',
    signatureSeparator: 'blank',
  };

  const createWrapper = (props = {}) => {
    return mount(MessageSignature, {
      props: { ...defaultProps, ...props },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });
  };

  describe('component rendering', () => {
    it('renders signature textarea with correct value', () => {
      const wrapper = createWrapper();
      const textarea = wrapper.find('textarea');
      expect(textarea.element.value).toBe('Best regards\nJohn Doe');
    });

    it('renders position toggle with correct initial state', () => {
      const wrapper = createWrapper({ signaturePosition: 'bottom' });
      const toggle = wrapper.find('[data-testid="position-toggle"]');
      expect(toggle.exists()).toBe(true);
    });

    it('renders separator dropdown with correct initial value', () => {
      const wrapper = createWrapper({ signatureSeparator: '--' });
      const dropdown = wrapper.find('select');
      expect(dropdown.element.value).toBe('--');
    });
  });

  describe('user interactions', () => {
    it('emits updateSignature when signature text changes', async () => {
      const wrapper = createWrapper();
      const textarea = wrapper.find('textarea');

      await textarea.setValue('New signature content');

      expect(wrapper.emitted('updateSignature')).toBeTruthy();
      const emittedEvent = wrapper.emitted('updateSignature')[0];
      expect(emittedEvent[0]).toBe('New signature content');
      expect(emittedEvent[1]).toBe('top');
      expect(emittedEvent[2]).toBe('blank');
    });

    it('emits updateSignature when position toggle changes', async () => {
      const wrapper = createWrapper();
      const toggle = wrapper.find('[data-testid="position-toggle"]');

      await toggle.trigger('change');

      expect(wrapper.emitted('updateSignature')).toBeTruthy();
      const emittedEvent = wrapper.emitted('updateSignature')[0];
      expect(emittedEvent[0]).toBe('Best regards\nJohn Doe');
      expect(emittedEvent[2]).toBe('blank');
    });

    it('emits updateSignature when separator dropdown changes', async () => {
      const wrapper = createWrapper();
      const dropdown = wrapper.find('select');

      await dropdown.setValue('--');

      expect(wrapper.emitted('updateSignature')).toBeTruthy();
      const emittedEvent = wrapper.emitted('updateSignature')[0];
      expect(emittedEvent[0]).toBe('Best regards\nJohn Doe');
      expect(emittedEvent[1]).toBe('top');
      expect(emittedEvent[2]).toBe('--');
    });
  });

  describe('prop reactivity', () => {
    it('updates textarea when signature prop changes', async () => {
      const wrapper = createWrapper();

      await wrapper.setProps({ signature: 'Updated signature' });

      const textarea = wrapper.find('textarea');
      expect(textarea.element.value).toBe('Updated signature');
    });

    it('updates position toggle when signaturePosition prop changes', async () => {
      const wrapper = createWrapper({ signaturePosition: 'top' });

      await wrapper.setProps({ signaturePosition: 'bottom' });

      const toggle = wrapper.find('[data-testid="position-toggle"]');
      expect(toggle.element.checked).toBe(true);
    });

    it('updates separator dropdown when signatureSeparator prop changes', async () => {
      const wrapper = createWrapper({ signatureSeparator: 'blank' });

      await wrapper.setProps({ signatureSeparator: '--' });

      const dropdown = wrapper.find('select');
      expect(dropdown.element.value).toBe('--');
    });
  });

  describe('event emission with all parameters', () => {
    it('always emits all three parameters (signature, position, separator)', async () => {
      const wrapper = createWrapper();
      const textarea = wrapper.find('textarea');

      await textarea.setValue('Test signature');

      const emittedEvent = wrapper.emitted('updateSignature')[0];
      expect(emittedEvent).toHaveLength(3);
      expect(typeof emittedEvent[0]).toBe('string');
      expect(typeof emittedEvent[1]).toBe('string');
      expect(typeof emittedEvent[2]).toBe('string');
    });

    it('maintains correct parameter order in emissions', async () => {
      const wrapper = createWrapper({
        signature: 'Test',
        signaturePosition: 'bottom',
        signatureSeparator: '--',
      });

      const textarea = wrapper.find('textarea');
      await textarea.setValue('Modified test');

      const emittedEvent = wrapper.emitted('updateSignature')[0];
      expect(emittedEvent[0]).toBe('Modified test');
      expect(emittedEvent[1]).toBe('bottom');
      expect(emittedEvent[2]).toBe('--');
    });
  });
});
