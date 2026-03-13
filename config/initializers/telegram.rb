Rails.application.config.telegram = ActiveSupport::OrderedOptions.new
Rails.application.config.telegram.bot_token = Rails.application.credentials.dig(:telegram, :bot_token)
