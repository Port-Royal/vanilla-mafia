require "rails_helper"

RSpec.describe "Hall of fame" do
  let(:document) { Nokogiri::HTML(response.body) }
  let(:players_section) { document.at_css("#hall-players") }
  let(:staff_section) { document.at_css("#hall-staff") }
  let(:cards) { players_section.css("[data-player-card]") }
  let(:card) { ->(player) { document.at_css("[data-player-card='#{player.id}']") } }
  let(:badge_titles) { ->(player) { card.(player).css("[data-award] [data-part='title']").map { |t| t.text.strip } } }

  let_it_be(:old_season) { create(:competition, :season, name: "Сезон 1", started_on: Date.new(2021, 1, 1)) }
  let_it_be(:new_season) { create(:competition, :season, name: "Сезон 2", started_on: Date.new(2022, 1, 1)) }

  context "when nobody has an award" do
    before { get hall_path }

    it "returns success" do
      expect(response).to have_http_status(:ok)
    end

    it "shows the title" do
      expect(document.at_css("main h1").text.strip).to eq("Зал Славы")
    end

    it "shows the coming soon note" do
      expect(document.at_css("#hall-empty").text.strip).to eq(I18n.t("common.coming_soon"))
    end

    it "shows no player cards" do
      expect(players_section).to be_nil
    end

    it "shows no organizers section" do
      expect(staff_section).to be_nil
    end
  end

  context "when players have awards" do
    let_it_be(:winner) { create(:award, title: "Победитель", position: 1) }
    let_it_be(:corpse) { create(:award, title: "Почётный трупак", position: 2) }
    let_it_be(:long_award) { create(:award, title: "Вот это поворот! Автор самой эпичной ошибки", position: 3) }
    let_it_be(:finch) { create(:player, name: "Финчер") }
    let_it_be(:remy) { create(:player, name: "Девятый Игрок Фол (ДИФ)") }

    before_all do
      create(:player_award, player: finch, award: corpse, competition: old_season)
      create(:player_award, player: finch, award: corpse, competition: new_season)
      create(:player_award, player: finch, award: winner, competition: new_season)
      create(:player_award, player: remy, award: long_award)
    end

    before { get hall_path }

    it "shows one card per awarded player, most awards first" do
      expect(cards.map { |c| c["data-player-card"] }).to eq([ finch.id.to_s, remy.id.to_s ])
    end

    it "labels the players section with a heading for screen readers" do
      expect(document.at_css("##{players_section['aria-labelledby']}").text.strip)
        .to eq(I18n.t("hall_of_fame.redesign.players"))
    end

    it "puts the players heading one level under the page title" do
      expect(players_section.at_css("h2.sr-only")).to be_present
    end

    it "links the name to the profile" do
      expect(card.(finch).at_css("a[href='#{player_path(finch)}']").text.strip).to eq("Финчер")
    end

    it "shows a long name in full" do
      expect(card.(remy).at_css("[data-part='name']").text.strip).to eq("Девятый Игрок Фол (ДИФ)")
    end

    it "shows the first letter when there is no photo" do
      expect(card.(finch).at_css("[data-part='initial']").text.strip).to eq("Ф")
    end

    it "hides the letter tile from screen readers" do
      expect(card.(finch).at_css("[data-part='initial']")["aria-hidden"]).to eq("true")
    end

    it "counts every award record, pluralised" do
      expect(card.(finch).at_css("[data-part='count']").text.strip).to eq("3 награды")
    end

    it "pluralises a single award" do
      expect(card.(remy).at_css("[data-part='count']").text.strip).to eq("1 награда")
    end

    it "shows one badge per award, in award order" do
      expect(badge_titles.(finch)).to eq([ "Победитель", "Почётный трупак" ])
    end

    it "lists the seasons of a repeated award, newest first" do
      expect(card.(finch).css("[data-award] .vm-sub").map { |s| s.text.strip }).to eq([ "Сезон 2", "Сезон 2, Сезон 1" ])
    end

    it "shows a long award title in full" do
      expect(badge_titles.(remy)).to eq([ "Вот это поворот! Автор самой эпичной ошибки" ])
    end

    it "shows no seasons line for an award won without a competition" do
      expect(card.(remy).css("[data-award] .vm-sub")).to be_empty
    end

    it "marks player awards as player badges" do
      expect(card.(finch).css("[data-award]").map { |b| b["data-award"] }.uniq).to eq([ "player" ])
    end

    it "shows no organizers section" do
      expect(staff_section).to be_nil
    end

    it "shows no coming soon note" do
      expect(document.at_css("#hall-empty")).to be_nil
    end

    it "does not use the old maroon colour" do
      expect(document.at_css("main").to_html).not_to include("maroon")
    end
  end

  context "when a player has a photo" do
    let_it_be(:player) do
      create(:player, name: "Фотогеничный").tap do |p|
        p.photo.attach(io: Rails.root.join("spec/fixtures/files/selfie.jpg").open, filename: "photo.jpg",
                       content_type: "image/jpeg")
      end
    end

    before_all { create(:player_award, player:, award: create(:award, title: "Глаз-алмаз")) }

    before { get hall_path }

    it "shows the photo as decoration, since the name follows it" do
      expect(card.(player).at_css("img[data-part='photo']")["alt"]).to eq("")
    end

    it "shows no letter tile" do
      expect(card.(player).at_css("[data-part='initial']")).to be_nil
    end
  end

  context "when there are staff awards" do
    let_it_be(:organizer_award) { create(:award, title: "Организатор", staff: true) }
    let_it_be(:organizer) { create(:player, name: "Ведущий") }

    before_all { create(:player_award, player: organizer, award: organizer_award) }

    before { get hall_path }

    it "shows the organizers heading" do
      expect(staff_section.at_css("h2").text.strip).to eq("Организаторы")
    end

    it "shows the organizer card" do
      expect(staff_section.css("[data-player-card]").map { |c| c["data-player-card"] }).to eq([ organizer.id.to_s ])
    end

    it "shows the staff badge" do
      expect(card.(organizer).at_css("[data-award]")["data-award"]).to eq("staff")
    end

    it "shows no count line for organizers" do
      expect(card.(organizer).at_css("[data-part='count']")).to be_nil
    end

    it "shows no player cards when only staff awards exist" do
      expect(players_section).to be_nil
    end

    it "shows no coming soon note" do
      expect(document.at_css("#hall-empty")).to be_nil
    end
  end
end
