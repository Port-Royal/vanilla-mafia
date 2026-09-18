require "rails_helper"

RSpec.describe GameBreakdownsHelper do
  include GameBreakdownHelpers

  describe "#breakdown_result_label" do
    it "translates a known result" do
      expect(helper.breakdown_result_label("city")).to eq(I18n.t("game_breakdowns.results.city"))
    end

    it "falls back to the unknown label for nil" do
      expect(helper.breakdown_result_label(nil)).to eq(I18n.t("game_breakdowns.results.unknown"))
    end

    it "falls back to the unknown label for a blank string" do
      expect(helper.breakdown_result_label("")).to eq(I18n.t("game_breakdowns.results.unknown"))
    end
  end

  describe "#breakdown_seat_names" do
    let(:breakdown) { create(:game_breakdown) }

    before { breakdown.seats.find_by(number: 2).update!(name: "Гость") }

    it "maps every seat number to its name" do
      expect(helper.breakdown_seat_names(breakdown)).to include(1 => nil, 2 => "Гость")
    end

    it "covers all ten seats" do
      expect(helper.breakdown_seat_names(breakdown).keys).to eq((1..10).to_a)
    end
  end

  describe "#breakdown_seat_label" do
    it "appends the name when present" do
      expect(helper.breakdown_seat_label({ 3 => "Гость" }, 3)).to eq("3 — Гость")
    end

    it "returns the bare number when the name is blank" do
      expect(helper.breakdown_seat_label({ 3 => "" }, 3)).to eq("3")
    end

    it "returns the bare number when the seat is unknown" do
      expect(helper.breakdown_seat_label({}, 3)).to eq("3")
    end
  end
  describe "#breakdown_move_defaults" do
    let(:breakdown) { create(:game_breakdown) }
    let(:phase) { breakdown.phases.find_by(position: 0) }
    let(:state) { GameBreakdown::Timeline.new(breakdown).state_for(phase) }
    let(:speech) { create(:breakdown_speech, breakdown_phase: phase, speaker_seat: 6) }

    it "starts a move as a plain comment" do
      expect(helper.breakdown_move_defaults(speech, state)[:kind]).to eq("other")
    end

    it "credits the move to the speaker" do
      expect(helper.breakdown_move_defaults(speech, state)[:actor_seat]).to eq(6)
    end

    it "leaves the night blank in the zero round" do
      expect(helper.breakdown_move_defaults(speech, state)[:night_number]).to be_nil
    end

    context "on a later day" do
      let!(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }
      let(:phase) { create(:breakdown_phase, game_breakdown: breakdown, position: 4) }

      before { create(:breakdown_phase, game_breakdown: breakdown, position: 2) }

      it "dates the move to the last passed night" do
        create(:breakdown_phase, game_breakdown: breakdown, position: 3, night_outcome: "miss")

        expect(helper.breakdown_move_defaults(speech, state)[:night_number]).to eq(2)
      end
    end
  end

  describe "#breakdown_move_summary" do
    let(:seat_names) { { 4 => "Гость" } }

    it "names the kind" do
      move = build(:breakdown_move, :sheriff_reveal_table, actor_seat: 1, text: nil)
      expect(helper.breakdown_move_summary(move, seat_names)).to eq(I18n.t("game_breakdowns.move_kinds.sheriff_reveal_table"))
    end

    it "appends the details after the kind" do
      move = build(:breakdown_move, :nomination, actor_seat: 1, target_seat: 4, text: nil)

      expect(helper.breakdown_move_summary(move, seat_names))
        .to eq("#{I18n.t('game_breakdowns.move_kinds.nomination')} · 4 — Гость")
    end
  end

  describe "#breakdown_move_details" do
    let(:seat_names) { { 4 => "Гость" } }

    it "is blank when the move carries nothing extra" do
      expect(helper.breakdown_move_details(build(:breakdown_move, :sheriff_reveal_table, actor_seat: 1, text: nil), seat_names)).to eq("")
    end

    it "names the target seat" do
      move = build(:breakdown_move, :nomination, actor_seat: 1, target_seat: 4, text: nil)
      expect(helper.breakdown_move_details(move, seat_names)).to eq("4 — Гость")
    end

    it "names the claimed colour and the night" do
      move = build(:breakdown_move, :check_claim, actor_seat: 1, target_seat: nil, claimed_color: "red", night_number: 2, text: nil)

      expect(helper.breakdown_move_details(move, seat_names))
        .to eq("#{I18n.t('game_breakdowns.claimed_colors.red')} · #{I18n.t('game_breakdowns.editor.night_number', number: 2)}")
    end

    it "lists the best move seats" do
      move = build(:breakdown_move, :best_move, actor_seat: 1, best_move_seats: [ 2, 4 ], text: nil)
      expect(helper.breakdown_move_details(move, seat_names)).to eq("2, 4")
    end

    it "names the removal reason" do
      move = build(:breakdown_move, :removal, actor_seat: 1, removal_reason: "fouls", text: nil)
      expect(helper.breakdown_move_details(move, seat_names)).to eq(I18n.t("game_breakdowns.removal_reasons.fouls"))
    end

    it "skips an empty comment" do
      move = build(:breakdown_move, :nomination, actor_seat: 1, target_seat: 4, text: "")
      expect(helper.breakdown_move_details(move, seat_names)).to eq("4 — Гость")
    end

    it "includes the comment" do
      move = build(:breakdown_move, actor_seat: 1, kind: "other", text: "шумел")
      expect(helper.breakdown_move_details(move, seat_names)).to eq("шумел")
    end
  end

  describe "#breakdown_tally_label" do
    let(:breakdown) { create(:game_breakdown) }
    let(:phase) { breakdown.phases.find_by(position: 0) }

    it "names the seat for a candidate round" do
      round = create(:breakdown_vote_round, breakdown_phase: phase, kind: "main", number: 1)
      expect(helper.breakdown_tally_label(round, 4, { 4 => "Гость" })).to eq("4 — Гость")
    end

    it "names the bucket for a lift round" do
      round = create(:breakdown_vote_round, breakdown_phase: phase, kind: "lift", number: 1)
      expect(helper.breakdown_tally_label(round, :for, {})).to eq(I18n.t("game_breakdowns.lift_choices.for"))
    end
  end

  describe "#breakdown_vote_value" do
    let(:breakdown) { create(:game_breakdown) }
    let(:zero_round) { breakdown.phases.find_by(position: 0) }
    let(:result) { GameBreakdown::Timeline.new(breakdown).state_for(zero_round).vote_rounds.first }

    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      round
    end

    let(:round) { create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "main", number: 1) }

    before { create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 1, candidate_seat: 4) }

    it "returns the stored choice" do
      expect(helper.breakdown_vote_value(result, 1)).to eq(4)
    end

    # 4.4.9: a player who did not vote is counted for the last nominee.
    it "falls back to the last nominee" do
      expect(helper.breakdown_vote_value(result, 3)).to eq(5)
    end
  end

  describe "#breakdown_lift_value" do
    let(:breakdown) { create(:game_breakdown) }
    let(:zero_round) { breakdown.phases.find_by(position: 0) }
    let(:result) { GameBreakdown::Timeline.new(breakdown).state_for(zero_round).vote_rounds.first }

    before do
      nominate(zero_round, 1, 4)
      nominate(zero_round, 2, 5)
      round
    end

    let(:round) { create(:breakdown_vote_round, breakdown_phase: zero_round, kind: "lift", number: 1) }

    before { create(:breakdown_vote, breakdown_vote_round: round, voter_seat: 2, candidate_seat: nil, for_lift: false) }

    it "returns the stored choice as a string" do
      expect(helper.breakdown_lift_value(result, 2)).to eq("false")
    end

    it "is blank for a voter who did not vote" do
      expect(helper.breakdown_lift_value(result, 3)).to be_nil
    end
  end

  describe "#breakdown_lift_options" do
    it "offers for and against" do
      expect(helper.breakdown_lift_options).to eq(
        [ [ I18n.t("game_breakdowns.lift_choices.for"), "true" ], [ I18n.t("game_breakdowns.lift_choices.against"), "false" ] ]
      )
    end
  end

  describe "#breakdown_role_seats" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    before do
      { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
        .each { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
      breakdown.seats.update_all(role_code: "peace")
      breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
      breakdown.seats.where(number: 4).update_all(role_code: "don")
      breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
    end

    it "groups the seat numbers by role" do
      expect(helper.breakdown_role_seats(breakdown)).to include("mafia" => [ 2, 3 ], "don" => [ 4 ], "sheriff" => [ 5 ])
    end

    it "groups the unassigned seats under nil" do
      breakdown.seats.where(number: 6).update_all(role_code: nil)
      expect(helper.breakdown_role_seats(breakdown)[nil]).to eq([ 6 ])
    end
  end

  describe "#breakdown_shooter_seats" do
    # The don sits before the mafia, so the result is only in seat order if the helper sorts it.
    let(:role_seats) { { "mafia" => [ 3, 6 ], "don" => [ 1 ], "sheriff" => [ 5 ], "peace" => [ 2, 4, 7, 8, 9, 10 ] } }
    let(:alive) { (1..10).to_a }

    it "lists the mafia and the don in seat order" do
      expect(helper.breakdown_shooter_seats(role_seats, alive)).to eq([ 1, 3, 6 ])
    end

    context "when a shooter is no longer in the game" do
      let(:alive) { (1..10).to_a - [ 3 ] }

      it "leaves them out" do
        expect(helper.breakdown_shooter_seats(role_seats, alive)).to eq([ 1, 6 ])
      end
    end

    context "when only the don is assigned" do
      let(:role_seats) { { "don" => [ 1 ] } }

      it "lists the don alone" do
        expect(helper.breakdown_shooter_seats(role_seats, alive)).to eq([ 1 ])
      end
    end

    context "when no black roles are set" do
      let(:role_seats) { { "peace" => (1..10).to_a } }

      it "is empty" do
        expect(helper.breakdown_shooter_seats(role_seats, alive)).to be_empty
      end
    end
  end

  describe "#breakdown_checker_seat" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    before do
      { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
        .each { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
      breakdown.seats.update_all(role_code: "peace")
      breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
      breakdown.seats.where(number: 4).update_all(role_code: "don")
      breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
    end

    let(:role_seats) { helper.breakdown_role_seats(breakdown) }

    it "finds the seat holding the role" do
      expect(helper.breakdown_checker_seat(role_seats, "sheriff", (1..10).to_a)).to eq(5)
    end

    it "is blank once that seat has left the game" do
      expect(helper.breakdown_checker_seat(role_seats, "sheriff", (1..10).to_a - [ 5 ])).to be_nil
    end

    it "is blank when the role is not assigned" do
      breakdown.seats.where(number: 5).update_all(role_code: "peace")
      expect(helper.breakdown_checker_seat(helper.breakdown_role_seats(breakdown), "sheriff", (1..10).to_a)).to be_nil
    end
  end

  describe "#breakdown_check_result" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    before do
      { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
        .each { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
      breakdown.seats.update_all(role_code: "peace")
      breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
      breakdown.seats.where(number: 4).update_all(role_code: "don")
      breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
    end

    it "tells the don that the target is the sheriff" do
      expect(helper.breakdown_check_result("don_check", "sheriff")).to eq(I18n.t("game_breakdowns.check_results.sheriff"))
    end

    it "tells the don that the target is not the sheriff" do
      expect(helper.breakdown_check_result("don_check", "mafia")).to eq(I18n.t("game_breakdowns.check_results.not_sheriff"))
    end

    it "tells the sheriff that a mafia target is black" do
      expect(helper.breakdown_check_result("sheriff_check", "mafia")).to eq(I18n.t("game_breakdowns.check_results.black"))
    end

    it "tells the sheriff that the don is black" do
      expect(helper.breakdown_check_result("sheriff_check", "don")).to eq(I18n.t("game_breakdowns.check_results.black"))
    end

    it "tells the sheriff that a peaceful target is red" do
      expect(helper.breakdown_check_result("sheriff_check", "peace")).to eq(I18n.t("game_breakdowns.check_results.red"))
    end

    it "tells the sheriff that another sheriff claim is red" do
      expect(helper.breakdown_check_result("sheriff_check", "sheriff")).to eq(I18n.t("game_breakdowns.check_results.red"))
    end

    it "derives nothing when the target has no role" do
      expect(helper.breakdown_check_result("sheriff_check", nil)).to be_nil
    end
  end

  describe "#breakdown_night_action" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    before do
      { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
        .each { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
      breakdown.seats.update_all(role_code: "peace")
      breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
      breakdown.seats.where(number: 4).update_all(role_code: "don")
      breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
    end

    let!(:shot) { create(:breakdown_night_action, breakdown_phase: night, kind: "mafia_shot", actor_seat: 2, target_seat: 7) }
    let!(:check) { create(:breakdown_night_action, breakdown_phase: night, kind: "don_check", actor_seat: nil, target_seat: 5) }

    it "finds a shot by its shooter" do
      expect(helper.breakdown_night_action(night.night_actions.to_a, "mafia_shot", 2)).to eq(shot)
    end

    it "finds a check by its kind" do
      expect(helper.breakdown_night_action(night.night_actions.to_a, "don_check", nil)).to eq(check)
    end

    it "does not confuse a shot with a check" do
      expect(helper.breakdown_night_action(night.night_actions.to_a, "mafia_shot", nil)).to be_nil
    end

    it "is blank for a shooter with nothing recorded" do
      expect(helper.breakdown_night_action(night.night_actions.to_a, "mafia_shot", 3)).to be_nil
    end
  end

  describe "#breakdown_check_target" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    before do
      { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
        .each { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
      breakdown.seats.update_all(role_code: "peace")
      breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
      breakdown.seats.where(number: 4).update_all(role_code: "don")
      breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
    end

    it "returns the checked seat" do
      action = build(:breakdown_night_action, kind: "don_check", actor_seat: nil, target_seat: 5)
      expect(helper.breakdown_check_target(action)).to eq(5)
    end

    it "is blank when nothing was recorded" do
      expect(helper.breakdown_check_target(nil)).to be_nil
    end
  end

  describe "#breakdown_shot_value" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "miss") }

    before do
      { "peace" => "Мирный", "mafia" => "Мафия", "don" => "Дон", "sheriff" => "Шериф" }
        .each { |code, name| Role.find_or_create_by!(code: code) { |role| role.name = name } }
      breakdown.seats.update_all(role_code: "peace")
      breakdown.seats.where(number: [ 2, 3 ]).update_all(role_code: "mafia")
      breakdown.seats.where(number: 4).update_all(role_code: "don")
      breakdown.seats.where(number: 5).update_all(role_code: "sheriff")
    end

    it "returns the target as the select value" do
      action = build(:breakdown_night_action, kind: "mafia_shot", actor_seat: 2, target_seat: 7)
      expect(helper.breakdown_shot_value(action)).to eq("7")
    end

    it "marks a recorded miss as the did-not-shoot choice" do
      action = build(:breakdown_night_action, kind: "mafia_shot", actor_seat: 2, target_seat: nil)
      expect(helper.breakdown_shot_value(action)).to eq(SaveBreakdownNightService::NO_SHOT)
    end

    it "is blank when nothing was recorded" do
      expect(helper.breakdown_shot_value(nil)).to be_nil
    end
  end

  describe "#breakdown_view_metadata" do
    subject(:metadata) { helper.breakdown_view_metadata(breakdown) }

    let(:game) { build_stubbed(:game, slug: "cup-game-1") }
    let(:author) { build_stubbed(:user, email: "judge@example.com") }

    def label(attribute)
      GameBreakdown.human_attribute_name(attribute)
    end

    context "when every field is filled in" do
      let(:breakdown) do
        build_stubbed(:game_breakdown, author: author, game: game, played_on: Date.new(2026, 9, 14), source: "Кубок",
                                       video_url: "https://example.com/v", judge_name: "Иванов", roles_mode: "closed")
      end

      it "lists every field in order with its value" do
        expect(metadata).to eq([
          [ label(:played_on), Date.new(2026, 9, 14) ],
          [ label(:source), "Кубок" ],
          [ label(:video_url), helper.breakdown_video_link(breakdown) ],
          [ label(:judge_name), "Иванов" ],
          [ label(:roles_mode), I18n.t("game_breakdowns.roles_modes.closed") ],
          [ label(:game_id), helper.breakdown_game_link(breakdown) ],
          [ label(:author), "judge@example.com" ]
        ])
      end
    end

    context "when nothing optional was filled in" do
      let(:breakdown) { build_stubbed(:game_breakdown, author: author, source: "", judge_name: "") }

      it "dashes out every blank field" do
        expect(metadata.to_h.values_at(label(:played_on), label(:source), label(:video_url), label(:judge_name), label(:game_id)))
          .to eq([ "—" ] * 5)
      end
    end
  end

  describe "#breakdown_video_link" do
    subject(:link) { helper.breakdown_video_link(breakdown) }

    let(:breakdown) { build_stubbed(:game_breakdown, video_url: video_url) }

    def link_markup(url)
      %(<a target="_blank" rel="noopener noreferrer" class="text-maroon hover:underline" href="#{url}">#{url}</a>)
    end

    context "with an https address" do
      let(:video_url) { "https://example.com/v" }

      it "links it in a new tab without leaking the referrer" do
        expect(link).to eq(link_markup(video_url))
      end
    end

    context "with an http address" do
      let(:video_url) { "http://example.com/v" }

      it "links it" do
        expect(link).to eq(link_markup(video_url))
      end
    end

    # A judge pasting an address from a browser may well capitalise the scheme.
    context "with an uppercase scheme" do
      let(:video_url) { "HTTPS://example.com/v" }

      it "links it" do
        expect(link).to eq(link_markup(video_url))
      end
    end

    # The URL is free text a judge typed, so it must never become a scripted href.
    context "with a javascript url" do
      let(:video_url) { "javascript:alert(1)" }

      it "returns it as plain text" do
        expect(link).to eq("javascript:alert(1)")
      end
    end

    context "with an address that only appears inside the text" do
      let(:video_url) { "see https://example.com/v" }

      it "returns it as plain text" do
        expect(link).to eq("see https://example.com/v")
      end
    end

    context "with a scheme missing its slashes" do
      let(:video_url) { "https:example.com/v" }

      it "returns it as plain text" do
        expect(link).to eq("https:example.com/v")
      end
    end

    context "without a url" do
      let(:video_url) { nil }

      it "dashes it out" do
        expect(link).to eq("—")
      end
    end

    context "with a whitespace-only url" do
      let(:video_url) { "  " }

      it "dashes it out" do
        expect(link).to eq("—")
      end
    end
  end

  describe "#breakdown_game_link" do
    subject(:link) { helper.breakdown_game_link(breakdown) }

    let(:breakdown) { build_stubbed(:game_breakdown, game: game) }

    context "without a linked game" do
      let(:game) { nil }

      it "dashes it out" do
        expect(link).to eq("—")
      end
    end

    context "with a linked game" do
      let(:game) { build_stubbed(:game, slug: "cup-game-1") }

      it "links the club game by its full name" do
        expect(link).to eq(%(<a class="text-maroon hover:underline" href="#{game_path(game)}">#{game.full_name}</a>))
      end
    end
  end

  describe "#breakdown_roles_by_seat" do
    let(:breakdown) { create(:game_breakdown, played_on: Date.new(2026, 9, 14), source: "Кубок", judge_name: "Иванов") }

    it "maps every seat to its role" do
      Role.find_or_create_by!(code: "don") { |role| role.name = "Дон" }
      breakdown.seats.where(number: 4).update_all(role_code: "don")

      expect(helper.breakdown_roles_by_seat(breakdown)).to include(4 => "don", 1 => nil)
    end
  end


  describe "#breakdown_night_outcome_summary" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "kill", killed_seat: 4) }
    let(:seat_names) { { 4 => "Гость" } }
    let(:roles_by_seat) { { 2 => "mafia", 7 => "peace" } }

    it "names the killed seat" do
      expect(helper.breakdown_night_outcome_summary(night, seat_names))
        .to eq(I18n.t("game_breakdowns.view.killed", seat: "4 — Гость"))
    end

    it "names a miss" do
      night.update!(night_outcome: "miss", killed_seat: nil)
      expect(helper.breakdown_night_outcome_summary(night, seat_names)).to eq(I18n.t("game_breakdowns.night_outcomes.miss"))
    end

    it "says when nothing was recorded" do
      night.update!(night_outcome: nil, killed_seat: nil)
      expect(helper.breakdown_night_outcome_summary(night, seat_names)).to eq(I18n.t("game_breakdowns.editor.not_recorded"))
    end
  end

  describe "#breakdown_shot_summary" do
    let(:breakdown) { create(:game_breakdown, roles_mode: "open") }
    let(:night) { create(:breakdown_phase, game_breakdown: breakdown, position: 1, night_outcome: "kill", killed_seat: 4) }
    let(:seat_names) { { 4 => "Гость" } }
    let(:roles_by_seat) { { 2 => "mafia", 7 => "peace" } }

    it "names shooter and target" do
      action = build(:breakdown_night_action, kind: "mafia_shot", actor_seat: 2, target_seat: 7)
      expect(helper.breakdown_shot_summary(action, seat_names)).to eq(I18n.t("game_breakdowns.view.shot", actor: 2, target: "7"))
    end

    it "reports a shooter who held fire" do
      action = build(:breakdown_night_action, kind: "mafia_shot", actor_seat: 2, target_seat: nil)
      expect(helper.breakdown_shot_summary(action, seat_names)).to eq(I18n.t("game_breakdowns.view.no_shot", actor: 2))
    end
  end

  describe "#breakdown_night_action_summary" do
    subject(:summary) { helper.breakdown_night_action_summary(action, seat_names, roles_by_seat) }

    let(:seat_names) { { 2 => "Кот", 5 => "Лис", 7 => "Гость" } }
    let(:roles_by_seat) { { 2 => "mafia", 5 => "sheriff", 7 => "peace" } }

    context "with a shot" do
      let(:action) { build(:breakdown_night_action, breakdown_phase: nil, kind: "mafia_shot", actor_seat: 2, target_seat: 7) }

      it "names the shooter and the target" do
        expect(summary).to eq(I18n.t("game_breakdowns.view.shot", actor: 2, target: "7 — Гость"))
      end
    end

    context "with a sheriff check" do
      let(:action) { build(:breakdown_night_action, breakdown_phase: nil, kind: "sheriff_check", actor_seat: nil, target_seat: 2) }

      it "names the target and derives red or black from their role" do
        expect(summary).to eq(I18n.t("game_breakdowns.view.check",
                                     role: I18n.t("game_breakdowns.view.sheriff_check"),
                                     seat: "2 — Кот",
                                     result: I18n.t("game_breakdowns.check_results.black")))
      end
    end

    context "with a don check" do
      let(:action) { build(:breakdown_night_action, breakdown_phase: nil, kind: "don_check", actor_seat: nil, target_seat: 5) }

      it "names the target and derives sheriff or not from their role" do
        expect(summary).to eq(I18n.t("game_breakdowns.view.check",
                                     role: I18n.t("game_breakdowns.view.don_check"),
                                     seat: "5 — Лис",
                                     result: I18n.t("game_breakdowns.check_results.sheriff")))
      end
    end

    context "when the target's role is not known" do
      let(:action) { build(:breakdown_night_action, breakdown_phase: nil, kind: "sheriff_check", actor_seat: nil, target_seat: 2) }
      let(:roles_by_seat) { {} }

      it "leaves the result empty" do
        expect(summary).to eq(I18n.t("game_breakdowns.view.check",
                                     role: I18n.t("game_breakdowns.view.sheriff_check"), seat: "2 — Кот", result: nil))
      end
    end
  end

  describe "#breakdown_night_summary" do
    subject(:summary) { helper.breakdown_night_summary(night, seat_names, roles_by_seat) }

    let(:night) do
      build(:breakdown_phase, :night, position: 1, night_outcome: "kill", killed_seat: 4, night_actions: actions)
    end
    let(:seat_names) { { 2 => "Кот", 4 => "Гость", 7 => "Лис" } }
    let(:roles_by_seat) { { 2 => "mafia", 7 => "peace" } }

    context "with recorded actions" do
      let(:actions) do
        [
          build(:breakdown_night_action, breakdown_phase: nil, kind: "sheriff_check", actor_seat: nil, target_seat: 2),
          build(:breakdown_night_action, breakdown_phase: nil, kind: "mafia_shot", actor_seat: 2, target_seat: 7)
        ]
      end

      it "opens with the outcome and summarises each action in order" do
        expect(summary).to eq([
          I18n.t("game_breakdowns.view.killed", seat: "4 — Гость"),
          I18n.t("game_breakdowns.view.check", role: I18n.t("game_breakdowns.view.sheriff_check"),
                                               seat: "2 — Кот", result: I18n.t("game_breakdowns.check_results.black")),
          I18n.t("game_breakdowns.view.shot", actor: 2, target: "7 — Лис")
        ])
      end
    end

    context "when nothing was recorded inside the night" do
      let(:actions) { [] }

      it "is just the outcome" do
        expect(summary).to eq([ I18n.t("game_breakdowns.view.killed", seat: "4 — Гость") ])
      end
    end
  end
end
