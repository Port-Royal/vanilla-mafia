class NotifyEditorsAboutDraftService
  def self.call(news)
    new(news).call
  end

  def initialize(news)
    @news = news
  end

  def call
    return unless @news.draft?

    recipients.find_each do |user|
      NewsDraftMailer.draft_created(user, @news).deliver_later
    end
  end

  private

  def recipients
    User
      .joins(:grants).where(grants: { code: %w[editor admin] })
      .where(notify_on_news_draft: true)
      .where.not(id: @news.author_id)
  end
end
