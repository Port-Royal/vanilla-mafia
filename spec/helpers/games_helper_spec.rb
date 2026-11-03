require "rails_helper"

RSpec.describe GamesHelper do
  describe "#overlay_player_status" do
    it "returns nil when no participation is given" do
      expect(helper.overlay_player_status(nil)).to be_nil
    end

    it "returns the participation status as a symbol" do
      participation = instance_double(GameParticipation, status: "killed_by_mafia")

      expect(helper.overlay_player_status(participation)).to eq(:killed_by_mafia)
    end

    it "returns :alive for a freshly built participation" do
      participation = GameParticipation.new

      expect(helper.overlay_player_status(participation)).to eq(:alive)
    end

    it "reflects a voted_out participation" do
      participation = GameParticipation.new(status: :voted_out)

      expect(helper.overlay_player_status(participation)).to eq(:voted_out)
    end

    it "reflects a banned participation" do
      participation = GameParticipation.new(status: :banned)

      expect(helper.overlay_player_status(participation)).to eq(:banned)
    end
  end

  describe "#overlay_role_badge" do
    {
      "sheriff" => "Ш",
      "don" => "Д",
      "mafia" => "М"
    }.each do |role_code, letter|
      context "when the role is #{role_code}" do
        it "returns the #{letter} letter" do
          expect(helper.overlay_role_badge(role_code)).to eq(letter)
        end
      end
    end

    [ nil, "unknown", "peace" ].each do |role_code|
      context "when the role is #{role_code.inspect}" do
        it "returns nil" do
          expect(helper.overlay_role_badge(role_code)).to be_nil
        end
      end
    end
  end

  describe "#overlay_role_badge_role" do
    %w[sheriff don mafia].each do |role_code|
      it "keeps #{role_code}" do
        expect(helper.overlay_role_badge_role(role_code)).to eq(role_code)
      end
    end

    [ nil, "unknown", "peace" ].each do |role_code|
      it "gives nothing for #{role_code.inspect}" do
        expect(helper.overlay_role_badge_role(role_code)).to be_nil
      end
    end
  end

  describe "#overlay_eliminated?" do
    %i[killed_by_mafia voted_out banned].each do |status|
      context "when the status is #{status}" do
        it "is true" do
          expect(helper.overlay_eliminated?(status)).to be(true)
        end
      end
    end

    [ :alive, nil ].each do |status|
      context "when the status is #{status.inspect}" do
        it "is false" do
          expect(helper.overlay_eliminated?(status)).to be(false)
        end
      end
    end
  end

  describe "#table_overlay_url_for" do
    subject { helper.table_overlay_url_for(build(:game, table_number:)) }

    context "with table 1" do
      let(:table_number) { 1 }

      it { is_expected.to eq("http://test.host/overlay") }
    end

    context "without a table number" do
      let(:table_number) { nil }

      it { is_expected.to eq("http://test.host/overlay") }
    end

    context "with another table" do
      let(:table_number) { 3 }

      it { is_expected.to eq("http://test.host/overlay/tables/3") }
    end
  end

  describe "#overlay_status_icon" do
    let(:icon) { Nokogiri::HTML5.fragment(helper.overlay_status_icon(status)).at_css("svg") }

    %i[killed_by_mafia voted_out banned].each do |status_key|
      context "when the status is #{status_key}" do
        let(:status) { status_key }
        let(:source) { Nokogiri::XML(Rails.root.join("app/assets/images/overlay/status/#{status_key}.svg").read).root }

        it "inlines the #{status_key} icon file" do
          expect(icon.at_css("path")["d"]).to eq(source.at_xpath("//*[local-name()='path']")["d"])
        end

        it "returns markup safe to inline" do
          expect(helper.overlay_status_icon(status)).to be_html_safe
        end

        it "marks the icon with its status, sizing and accessibility attributes" do
          expect(icon.to_h).to include(
            "data-status" => status_key.to_s,
            "class" => "h-full w-full drop-shadow",
            "aria-hidden" => "true"
          )
        end
      end
    end

    [ :alive, nil ].each do |status_key|
      context "when the status is #{status_key.inspect}" do
        let(:status) { status_key }

        it "renders nothing" do
          expect(helper.overlay_status_icon(status)).to be_nil
        end
      end
    end
  end

  describe "#overlay_table_label" do
    let(:game) { Game.new(table_number: table_number) }

    context "when the table number is set" do
      let(:table_number) { 3 }

      it "labels the table" do
        expect(helper.overlay_table_label(game)).to eq("Стол 3")
      end
    end

    context "when the table number is blank" do
      let(:table_number) { nil }

      it "returns nil" do
        expect(helper.overlay_table_label(game)).to be_nil
      end
    end
  end

  describe "#overlay_game_label" do
    let(:game) { Game.new(game_number: 5, games_total: games_total) }

    context "when the total is set" do
      let(:games_total) { 8 }

      it "labels the game as a fraction of the total" do
        expect(helper.overlay_game_label(game)).to eq("Игра 5/8")
      end
    end

    context "when the total is blank" do
      let(:games_total) { nil }

      it "labels the game by its number" do
        expect(helper.overlay_game_label(game)).to eq("Игра 5")
      end
    end
  end

  describe "#overlay_judge_label" do
    let(:game) { Game.new(judge: judge) }

    context "when the judge is set" do
      let(:judge) { "Кузнецов" }

      it "labels the judge" do
        expect(helper.overlay_judge_label(game)).to eq("Судья Кузнецов")
      end
    end

    context "when the judge is blank" do
      let(:judge) { " " }

      it "returns nil" do
        expect(helper.overlay_judge_label(game)).to be_nil
      end
    end
  end

  describe "#overlay_best_move_colour" do
    {
      "mafia" => "black",
      "don" => "black",
      "peace" => "red",
      "sheriff" => "red",
      nil => "neutral",
      "unknown" => "neutral"
    }.each do |role_code, colour|
      context "when the named player's role is #{role_code.inspect}" do
        it "is #{colour}" do
          expect(helper.overlay_best_move_colour(role_code)).to eq(colour)
        end
      end
    end
  end

  describe "#overlay_seat_roles" do
    let(:participations_by_seat) do
      {
        5 => GameParticipation.new(seat: 5, role_code: "peace"),
        3 => GameParticipation.new(seat: 3, role_code: "don"),
        7 => GameParticipation.new(seat: 7, role_code: nil)
      }
    end

    it "maps every seat with a role, in seat order" do
      expect(helper.overlay_seat_roles(participations_by_seat).to_a).to eq([ [ 3, "don" ], [ 5, "peace" ] ])
    end

    context "with an unseated legacy participation" do
      before { participations_by_seat[nil] = GameParticipation.new(seat: nil, role_code: "mafia") }

      it "leaves it out" do
        expect(helper.overlay_seat_roles(participations_by_seat).to_a).to eq([ [ 3, "don" ], [ 5, "peace" ] ])
      end
    end
  end

  describe "#overlay_best_move_cells" do
    let(:seat_roles) { { 3 => "don", 5 => "peace" } }
    let(:participation) { GameParticipation.new(seat: 1, best_move_seats: best_move_seats) }
    let(:best_move_seats) { [ 3, 5, 7 ] }
    let(:cells) { helper.overlay_best_move_cells(participation, seat_roles) }

    it "colours every named seat by its player's role" do
      expect(cells).to eq([ [ 3, "black" ], [ 5, "red" ], [ 7, "neutral" ] ])
    end

    context "when no roles are known" do
      let(:seat_roles) { {} }

      it "keeps every cell neutral" do
        expect(cells).to eq([ [ 3, "neutral" ], [ 5, "neutral" ], [ 7, "neutral" ] ])
      end
    end

    context "when no seats are named" do
      let(:best_move_seats) { nil }

      it "has no cells" do
        expect(cells).to eq([])
      end
    end

    context "when the seat is empty" do
      let(:participation) { nil }

      it "has no cells" do
        expect(cells).to eq([])
      end
    end
  end

  describe "#overlay_canvas_class" do
    let(:game) { Game.new(settings) }
    let(:classes) { helper.overlay_canvas_class(game).split }

    context "when nothing is hidden" do
      let(:settings) { {} }

      it "is the plain canvas" do
        expect(classes).to eq(%w[overlay-canvas text-white])
      end
    end

    context "when everything is hidden" do
      let(:settings) { { hide_roles: true, hide_game_info: true, hide_table_info: true } }

      it "adds a class per hidden block" do
        expect(classes).to eq(%w[
          overlay-canvas text-white overlay-canvas--hide-roles overlay-canvas--hide-game-info overlay-canvas--hide-table-info
        ])
      end
    end

    {
      hide_roles: "overlay-canvas--hide-roles",
      hide_game_info: "overlay-canvas--hide-game-info",
      hide_table_info: "overlay-canvas--hide-table-info"
    }.each do |setting, css_class|
      context "when only #{setting} is on" do
        let(:settings) { { setting => true } }

        it "adds only #{css_class}" do
          expect(classes).to eq([ "overlay-canvas", "text-white", css_class ])
        end
      end
    end
  end

  describe "#overlay_seat_colour" do
    { "don" => "black", "mafia" => "black", "sheriff" => "red", "peace" => "red", nil => "neutral", "maf" => "neutral" }.each do |role_code, colour|
      it "gives #{colour} for #{role_code.inspect}" do
        expect(helper.overlay_seat_colour(role_code)).to eq(colour)
      end
    end
  end

  describe "#overlay_night_rows" do
    let(:shots) { [ { night: 1, target_seat: 5, team: "black" }, { night: 3, target_seat: nil, team: nil } ] }
    let(:checks) { [ { night: 1, kind: "don", target_seat: 7, result: "not_sheriff", team: "red" }, { night: 2, kind: "sheriff", target_seat: 3, result: "red", team: "red" } ] }
    let(:rows) { helper.overlay_night_rows(shots, checks) }

    it "counts the nights from every entry" do
      expect(rows[:nights]).to eq(3)
    end

    it "puts each shot in its night, an empty cell for a night with none" do
      expect(rows[:shots]).to eq([ { text: "5", colour: "black", mark: nil }, { text: "", colour: "none", mark: nil }, { text: "×", colour: "empty", mark: nil } ])
    end

    it "shows a don's check that is not the sheriff in the target's colour" do
      expect(rows[:don].first).to eq(text: "7", colour: "red", mark: nil)
    end

    it "shows the don checking his own mafia in black" do
      own = helper.overlay_night_rows([], [ { night: 1, kind: "don", target_seat: 3, result: "not_sheriff", team: "black" } ])

      expect(own[:don]).to eq([ { text: "3", colour: "black", mark: nil } ])
    end

    it "falls back to a neutral colour when the target's team is unknown" do
      unknown = helper.overlay_night_rows([], [ { night: 1, kind: "don", target_seat: 3, result: "not_sheriff", team: nil } ])

      expect(unknown[:don]).to eq([ { text: "3", colour: "neutral", mark: nil } ])
    end

    it "keeps each kind of check in its own row" do
      expect(rows.values_at(:don, :sheriff)).to eq([
        [ { text: "7", colour: "red", mark: nil }, { text: "", colour: "none", mark: nil }, { text: "", colour: "none", mark: nil } ],
        [ { text: "", colour: "none", mark: nil }, { text: "3", colour: "red", mark: nil }, { text: "", colour: "none", mark: nil } ]
      ])
    end

    it "shows a skipped check as a cross" do
      skipped = helper.overlay_night_rows([], [ { night: 1, kind: "sheriff", target_seat: nil, result: nil } ])

      expect(skipped[:sheriff]).to eq([ { text: "×", colour: "empty", mark: nil } ])
    end

    it "marks the don finding the sheriff" do
      found = helper.overlay_night_rows([], [ { night: 1, kind: "don", target_seat: 2, result: "sheriff" } ])

      expect(found[:don]).to eq([ { text: "2", colour: "red", mark: "sheriff" } ])
    end

    it "shows a shot with no team in a neutral colour" do
      expect(helper.overlay_night_rows([ { night: 1, target_seat: 5, team: nil } ], [])[:shots]).to eq([ { text: "5", colour: "neutral", mark: nil } ])
    end

    it "leaves the check rows empty with no checks" do
      expect(helper.overlay_night_rows(shots, []).values_at(:don, :sheriff)).to eq([ [], [] ])
    end

    it "has no nights with nothing recorded" do
      expect(helper.overlay_night_rows([], [])[:nights]).to eq(0)
    end
  end

  describe "#overlay_foul_pips" do
    it "gives a foul pip per foul and a tech mark per technical foul" do
      expect(helper.overlay_foul_pips({ fouls: 2, tech: 1 })).to eq(%w[foul foul tech])
    end

    it "gives nothing for a clean seat" do
      expect(helper.overlay_foul_pips(nil)).to eq([])
    end
  end
end
