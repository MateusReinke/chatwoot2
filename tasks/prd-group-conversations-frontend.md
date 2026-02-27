# PRD: Group Conversations — Full Feature

## Introduction

Chatwoot already supports group conversations on the backend (models, API endpoints, Baileys provider integration). Group contacts (`group_type: :group`), group conversations (`conversation.group_type: :group`), and group members (`ConversationGroupMember`) are all stored and managed.

This PRD covers the **full frontend implementation** and **backend expansions** needed to support groups end-to-end: API serialization, sidebar UI, filtering, group management (create, edit metadata, members, invite links), group message bubbles, and an `@mention` system for group conversations.

### Key Backend Context

| Concept | Backend Implementation |
|---|---|
| **Group contact** | `Contact` with `group_type: :group` |
| **Group conversation** | `Conversation` with `group_type: :group` (column to be renamed from `conversation_type`) |
| **Group member** | `ConversationGroupMember` (join table: conversation ↔ contact, with `role` and `is_active`) |
| **Sync group** | `POST /api/v1/accounts/:account_id/contacts/:id/sync_group` — fetches latest group metadata from provider |
| **List members** | `GET /api/v1/accounts/:account_id/contacts/:contact_id/group_members` — returns active members |

**Important naming note:** The frontend already uses `conversationType` as a **routing concept** (values: `''`, `'mention'`, `'participating'`, `'unattended'`). The DB column on `conversations` will be renamed from `conversation_type` to `group_type` to avoid this collision. In the frontend, use `groupType` consistently for the model field.

### Baileys Provider API Reference

When implementing provider-level routes for groups, consult the Baileys SDK type definitions at `tasks/references/baileys.d.ts`. Key functions:

| Baileys Function | Purpose |
|---|---|
| `groupCreate(subject, participants)` | Create a new group |
| `groupMetadata(jid)` | Fetch group metadata (name, desc, participants) |
| `groupUpdateSubject(jid, subject)` | Update group name |
| `groupUpdateDescription(jid, description?)` | Update group description |
| `groupParticipantsUpdate(jid, participants, action)` | Add/remove/promote/demote participants |
| `groupInviteCode(jid)` | Get invite link code |
| `groupRevokeInvite(jid)` | Revoke and regenerate invite link |
| `groupAcceptInvite(code)` | Accept an invite code |
| `groupSettingUpdate(jid, setting)` | Toggle announcement/locked settings |
| `groupMemberAddMode(jid, mode)` | Set who can add members (admin_add / all_member_add) |
| `groupJoinApprovalMode(jid, mode)` | Toggle join approval (on/off) |
| `groupRequestParticipantsList(jid)` | List pending join requests |
| `groupRequestParticipantsUpdate(jid, participants, action)` | Approve/reject join requests |

## Goals

- Rename `conversation_type` column to `group_type` on the `conversations` table to avoid frontend naming conflicts
- Expose `group_type` in both conversation and contact API JSON responses
- Allow agents to filter conversations by type (all/individual/group) in basic and advanced filters
- Replace `ContactInfo` with a dedicated `GroupContactInfo` component for group conversations in the sidebar (keep `contact_notes` and `contact_attributes` sections)
- Allow agents to **create groups**, **add/remove members**, **promote/demote admins**, **approve join requests via invite link**
- Allow agents to **edit group metadata** (name, description, avatar) via new backend routes proxying to Baileys
- Generate and manage **group invite links**
- Render **group-specific message bubbles** with colored sender names and sender avatars
- Implement **@mentions in group conversations** (inspired by the existing private note mention system)
- Handle real-time group updates via ActionCable

## User Stories

### US-001: Rename conversation_type to group_type (Backend Refactor)
**Description:** As a developer, I need to rename the `conversation_type` column on `conversations` to `group_type` to avoid naming conflicts with the frontend's routing `conversationType` concept.

**Acceptance Criteria:**
- [ ] New migration renames column `conversation_type` to `group_type` on the `conversations` table
- [ ] `Conversation` model enum updated: `enum group_type: { individual: 0, group: 1 }`
- [ ] All backend references updated (model, concerns, services, controllers, specs, serializers, handlers)
- [ ] Frontend references to `conversation_type` (routing concept) remain untouched
- [ ] All existing specs pass
- [ ] Typecheck/lint passes

---

### US-002: Serialize group fields in API responses
**Description:** As a frontend consumer, I need `group_type` in both conversation and contact JSON so the UI can identify group conversations and contacts.

**Acceptance Criteria:**
- [ ] `group_type` field added to `app/views/api/v1/conversations/partials/_conversation.json.jbuilder` (outputs `'individual'` or `'group'`)
- [ ] `group_type` field added to `app/views/api/v1/models/_contact.json.jbuilder` (outputs `'individual'` or `'group'`)
- [ ] Existing API responses for conversations and contacts include the new fields
- [ ] No regressions in existing conversation/contact endpoints
- [ ] Typecheck/lint passes

---

### US-003: Create frontend API clients for group endpoints
**Description:** As a developer, I need API client methods for group-related endpoints so Vue components can call backend group APIs.

**Acceptance Criteria:**
- [ ] New file `app/javascript/dashboard/api/groupMembers.js` with methods:
  - `getGroupMembers(accountId, contactId)` → `GET /api/v1/accounts/:account_id/contacts/:contact_id/group_members`
  - `syncGroup(accountId, contactId)` → `POST /api/v1/accounts/:account_id/contacts/:id/sync_group`
  - `createGroup(accountId, params)` → `POST /api/v1/accounts/:account_id/groups` (new endpoint, see US-010)
  - `updateGroupMetadata(accountId, contactId, params)` → `PATCH /api/v1/accounts/:account_id/contacts/:id/group_metadata` (see US-012)
  - `addMembers(accountId, contactId, memberIds)` → `POST /api/v1/accounts/:account_id/contacts/:id/group_members`
  - `removeMembers(accountId, contactId, memberIds)` → `DELETE /api/v1/accounts/:account_id/contacts/:id/group_members`
  - `updateMemberRole(accountId, contactId, memberId, role)` → `PATCH /api/v1/accounts/:account_id/contacts/:id/group_members/:member_id`
  - `getInviteLink(accountId, contactId)` → `GET /api/v1/accounts/:account_id/contacts/:id/group_invite`
  - `revokeInviteLink(accountId, contactId)` → `POST /api/v1/accounts/:account_id/contacts/:id/group_invite/revoke`
  - `getPendingRequests(accountId, contactId)` → `GET /api/v1/accounts/:account_id/contacts/:id/group_join_requests`
  - `handleJoinRequest(accountId, contactId, params)` → `POST /api/v1/accounts/:account_id/contacts/:id/group_join_requests/handle`
- [ ] API methods follow existing `ApiClient` patterns used in the codebase
- [ ] Typecheck/lint passes

---

### US-004: Create group members Vuex store module
**Description:** As a developer, I need a Vuex store module to manage group member state (fetch, cache, sync, add, remove) so components can reactively access group data.

**Acceptance Criteria:**
- [ ] New store module at `app/javascript/dashboard/store/modules/groupMembers.js`
- [ ] State: `records` (keyed by contactId → array of members), `uiFlags` (isFetching, isSyncing, isUpdating)
- [ ] Getters: `getGroupMembers(contactId)`, `getUIFlags`
- [ ] Actions: `fetch({ contactId })`, `sync({ contactId })` (calls sync_group, then re-fetches members), `addMembers(...)`, `removeMembers(...)`, `updateMemberRole(...)`
- [ ] Mutations: `SET_GROUP_MEMBERS`, `SET_UI_FLAG`
- [ ] Module registered in the global store (`app/javascript/dashboard/store/index.js`)
- [ ] Typecheck/lint passes

---

### US-005: Add i18n keys for group features
**Description:** As a developer, I need English and pt-BR i18n keys for all group-related UI text.

**Acceptance Criteria:**
- [ ] Keys added to `app/javascript/dashboard/i18n/locale/en/` JSON files
- [ ] Keys cover: group members section title, admin role badge, sync button label, sync success/error messages, empty state, filter labels (type: all/individual/group), group info header, create group labels, edit metadata labels, invite link labels, member management labels, mention UI labels, join request labels
- [ ] pt-BR translations added for all new keys
- [ ] Typecheck/lint passes

---

### US-006: Add group_type filter to ConversationBasicFilter
**Description:** As an agent, I want to filter the conversation list by type (all/individual/group) in the basic filter dropdown.

**Acceptance Criteria:**
- [ ] New "Type" section in `ConversationBasicFilter.vue` dropdown (alongside existing Status and Sort Order sections)
- [ ] Options: "All" (default), "Individual", "Group"
- [ ] Selected filter is persisted in UI settings (`conversations_filter_by.group_type`)
- [ ] Filter value is passed to the conversation list API call and correctly filters results
- [ ] Backend handles the new `group_type` query parameter in the conversations index endpoint to filter by `group_type` column
- [ ] Typecheck/lint passes

---

### US-007: Add group_type to advanced filter system
**Description:** As an agent, I want to filter conversations by type in the advanced filter for complex filter rules.

**Acceptance Criteria:**
- [ ] New filter attribute `group_type` added to `advancedFilterItems/index.js` with `inputType: 'multi_select'` and operators `equal_to`, `not_equal_to`
- [ ] Added to `filterAttributeGroups` under "Standard Filters"
- [ ] i18n key for the filter attribute added
- [ ] Filter options provided: `individual`, `group` (with i18n labels)
- [ ] Backend: `group_type` added to `lib/filters/filter_keys.yml` under `conversations:` with `attribute_type: "standard"`, `data_type: "text"`, operators `equal_to`/`not_equal_to`
- [ ] Advanced filter correctly returns only matching conversations
- [ ] Typecheck/lint passes

---

### US-008: Create GroupContactInfo component
**Description:** As an agent, I want to see group-specific info (group name, member count, member list with roles, sync button) in the right sidebar when viewing a group conversation.

**Acceptance Criteria:**
- [ ] New component `app/javascript/dashboard/routes/dashboard/conversation/contact/GroupContactInfo.vue` using `<script setup>` and Composition API
- [ ] Displays: group avatar, group name, active member count
- [ ] Lists all active group members with: thumbnail/avatar, name; admin badge only (members have no badge)
- [ ] "Sync group" button that dispatches `groupMembers/sync` action, shows spinner during sync, and shows success/error alert
- [ ] Skeleton loading placeholders while fetching members
- [ ] Uses Tailwind utility classes only (no custom/scoped CSS)
- [ ] Fetches group members on mount via `groupMembers/fetch` action
- [ ] Only shows active members (not inactive/removed)
- [ ] Member count displayed prominently
- [ ] Typecheck/lint passes

---

### US-009: Integrate GroupContactInfo in ContactPanel
**Description:** As a system, I need to conditionally render `GroupContactInfo` instead of `ContactInfo` in the sidebar when viewing a group conversation.

**Acceptance Criteria:**
- [ ] `ContactPanel.vue` imports `GroupContactInfo`
- [ ] When `currentChat.group_type === 'group'`, renders `GroupContactInfo` instead of `ContactInfo`
- [ ] When conversation is individual (or no type), renders existing `ContactInfo` (no regression)
- [ ] Sidebar title changes to group-appropriate text (e.g., "Group" instead of "Contact") for group conversations
- [ ] Keeps `contact_notes` and `contact_attributes` sections visible for group conversations
- [ ] Typecheck/lint passes

---

### US-010: Backend — Group creation endpoint
**Description:** As an agent, I want to create a new WhatsApp group from the Chatwoot UI so I can start group conversations directly.

**Acceptance Criteria:**
- [ ] New controller action: `POST /api/v1/accounts/:account_id/groups` accepting `{ inbox_id, subject, participants: [phone_numbers] }`
- [ ] Service delegates to the channel provider (e.g., `WhatsappBaileysService`) which calls Baileys `groupCreate(subject, participants)`
- [ ] On success: creates `Contact` (group_type: group), `ContactInbox`, `Conversation` (group_type: group), and `ConversationGroupMember` records for all participants
- [ ] Returns the created conversation with group metadata
- [ ] Proper authorization (agent must have access to the inbox)
- [ ] Specs for controller and service
- [ ] Typecheck/lint passes

---

### US-011: Backend — Add/remove members and role management
**Description:** As an agent, I want to add/remove members from a group and promote/demote admins so I can manage group composition.

**Acceptance Criteria:**
- [ ] `POST /api/v1/accounts/:account_id/contacts/:id/group_members` — add participants (accepts `{ participants: [phone_numbers] }`)
- [ ] `DELETE /api/v1/accounts/:account_id/contacts/:id/group_members` — remove participants (accepts `{ participants: [phone_numbers] }`)
- [ ] `PATCH /api/v1/accounts/:account_id/contacts/:id/group_members/:member_id` — update role (accepts `{ role: 'admin' | 'member' }`)
- [ ] Each action delegates to the channel provider which calls Baileys `groupParticipantsUpdate(jid, participants, action)` with action `add`/`remove`/`promote`/`demote`
- [ ] Backend updates `ConversationGroupMember` records accordingly (create, soft-delete via `is_active`, update role)
- [ ] Proper authorization and error handling
- [ ] Specs for controller and service
- [ ] Typecheck/lint passes

---

### US-012: Backend — Group metadata update endpoint
**Description:** As an agent, I want to edit group name, description, and avatar from the Chatwoot UI.

**Acceptance Criteria:**
- [ ] `PATCH /api/v1/accounts/:account_id/contacts/:id/group_metadata` accepting `{ subject, description }`
- [ ] Avatar upload uses the existing contact avatar update mechanism (`contacts#update` with `avatar` param), which should proxy to the provider for group contacts
- [ ] Service delegates to the channel provider calling Baileys `groupUpdateSubject`, `groupUpdateDescription`, and `updateProfilePicture` as needed
- [ ] Backend updates the `Contact` record (name, additional_attributes.description)
- [ ] Proper authorization and error handling
- [ ] Specs for controller and service
- [ ] Typecheck/lint passes

---

### US-013: Backend — Invite link management
**Description:** As an agent, I want to generate and manage a group invite link so external users can join the group.

**Acceptance Criteria:**
- [ ] `GET /api/v1/accounts/:account_id/contacts/:id/group_invite` — returns current invite code/URL (calls Baileys `groupInviteCode(jid)`)
- [ ] `POST /api/v1/accounts/:account_id/contacts/:id/group_invite/revoke` — revokes current link and generates a new one (calls Baileys `groupRevokeInvite(jid)`)
- [ ] Response includes the full invite URL
- [ ] Proper authorization (only admins should be able to manage invite links — or follow group settings)
- [ ] Specs for controller and service
- [ ] Typecheck/lint passes

---

### US-014: Backend — Join request management
**Description:** As an agent/admin, I want to see pending join requests and approve/reject them when the group has join approval mode enabled.

**Acceptance Criteria:**
- [ ] `GET /api/v1/accounts/:account_id/contacts/:id/group_join_requests` — lists pending join requests (calls Baileys `groupRequestParticipantsList(jid)`)
- [ ] `POST /api/v1/accounts/:account_id/contacts/:id/group_join_requests/handle` — approve or reject requests (accepts `{ participants: [jids], action: 'approve' | 'reject' }`, calls Baileys `groupRequestParticipantsUpdate(jid, participants, action)`)
- [ ] Proper authorization
- [ ] Specs for controller and service
- [ ] Typecheck/lint passes

---

### US-015: Frontend — Group creation UI
**Description:** As an agent, I want a UI to create a new group by selecting an inbox, entering a group name, and choosing initial participants.

**Acceptance Criteria:**
- [ ] New component/modal for group creation accessible from a relevant UI entry point (e.g., "New Group" button)
- [ ] Form fields: inbox selector (only inboxes supporting groups), group name (subject), participant selector (search contacts by phone/name)
- [ ] Calls `groupMembers/createGroup` store action on submit
- [ ] Shows success notification and navigates to the new group conversation on success
- [ ] Shows error notification on failure
- [ ] Uses `<script setup>` and Composition API, Tailwind only
- [ ] Typecheck/lint passes

---

### US-016: Frontend — Member management UI in GroupContactInfo
**Description:** As an agent, I want to add/remove members and change roles directly from the GroupContactInfo sidebar panel.

**Acceptance Criteria:**
- [ ] "Add member" button in GroupContactInfo that opens a contact search/select input
- [ ] Each member row has a context menu or action buttons: "Promote to admin" / "Demote to member" / "Remove from group"
- [ ] Actions call corresponding store actions (which call API endpoints from US-011)
- [ ] Loading states and success/error alerts for each action
- [ ] Skeleton loading for initial member list load
- [ ] Uses `<script setup>` and Composition API, Tailwind only
- [ ] Typecheck/lint passes

---

### US-017: Frontend — Group metadata editing UI
**Description:** As an agent, I want to edit the group name, description, and avatar from the sidebar.

**Acceptance Criteria:**
- [ ] Inline editable group name (click to edit, enter/blur to save)
- [ ] Editable description field (click to edit, save)
- [ ] Avatar click opens file picker for upload (uses existing contact avatar update flow, extended for group provider sync)
- [ ] Each edit calls the appropriate API endpoint (US-012)
- [ ] Loading states and success/error alerts
- [ ] Uses `<script setup>` and Composition API, Tailwind only
- [ ] Typecheck/lint passes

---

### US-018: Frontend — Invite link management UI
**Description:** As an agent, I want to view, copy, and revoke the group invite link from the sidebar.

**Acceptance Criteria:**
- [ ] "Invite Link" section in GroupContactInfo or as an accordion section
- [ ] Shows the current invite link with a "Copy" button
- [ ] "Revoke & Regenerate" button that revokes the current link and fetches a new one
- [ ] Loading states during fetch/revoke
- [ ] Uses `<script setup>` and Composition API, Tailwind only
- [ ] Typecheck/lint passes

---

### US-019: Frontend — Join request management UI
**Description:** As an agent, I want to see pending join requests and approve/reject them from the sidebar when join approval mode is enabled.

**Acceptance Criteria:**
- [ ] "Pending Requests" section in GroupContactInfo (only visible when there are pending requests)
- [ ] Lists pending requests with requester name/phone and "Approve" / "Reject" buttons
- [ ] Actions call the API endpoint from US-014
- [ ] Loading and success/error states
- [ ] Uses `<script setup>` and Composition API, Tailwind only
- [ ] Typecheck/lint passes

---

### US-020: Group message bubbles — Sender name with color
**Description:** As an agent, I want group message bubbles to display the sender's name above the message text, with a distinct color per sender, so I can easily distinguish who sent each message.

**Acceptance Criteria:**
- [ ] In group conversations, each incoming message bubble shows the sender's name above the message content
- [ ] Sender name color is deterministic and derived from the sender's name hash, using the same color palette as the `Avatar` component (6 color pairs, index = `name.length % 6`)
- [ ] Sender name is not shown for consecutive messages from the same sender (group by sender)
- [ ] Sender name is clickable/linkable to the contact profile (optional, evaluate)
- [ ] Works in `components-next/` message bubble components
- [ ] Typecheck/lint passes

---

### US-021: Group message bubbles — Sender avatar
**Description:** As an agent, I want to see the sender's avatar thumbnail next to group message bubbles so I can visually identify senders.

**Acceptance Criteria:**
- [ ] In group conversations, each incoming message shows the sender's avatar on the left side of the bubble
- [ ] Avatar uses the sender's `thumbnail` if available, otherwise shows the avatar placeholder with initials and color (matching the name color from US-020)
- [ ] Avatar is not repeated for consecutive messages from the same sender (show only on the first message of a group)
- [ ] Works in `components-next/` message bubble components
- [ ] Typecheck/lint passes

---

### US-022: @Mention system for group conversations
**Description:** As an agent, I want to @mention group members in messages so they receive a notification and can be highlighted in the conversation.

**Acceptance Criteria:**
- [ ] Typing `@` in the message editor for a **group conversation** triggers a mention suggestion dropdown (similar to the existing private note mention feature)
- [ ] The dropdown lists **group members** (contacts from the group), not agents — filtering as the user types
- [ ] Each item in the dropdown shows avatar, name, and phone number
- [ ] Selecting a mention inserts a mention node into the ProseMirror editor (format: `[@DisplayName](mention://contact/ID/EncodedName)`)
- [ ] Mention text is rendered highlighted in the message bubble
- [ ] Backend: new mention type `contact` handled in `Messages::MentionService` (currently only handles `user` and `team` types)
- [ ] Backend: when a group message contains contact mentions, the mentioned contacts can be tracked (for future notification/highlight features)
- [ ] Uses the existing mention infrastructure (ProseMirror `suggestionsPlugin`, `createNode('mention', ...)`) extended for contact mentions
- [ ] Typecheck/lint passes

---

### US-023: Handle real-time group updates via ActionCable
**Description:** As a system, when a `contact.group_synced` event is received via ActionCable, the frontend should update the group members in the store directly from the event payload.

**Acceptance Criteria:**
- [ ] ActionCable handler listens for `contact.group_synced` event
- [ ] On receiving the event, the handler extracts the group members data directly from the event payload (no additional API call needed)
- [ ] Commits the data to the `groupMembers` store via mutation
- [ ] Group member list in sidebar updates reactively
- [ ] Typecheck/lint passes

## Functional Requirements

- **FR-1:** Rename `conversation_type` column to `group_type` on `conversations` table; update all backend references
- **FR-2:** Add `group_type` to both conversation and contact JSON serializers
- **FR-3:** Create frontend API client with methods for all group endpoints (members, sync, create, metadata, invite, join requests)
- **FR-4:** Create Vuex store module `groupMembers` with full CRUD state management
- **FR-5:** Add all i18n keys (en + pt-BR) for group UI text
- **FR-6:** Add "Type" filter section in `ConversationBasicFilter` dropdown (All/Individual/Group), persisted in UI settings
- **FR-7:** Add `group_type` to the advanced filter system (frontend + backend filter_keys.yml)
- **FR-8:** Create `GroupContactInfo.vue` displaying group avatar, name, member count, member list (admin badge only), sync button with skeleton loading
- **FR-9:** Conditionally render `GroupContactInfo` vs `ContactInfo` in `ContactPanel.vue` based on `group_type`; keep `contact_notes` and `contact_attributes` visible for groups
- **FR-10:** Backend endpoint for group creation delegating to Baileys `groupCreate`
- **FR-11:** Backend endpoints for add/remove members and role management delegating to Baileys `groupParticipantsUpdate`
- **FR-12:** Backend endpoint for group metadata update (name, description) delegating to Baileys `groupUpdateSubject`/`groupUpdateDescription`; avatar upload via existing contact update + provider profile picture update
- **FR-13:** Backend endpoints for invite link get/revoke delegating to Baileys `groupInviteCode`/`groupRevokeInvite`
- **FR-14:** Backend endpoints for join request list/approve/reject delegating to Baileys `groupRequestParticipantsList`/`groupRequestParticipantsUpdate`
- **FR-15:** Frontend UI for group creation (modal with inbox, name, participant selection)
- **FR-16:** Frontend member management UI in GroupContactInfo (add, remove, promote/demote)
- **FR-17:** Frontend group metadata editing (inline editable name/description, avatar upload)
- **FR-18:** Frontend invite link management (view, copy, revoke)
- **FR-19:** Frontend join request management (list, approve, reject)
- **FR-20:** Group message bubbles with colored sender names (color from name hash, same palette as Avatar: `name.length % 6`) and sender avatars
- **FR-21:** @mention system in group conversations targeting group member contacts (extends existing ProseMirror mention infrastructure)
- **FR-22:** Handle `contact.group_synced` ActionCable event using event payload data directly (no re-fetch)

## Non-Goals

- No notifications or sounds specific to group conversations (use existing notification system)
- No group-to-group messaging (a group is always tied to a provider group like WhatsApp)
- No bulk group operations (e.g., merge groups, archive all groups)
- No automated group creation rules or templates
- No group analytics or reporting dashboard
- No changes to the conversation card in the list (no special group badge/icon — filtering handles differentiation)

## Design Considerations

- **GroupContactInfo** should follow the same layout patterns as `ContactInfo` (padding, typography, avatar size) for visual consistency
- Member list should be scrollable if the group has many members (use `max-h-*` + `overflow-y-auto`)
- Sync button shows a **spinner** during sync
- **Skeleton loading placeholders** for member list while fetching, and for any section loading group data
- **Admin badge only** — members have no badge; admin role gets a subtle badge (e.g., small "Admin" text badge or shield icon)
- Sender name colors in group message bubbles use the same palette and algorithm as the `Avatar` component: `AVATAR_COLORS[mode][name.length % 6]`
- Sender avatars in message bubbles follow the same placeholder logic (initials + color) when no thumbnail is available
- Mention dropdown for group contacts follows the same pattern as `TagAgents.vue` but shows contacts instead of agents
- Reuse existing components: `Avatar`, `NextButton`, `AccordionItem`, `SelectMenu`, `MentionBox`, skeleton components, and others available in the component library — the components listed here are examples; use any existing component that fits
- Follow **Tailwind-only** styling as per project guidelines (no custom CSS, no scoped CSS, no inline styles)

## Technical Considerations

- **Column rename:** `conversation_type` → `group_type` requires a migration + updating all references across the backend (model enums, concerns, services, controllers, handlers, specs, JBuilder views). The frontend routing `conversationType` remains unchanged.
- **Store key pattern:** Use `contactId` as the key for group members in the store (since group members are associated with the group contact, and a group contact may have multiple conversations)
- **ActionCable event:** The `contact.group_synced` event payload already includes all group member data. The frontend handler should directly commit this data to the store without making an additional API call.
- The conversation serializer already has an enterprise partial include — no conflict with adding `group_type`
- Group members API response shape: `{ payload: [{ id, role, is_active, conversation_id, contact: { id, name, phone_number, identifier, thumbnail } }] }`
- **Baileys provider routes:** All new group management endpoints (create, members, metadata, invite, join requests) must be implemented first as abstract methods on the base channel service, then implemented concretely in `WhatsappBaileysService`. Refer to `tasks/references/baileys.d.ts` for available Baileys functions.
- **Mention system extension:** The existing `suggestionsPlugin` supports multiple triggers. For group conversations, the `@` trigger should show group member contacts instead of agents (keep listing agents on private note). The `mention_service.rb` backend needs to handle `mention://contact/ID/Name` format alongside existing `mention://user/ID/Name`.
- **Message bubble components:** Group-specific rendering (sender name, sender avatar) should be implemented in `components-next/` where message bubbles live.

## Success Metrics

- Agents can identify and filter group conversations in under 2 clicks (basic filter dropdown)
- Group member list loads within 1 second of opening the sidebar (with skeleton loading visible during fetch)
- Sync button successfully refreshes group members from the provider
- Group creation from UI results in a working group on the provider within 3 seconds
- Member add/remove/role changes are reflected both in the provider and in the UI
- @mentions in group messages trigger the suggestion dropdown with < 200ms latency
- No regressions in individual conversation sidebar behavior

## Open Questions

- Should the invite link section be visible by default or collapsed in an accordion?
  - Always visible with copy button to the side
- Should @mentions in group messages also create `Mention` records for contacts (extending the current user-only model), or only track them at the message level?
  - Yes
- What should happen if the provider (Baileys) is unavailable when trying to create/modify a group — retry queue, or immediate error?
  - Immediate error with user-friendly message
