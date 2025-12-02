# frozen_string_literal: true

class Api::V1::Accounts::KanbanController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  # GET /api/v1/accounts/:account_id/kanban
  # Retorna todos os leads organizados por status para o Kanban
  def index
    @conversations = Current.account.conversations
                                    .includes(:contact, :inbox, :assignee, :team)
                                    .order(last_activity_at: :desc)

    # Aplicar filtros
    @conversations = apply_filters(@conversations)

    # Agrupar por status
    @kanban_data = group_by_status(@conversations)

    # Estatísticas
    @stats = calculate_stats(@conversations)
  end

  # PUT /api/v1/accounts/:account_id/kanban/:id/move
  # Move um lead para outra coluna (muda o status)
  def move
    @conversation = Current.account.conversations.find(params[:id])

    old_status = @conversation.status
    new_status = params[:status]

    # Atualizar status via custom attribute (ou status nativo)
    if @conversation.contact.present?
      custom_attrs = @conversation.contact.custom_attributes || {}
      custom_attrs['status_lead'] = new_status
      @conversation.contact.update!(custom_attributes: custom_attrs)
    end

    # Criar activity message
    create_activity_message(@conversation, old_status, new_status)

    render json: {
      success: true,
      conversation: conversation_json(@conversation)
    }
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/kanban/export
  # Exporta leads de uma coluna específica
  def export
    status = params[:status]
    @conversations = Current.account.conversations
                                    .includes(:contact, :inbox)

    # Filtrar por status
    @conversations = filter_by_status(@conversations, status) if status.present?

    # Gerar dados para planilha
    @export_data = @conversations.map do |conv|
      contact = conv.contact
      custom_attrs = contact&.custom_attributes || {}

      {
        nome: contact&.name || 'Sem nome',
        telefone: contact&.phone_number || conv.contact_inbox&.source_id,
        email: contact&.email,
        status: custom_attrs['status_lead'] || 'novo_lead',
        lead_score: custom_attrs['lead_score'] || 0,
        temperatura: custom_attrs['temperatura'] || 'frio',
        servico_interesse: custom_attrs['servico_interesse'],
        dores_identificadas: custom_attrs['dores_identificadas'],
        objecoes: custom_attrs['objecoes'],
        ultima_mensagem: conv.messages.last&.content&.truncate(100),
        ultimo_contato: conv.last_activity_at&.strftime('%d/%m/%Y %H:%M'),
        total_mensagens: conv.messages_count,
        inbox: conv.inbox&.name,
        atribuido_a: conv.assignee&.name
      }
    end

    render json: { data: @export_data }
  end

  private

  def apply_filters(conversations)
    conversations = filter_by_status(conversations, params[:status]) if params[:status].present?
    conversations = filter_by_temperatura(conversations, params[:temperatura]) if params[:temperatura].present?
    conversations = filter_by_score(conversations, params[:score]) if params[:score].present?
    conversations = filter_by_search(conversations, params[:search]) if params[:search].present?
    conversations = filter_by_inbox(conversations, params[:inbox_id]) if params[:inbox_id].present?
    conversations
  end

  def filter_by_status(conversations, status)
    conversations.joins(:contact).where(
      "contacts.custom_attributes->>'status_lead' = ?", status
    )
  end

  def filter_by_temperatura(conversations, temperatura)
    conversations.joins(:contact).where(
      "contacts.custom_attributes->>'temperatura' = ?", temperatura
    )
  end

  def filter_by_score(conversations, score_range)
    case score_range
    when 'alto'
      conversations.joins(:contact).where(
        "(contacts.custom_attributes->>'lead_score')::int >= 70"
      )
    when 'medio'
      conversations.joins(:contact).where(
        "(contacts.custom_attributes->>'lead_score')::int BETWEEN 40 AND 69"
      )
    when 'baixo'
      conversations.joins(:contact).where(
        "(contacts.custom_attributes->>'lead_score')::int < 40"
      )
    else
      conversations
    end
  end

  def filter_by_search(conversations, search)
    conversations.joins(:contact).where(
      'contacts.name ILIKE ? OR contacts.phone_number ILIKE ?',
      "%#{search}%", "%#{search}%"
    )
  end

  def filter_by_inbox(conversations, inbox_id)
    conversations.where(inbox_id: inbox_id)
  end

  def group_by_status(conversations)
    # Buscar status de conversão configurado para a conta
    status_conversao = Current.account.custom_attributes&.dig('status_conversao') || 'convertido'

    statuses = ['novo_lead', 'aquecimento', 'qualificado', status_conversao, 'perdido']

    grouped = {}
    statuses.each do |status|
      grouped[status] = conversations.select do |conv|
        conv.contact&.custom_attributes&.dig('status_lead') == status
      end
    end

    grouped
  end

  def calculate_stats(conversations)
    total = conversations.count

    by_status = {}
    group_by_status(conversations).each do |status, convs|
      by_status[status] = convs.count
    end

    by_temperatura = {
      'quente' => 0,
      'morno' => 0,
      'frio' => 0
    }

    conversations.each do |conv|
      temp = conv.contact&.custom_attributes&.dig('temperatura')
      by_temperatura[temp] += 1 if temp.present?
    end

    {
      total: total,
      by_status: by_status,
      by_temperatura: by_temperatura
    }
  end

  def create_activity_message(conversation, old_status, new_status)
    content = "Status alterado de #{format_status(old_status)} para #{format_status(new_status)}"

    conversation.messages.create!(
      account: Current.account,
      inbox: conversation.inbox,
      message_type: :activity,
      content: content,
      sender: Current.user
    )
  end

  def format_status(status)
    {
      'novo_lead' => 'Novo Lead',
      'aquecimento' => 'Aquecimento',
      'qualificado' => 'Qualificado',
      'convertido' => 'Convertido',
      'agendado' => 'Agendado',
      'perdido' => 'Perdido'
    }[status] || status
  end

  def conversation_json(conversation)
    {
      id: conversation.id,
      contact: {
        id: conversation.contact&.id,
        name: conversation.contact&.name,
        phone_number: conversation.contact&.phone_number,
        custom_attributes: conversation.contact&.custom_attributes
      },
      inbox: {
        id: conversation.inbox&.id,
        name: conversation.inbox&.name
      },
      status: conversation.contact&.custom_attributes&.dig('status_lead'),
      last_activity_at: conversation.last_activity_at
    }
  end
end
