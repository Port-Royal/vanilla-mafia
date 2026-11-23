require "rails_helper"

# The admin, judge, account and podcast screens render inside the warm-paper shell; their own markup follows it.
RSpec.describe "Working screens in the paper style" do
  include GameBreakdownHelpers

  let_it_be(:admin) { create(:user, :admin, player: create(:player, name: "Админ")) }
  let_it_be(:subscriber) { create(:user, :subscriber) }

  let(:current_page) { Nokogiri::HTML(response.body).at_css("main#site-main nav [aria-current='page']") }

  describe "admin news" do
    let_it_be(:published) { create(:news, :published, author: admin) }
    let_it_be(:drafts) { create_list(:news, 25, author: admin) }

    before { sign_in admin }

    context "with the list" do
      before { get admin_news_index_path }

      it_behaves_like "a page in the paper style"

      it "paginates with the paper nav" do
        expect(current_page["class"].split).to include("border-ink", "bg-ink", "text-gold-bright")
      end
    end

    context "with a draft" do
      before { get admin_news_path(drafts.first) }

      it_behaves_like "a page in the paper style"
    end

    context "with a published article" do
      before { get admin_news_path(published) }

      it_behaves_like "a page in the paper style"
    end

    context "with the new article form" do
      before { get new_admin_news_path }

      it_behaves_like "a page in the paper style"
    end

    context "with the edit form showing errors" do
      before { patch admin_news_path(drafts.first), params: { news: { title: "" } } }

      it_behaves_like "a page in the paper style"
    end
  end

  describe "admin telegram settings" do
    let_it_be(:author) { create(:telegram_author, user: admin) }

    before do
      allow(Telegram::WebhookInfoService).to receive(:call).and_return(webhook_info)
      sign_in admin
      get admin_telegram_settings_path
    end

    context "with an active webhook" do
      let(:webhook_info) do
        Telegram::WebhookInfoService::Result.new(success: true, url: "https://example.com/hook", pending_update_count: 0,
                                                 description: nil)
      end

      it_behaves_like "a page in the paper style"
    end

    context "with no webhook" do
      let(:webhook_info) do
        Telegram::WebhookInfoService::Result.new(success: true, url: "", pending_update_count: 0, description: nil)
      end

      it_behaves_like "a page in the paper style"
    end

    context "with a failed webhook lookup" do
      let(:webhook_info) do
        Telegram::WebhookInfoService::Result.new(success: false, url: nil, pending_update_count: nil,
                                                 description: "Unauthorized")
      end

      it_behaves_like "a page in the paper style"
    end
  end

  describe "sign-in and account" do
    let_it_be(:user) { create(:user) }

    context "with the sign-in form" do
      before { get new_user_session_path }

      it_behaves_like "a page in the paper style"
    end

    context "with the sign-up form showing errors" do
      before { post user_registration_path, params: { user: { email: "", password: "x", password_confirmation: "y" } } }

      it_behaves_like "a page in the paper style"
    end

    context "with the password reset request" do
      before { get new_user_password_path }

      it_behaves_like "a page in the paper style"
    end

    context "with the new password form" do
      before { get edit_user_password_path(reset_password_token: user.send(:set_reset_password_token)) }

      it_behaves_like "a page in the paper style"
    end

    context "with the account settings" do
      before do
        sign_in user
        get edit_user_registration_path
      end

      it_behaves_like "a page in the paper style"
    end
  end

  describe "the player's own pages" do
    let_it_be(:player) { create(:player, name: "Свой") }
    let_it_be(:user) { create(:user, :editor, player: player) }
    let_it_be(:claimed) { create(:player, name: "Чужой").tap { |claimed| create(:user, player: claimed) } }

    before { sign_in user }

    context "with the profile form showing errors" do
      before { patch profile_path, params: { player: { name: "" } } }

      it_behaves_like "a page in the paper style"
    end

    context "with the notification settings" do
      before { get edit_notification_settings_path }

      it_behaves_like "a page in the paper style"
    end

    context "with the dispute form" do
      before do
        sign_in create(:user)
        get new_player_dispute_path(claimed)
      end

      it_behaves_like "a page in the paper style"
    end
  end

  describe "judge protocols" do
    let_it_be(:stale) { create(:game, played_on: Date.current - 1) }

    before do
      create(:feature_toggle, key: "live_protocol", enabled: true)
      sign_in admin
    end

    context "with the list" do
      before { get judge_protocols_path }

      it_behaves_like "a page in the paper style"
    end

    context "with the new protocol form" do
      before { get new_judge_protocol_path }

      it_behaves_like "a page in the paper style"
    end

    context "with the edit form" do
      before { get edit_judge_protocol_path(stale) }

      it_behaves_like "a page in the paper style"
    end
  end

  describe "judge breakdowns" do
    let(:breakdown) { create(:game_breakdown, author: admin, title: "Финал", roles_mode: "open", judge_name: "Иванов") }
    let(:zero_round) { breakdown.phases.find_by(position: 0) }

    before do
      create(:feature_toggle, key: "game_breakdown", enabled: true)
      assign_roles(mafia: [ 2, 3 ], don: 4, sheriff: 5)
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      vote(zero_round, "main", [ 1, 2, 3, 4, 5, 6 ] => 4, [ 7, 8, 9, 10 ] => 5)
      night(1)
      second_day = day(2)
      speech(second_day, 7, kind: "farewell")
      sign_in admin
    end

    context "with the list" do
      before { get judge_breakdowns_path }

      it_behaves_like "a page in the paper style"
    end

    context "with the new breakdown form showing errors" do
      before { post judge_breakdowns_path, params: { game_breakdown: { title: "" } } }

      it_behaves_like "a page in the paper style"
    end

    context "with the editor" do
      before { get edit_judge_breakdown_path(breakdown) }

      it_behaves_like "a page in the paper style"
    end

    context "with the read-only view" do
      before { get judge_breakdown_path(breakdown) }

      it_behaves_like "a page in the paper style"
    end

    context "with the read-only view filtered to a seat" do
      before { get judge_breakdown_path(breakdown, seat: 4) }

      it_behaves_like "a page in the paper style"
    end
  end

  describe "podcast" do
    let_it_be(:episodes) do
      create_list(:episode, 26, status: "published", published_at: 1.day.ago, description: "Выпуск")
    end
    let_it_be(:playlist) { create(:playlist, title: "Лучшее") }
    let_it_be(:entry) { create(:playlist_episode, playlist: playlist, episode: episodes.first, position: 1) }

    before { sign_in subscriber }

    context "with the episode list" do
      before { get podcast_episodes_path }

      it_behaves_like "a page in the paper style"

      it "paginates with the paper nav" do
        expect(current_page["class"].split).to include("border-ink", "bg-ink", "text-gold-bright")
      end
    end

    context "with an episode without audio" do
      before { get podcast_episode_path(episodes.first) }

      it_behaves_like "a page in the paper style"
    end

    context "with an episode with audio" do
      before do
        episodes.last.audio.attach(io: StringIO.new("fake-audio"), filename: "episode.mp3", content_type: "audio/mpeg")
        get podcast_episode_path(episodes.last)
      end

      it_behaves_like "a page in the paper style"
    end

    context "with the playlists" do
      before { get podcast_playlists_path }

      it_behaves_like "a page in the paper style"
    end

    context "with a playlist" do
      before { get podcast_playlist_path(playlist) }

      it_behaves_like "a page in the paper style"
    end
  end
end
