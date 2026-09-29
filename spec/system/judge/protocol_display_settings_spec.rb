require "rails_helper"

RSpec.describe "Protocol overlay display settings autosave" do
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:game) { create(:game, hide_table_info: true) }

  let(:stored_settings) do
    page.document.synchronize do
      settings = game.reload.slice(:hide_roles, :hide_game_info, :hide_table_info).values
      raise Capybara::ExpectationNotMet, "settings not saved yet: #{settings.inspect}" unless settings == [ true, false, false ]

      settings
    end
  end

  before do
    sign_in admin
    visit edit_judge_protocol_path(game)
    click_button I18n.t("game_protocols.autosave.toggle_off")
    find("input[type='checkbox'][name='game[hide_roles]']").click
    find("input[type='checkbox'][name='game[hide_table_info]']").click
  end

  it "saves each toggled setting" do
    expect(stored_settings).to eq([ true, false, false ])
  end
end
