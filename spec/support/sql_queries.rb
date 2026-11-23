# Request specs check eager loading by counting the SQL a request runs.
module SqlQueries
  IGNORED_NAMES = %w[SCHEMA TRANSACTION].freeze

  # The SQL the block runs, leaving out schema, transaction and cached queries.
  def queries_during(&)
    queries = []
    recorder = ->(*, payload) { queries << payload[:sql] unless payload[:name].in?(IGNORED_NAMES) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(recorder, "sql.active_record", &)
    queries
  end
end

RSpec.configure do |config|
  config.include SqlQueries, type: :request
end
