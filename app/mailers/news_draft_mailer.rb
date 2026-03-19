class NewsDraftMailer < ApplicationMailer
  def draft_created(user, news)
    @news = news

    I18n.with_locale(user.locale) do
      mail(
        to: user.email,
        subject: t(".subject", title: @news.title)
      )
    end
  end
end
