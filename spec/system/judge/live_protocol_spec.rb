require "rails_helper"

RSpec.describe "Live protocol console" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:roles) { %w[don sheriff mafia peace].map { |code| create(:role, code: code) } }
  let_it_be(:toggle) { create(:feature_toggle, key: "live_protocol", enabled: true) }
  let(:game) { create(:game) }
  let!(:seats) { (1..10).map { |seat| create(:game_participation, game:, seat:, role_code: nil, player: create(:player, name: "Игрок#{seat}")) } }

  let(:press) { ->(*keys) { keys.each { |key| find("body").send_keys(key) } } }
  let(:start_game) { -> { press.call("1", "2", "3", "4", :enter); expect(page).to have_css("[data-role='don']"); press.call(:enter); expect(page).to have_text("Игрок1") } }

  before do
    sign_in admin
    visit live_judge_protocol_path(game)
    expect(page).to have_css("#lp-work")
  end

  it "plays a short game from the keyboard" do
    start_game.call
    press.call("n", "3", :space, "n", "4", "v")
    expect(page).to have_css(".lp-vote--now")
    press.call("1", "2", "5", "6", "7", "8", :enter)
    expect(page).to have_css(".lp-vote--now", text: "4")
    press.call(:enter)
    expect(page).to have_text(I18n.t("live_protocols.screen.best.eyebrow"))
    press.call(:enter)
    expect(page).to have_css("#lp-will")
    press.call(:enter)
    expect(page).to have_text(I18n.t("live_protocols.screen.night.shot"))
    press.call("x", "1", "x", "4")
    expect(page).to have_text(I18n.t("live_protocols.screen.results.peace_victory"))
    press.call("q")
    expect(page).to have_current_path(edit_judge_protocol_path(game))
    expect(game.reload.result).to eq("peace_victory")
  end

  it "shows the sheet in its tab" do
    start_game.call
    click_button I18n.t("live_protocols.screen.sheet.title")
    expect(page).to have_css(".lp-sheet", text: I18n.t("live_protocols.screen.sheet.shots"))
    click_button I18n.t("live_protocols.screen.log.title")
    expect(page).to have_css(".lp-log")
  end

  it "reads 0 as seat 10" do
    start_game.call
    press.call("n", "0")
    expect(page).to have_css(".lp-chip", text: "10")
  end

  it "cancels the pending action on Esc" do
    start_game.call
    press.call("n", :escape, "3")
    expect(page).to have_text(I18n.t("live_protocols.screen.errors.choose_action"))
  end

  it "writes nothing for a number with no action" do
    start_game.call
    press.call("3")
    expect(page).to have_no_css(".lp-chip")
  end

  it "works by mouse" do
    start_game.call
    click_button I18n.t("live_protocols.screen.actions.nominate")
    find("[data-seat='5']").click
    expect(page).to have_css(".lp-chip", text: "5")
  end

  context "when roles are hidden by day" do
    before { start_game.call }

    it "keeps them out of the DOM" do
      expect(page).to have_no_css("[data-role]")
    end

    it "shows them while H is held" do
      page.driver.browser.action.key_down("h").perform
      expect(page).to have_css("[data-role='don']")
      page.driver.browser.action.key_up("h").perform
      expect(page).to have_no_css("[data-role]")
    end

    it "hides them when the window loses focus" do
      page.driver.browser.action.key_down("h").perform
      expect(page).to have_css("[data-role='don']")
      page.execute_script("window.dispatchEvent(new Event('blur'))")
      expect(page).to have_no_css("[data-role]")
      page.driver.browser.action.key_up("h").perform
    end

    it "does not redraw on the auto repeat of H" do
      page.driver.browser.action.key_down("h").perform
      expect(page).to have_css("[data-role='don']")
      page.execute_script("document.getElementById('lp-work').dataset.kept = 'yes'")
      page.execute_script("document.dispatchEvent(new KeyboardEvent('keydown', { code: 'KeyH', repeat: true, bubbles: true }))")
      expect(page.evaluate_script("document.getElementById('lp-work').dataset.kept")).to eq("yes")
      page.driver.browser.action.key_up("h").perform
    end
  end

  it "opens a finished game read-only with everything revealed" do
    start_game.call
    find("body").send_keys([ :shift, "d" ])
    expect(page).to have_current_path(edit_judge_protocol_path(game))
    visit live_judge_protocol_path(game)
    expect(page).to have_css("[data-role='don']")
    expect(page).to have_text(I18n.t("live_protocols.screen.finish.done"))
  end

  it "focuses the will field in the leaving speech" do
    start_game.call
    press.call("v", "5", :enter, :enter)
    expect(page).to have_text(I18n.t("live_protocols.screen.best.eyebrow"))
    press.call(:enter)
    expect(page.evaluate_script("document.activeElement.id")).to eq("lp-will")
  end

  it "undoes a whole action group with Ctrl+Z" do
    start_game.call
    press.call("g", "5", "g", "5")
    expect(page).to have_css(".lp-seat--out", text: "Игрок5")
    find("body").send_keys([ :control, "z" ])
    expect(page).to have_no_css(".lp-seat--out")
  end

  it "brings the deal back after undoing into it" do
    start_game.call
    find("body").send_keys([ :control, "z" ])
    expect(page).to have_text(I18n.t("live_protocols.screen.deal.title"))
  end

  context "with roles from the form" do
    before do
      { 1 => "don", 2 => "sheriff", 3 => "mafia", 4 => "mafia" }.each { |seat, code| seats[seat - 1].update!(role_code: code) }
      seats[4..].each { |seat| seat.update!(role_code: "peace") }
      visit live_judge_protocol_path(game)
    end

    it "keeps them after confirm and Ctrl+Z" do
      expect(page).to have_css("[data-role='don']")
      press.call(:enter)
      expect(page).to have_text(I18n.t("live_protocols.screen.deal.title"))
      find("body").send_keys([ :control, "z" ])
      expect(page).to have_css("[data-role='don']")
      expect(page).to have_css("[data-seat='1'] [data-role='don']")
    end
  end
end
