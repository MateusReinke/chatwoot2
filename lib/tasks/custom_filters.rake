# frozen_string_literal: true

namespace :custom_filters do # rubocop:disable Metrics/BlockLength
  desc 'Replicate custom filters to all users in an account'
  task :replicate, %i[filter_id] => :environment do |_task, args| # rubocop:disable Metrics/BlockLength
    filter_id = args[:filter_id]

    if filter_id.blank?
      puts 'Usage: rails custom_filters:replicate[<filter_id>]'
      puts 'Example: rails custom_filters:replicate[123]'
      next
    end

    source_filter = CustomFilter.find_by(id: filter_id)
    unless source_filter
      puts "ERROR: Custom filter with ID #{filter_id} not found."
      next
    end

    account = source_filter.account
    puts "Replicating filter '#{source_filter.name}' (ID: #{source_filter.id}) to all users in account '#{account.name}' (ID: #{account.id})..."

    users = account.users.where.not(id: source_filter.user_id)
    total_users = users.count
    created_count = 0
    skipped_count = 0
    failed_count = 0

    puts "Found #{total_users} users (excluding the filter owner)."

    users.find_each.with_index do |user, index| # rubocop:disable Metrics/BlockLength
      # Check if user already has a filter with the same name and query
      existing_filter = account.custom_filters.find_by(
        user_id: user.id,
        name: source_filter.name,
        filter_type: source_filter.filter_type,
        query: source_filter.query
      )

      if existing_filter
        puts "[#{index + 1}/#{total_users}] Skipped user #{user.email} (ID: #{user.id}) - duplicate filter already exists (ID: #{existing_filter.id})"
        skipped_count += 1
        next
      end

      # Check if user has reached the limit
      current_filters_count = account.custom_filters.where(user_id: user.id).count
      if current_filters_count >= Limits::MAX_CUSTOM_FILTERS_PER_USER
        puts "[#{index + 1}/#{total_users}] Skipped user #{user.email} (ID: #{user.id}) - user has reached the maximum limit of " \
             "#{Limits::MAX_CUSTOM_FILTERS_PER_USER} filters"
        skipped_count += 1
        next
      end

      # Create the filter for the user
      new_filter = account.custom_filters.new(
        user_id: user.id,
        name: source_filter.name,
        filter_type: source_filter.filter_type,
        query: source_filter.query
      )

      if new_filter.save
        puts "[#{index + 1}/#{total_users}] Created filter for user #{user.email} (ID: #{user.id})"
        created_count += 1
      else
        puts "[#{index + 1}/#{total_users}] Failed to create filter for user #{user.email} (ID: #{user.id}) - " \
             "Errors: #{new_filter.errors.full_messages.join(', ')}"
        failed_count += 1
      end
    end

    puts "\n=== Summary ==="
    puts "Total users processed: #{total_users}"
    puts "Filters created: #{created_count}"
    puts "Skipped (duplicates or at limit): #{skipped_count}"
    puts "Failed: #{failed_count}"
  end
end
