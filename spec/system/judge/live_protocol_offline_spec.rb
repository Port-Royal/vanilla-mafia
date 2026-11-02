require "rails_helper"

RSpec.describe "Live protocol send queue" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:roles) { %w[don sheriff mafia peace].map { |code| create(:role, code: code) } }
  let_it_be(:toggle) { create(:feature_toggle, key: "live_protocol", enabled: true) }
  let(:game) { create(:game) }
  let!(:seats) { (1..10).map { |seat| create(:game_participation, game:, seat:, role_code: nil) } }

  let(:press) { ->(*keys) { keys.each { |key| find("body").send_keys(key) } } }
  let(:saved_text) { I18n.t("live_protocols.screen.connection.saved") }
  let(:cut_connection) { -> { page.execute_script("window.realFetch = window.fetch; window.fetch = () => Promise.reject(new TypeError('offline'))") } }
  let(:restore_connection) { -> { page.execute_script("window.fetch = window.realFetch") } }
  let(:journal_kinds) { -> { game.game_protocol_events.order(:position).pluck(:kind) } }

  before do
    sign_in admin
    visit live_judge_protocol_path(game)
    expect(page).to have_css("#lp-work")
    press.call("1", "2", "3", "4", :enter)
    expect(page).to have_css("[data-seat='1'] [data-role='don']")
    press.call(:enter)
    expect(page).to have_css(".lp-seat--speaking", text: "1")
    expect(page).to have_css(".lp-status", exact_text: saved_text)
  end

  it "writes the journal and the roles to the server" do
    expect([ journal_kinds.call, seats.first.reload.role_code ]).to eq([ %w[roles deal], "don" ])
  end

  it "comes back to the same stage after a reload" do
    press.call("n", "5")
    expect(page).to have_css(".lp-chip", text: "5")
    expect(page).to have_css(".lp-status", exact_text: saved_text)
    visit live_judge_protocol_path(game)
    expect(page).to have_css(".lp-chip", text: "5")
  end

  it "keeps the order of quick actions on the server" do
    press.call("n", "5", :space, "n", "6", :space, "n", "7")
    expect(page).to have_css(".lp-chip", count: 3)
    expect(page).to have_css(".lp-status", exact_text: saved_text)
    expect(game.game_protocol_events.order(:position).where(kind: "nominate").map { |event| event.target_seats.first }).to eq([ 5, 6, 7 ])
  end

  it "shows the loss of connection and catches up" do
    cut_connection.call
    press.call("n", "5")
    expect(page).to have_css(".lp-status--bad", text: I18n.t("live_protocols.screen.connection.offline"))
    restore_connection.call
    expect(page).to have_css(".lp-status", exact_text: saved_text, wait: 10)
    expect(journal_kinds.call).to eq(%w[roles deal nominate])
  end

  it "keeps unsent events through a reload with no doubles" do
    cut_connection.call
    press.call("n", "5")
    expect(page).to have_css(".lp-status--bad")
    visit live_judge_protocol_path(game)
    expect(page).to have_css(".lp-chip", count: 1, text: "5")
    expect(page).to have_css(".lp-status", exact_text: saved_text, wait: 10)
    expect(journal_kinds.call).to eq(%w[roles deal nominate])
  end

  it "does not ask the server to delete what it never received" do
    cut_connection.call
    press.call("n", "5", :space)
    expect(page).to have_css(".lp-seat--speaking", text: "2")
    find("body").send_keys([ :control, "z" ])
    expect(page).to have_css(".lp-seat--speaking", text: "1")
    restore_connection.call
    expect(page).to have_css(".lp-status", exact_text: saved_text, wait: 10)
    expect(journal_kinds.call).to eq(%w[roles deal nominate])
  end

  it "undoes on the server and returns the roles" do
    find("body").send_keys([ :control, "z" ])
    find("body").send_keys([ :control, "z" ])
    expect(page).to have_text(I18n.t("live_protocols.screen.roles.title"))
    expect(page).to have_css(".lp-status", exact_text: saved_text)
    expect([ journal_kinds.call, seats.first.reload.role_code ]).to eq([ [], nil ])
  end

  it "stops and says so when the server refuses" do
    page.execute_script("window.fetch = () => Promise.resolve(new Response('{}', { status: 422 }))")
    press.call("n", "5")
    expect(page).to have_css(".lp-status--bad", text: I18n.t("live_protocols.screen.connection.rejected"))
  end
end
