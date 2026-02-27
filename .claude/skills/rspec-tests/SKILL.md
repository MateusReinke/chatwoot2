---
name: rspec-tests
description: Guidelines for writing RSpec tests in this Rails project. Covers test structure, conventions, anti-patterns, and project-specific tooling. Use when creating or reviewing Ruby specs.
---

# RSpec Testing Skill

## Core Principles

### 1. Test Each Behavior Exactly Once

Every spec should verify one expected behavior. Do not write multiple specs that assert the same thing in different ways. Redundant specs slow the suite and add maintenance burden without extra confidence.

### 2. Avoid `before(:each)`

Prefer `let`, `let!`, `let_it_be`, `before_all`, or inline setup inside the `it` block. Only use `before(:each)` when there is truly no alternative (e.g., stateful mutation needed before every example in a tightly scoped context). When a `before` block is unavoidable, keep it as close to the examples that need it as possible.

### 3. Follow Set → Action → Expect Ordering

Structure every test with three clearly separated stages, each divided by a blank line:

- **Set** (Setup): Build the context — `let`, `let_it_be`, `create`, variable assignment.
- **Action**: Execute the behavior under test — call the method, make the request, trigger the job.
- **Expect**: Assert the outcome — `expect(...)`.

Only break this order when the assertion must come before the action (e.g., `expect { action }.to change(...)`).

```ruby
it 'assigns the conversation to the agent' do
  agent = create(:user, account: account)

  service.perform

  expect(conversation.reload.assignee).to eq(agent)
end
```

### 4. Never Assert on Translated Strings

Translations vary by locale. Instead of matching user-facing text like `'enviado'` or `'sent'`, assert on the underlying status, enum value, or state change that produces that text.

```ruby
# Bad
expect(message.status_text).to eq('sent')

# Good
expect(message.status).to eq('sent')
expect(message).to be_sent
```

---

## Project Conventions

### Stubs and Mocks

- Stub with `allow(object).to receive(:method).and_return(value)`.
- Verify calls with `have_received(:method)` (message spies style is acceptable — `RSpec/MessageSpies` is disabled).
- For ENV variables, use the `with_modified_env` helper instead of stubbing `ENV` directly.

### Assertions

- Use Shoulda matchers for model validations and associations as one-liners:
  ```ruby
  it { is_expected.to belong_to(:account) }
  it { is_expected.to validate_presence_of(:name) }
  ```
- For HTTP responses: `expect(response).to have_http_status(:success)`.
- For error classes in parallel/reloading environments, compare `error.class.name` (string) instead of the constant directly.

### Style

- **Hash syntax**: Use explicit `key: value`. Do not use Ruby 3.1 shorthand (`{key:}`).
- **Module/class style**: Use compact definitions (`class Foo::Bar`) — never nested.
- **Describe/context naming**: `describe '#method_name'` for instance methods, `describe '.method_name'` for class methods, `context 'when condition'` for scenarios.

---

## Structure Examples

### Service Spec

```ruby
require 'rails_helper'

RSpec.describe MyService do
  subject(:service) { described_class.new(account: account) }

  let_it_be(:account) { create(:account) }

  describe '#perform' do
    context 'when the input is valid' do
      let(:params) { { name: 'Test' } }

      it 'creates the resource' do
        result = service.perform(params)

        expect(result).to be_persisted
        expect(result.name).to eq('Test')
      end
    end

    context 'when the input is invalid' do
      let(:params) { { name: '' } }

      it 'raises a validation error' do
        expect { service.perform(params) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
```

### Request Spec

```ruby
require 'rails_helper'

RSpec.describe 'Widgets API', type: :request do
  let_it_be(:account) { create(:account) }
  let_it_be(:agent) { create(:user, account: account, role: :agent) }

  describe 'POST /api/v1/accounts/{account.id}/widgets' do
    context 'when authenticated' do
      it 'creates a widget' do
        params = { name: 'Support', website_url: 'https://example.com' }

        post "/api/v1/accounts/#{account.id}/widgets",
             headers: { api_access_token: agent.access_token.token },
             params: params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)['name']).to eq('Support')
      end
    end
  end
end
```
