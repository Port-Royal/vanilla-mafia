# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Position field prefill" do
  def position_field_for(resource_class, record)
    resource = resource_class.new(record: record, view: :new)
    resource.detect_fields
    resource.items.find { |f| f.id == :position }
  end

  describe "Award" do
    let(:field) { position_field_for(Avo::Resources::Award, Award.new) }

    it "defaults to 1 when no records exist" do
      expect(field.default).to be_a(Proc)
      expect(field.default.call).to eq(1)
    end

    it "defaults to MAX+1 when records exist" do
      create(:award, position: 5)

      expect(field.default.call).to eq(6)
    end
  end

  describe "Competition" do
    let(:field) { position_field_for(Avo::Resources::Competition, Competition.new) }

    it "defaults to MAX+1" do
      create(:competition, :season, position: 3)

      expect(field.default).to be_a(Proc)
      expect(field.default.call).to eq(4)
    end
  end

  describe "PlayerAward" do
    let(:field) { position_field_for(Avo::Resources::PlayerAward, PlayerAward.new) }

    it "defaults to MAX+1" do
      player = create(:player)
      award = create(:award, position: 1)
      create(:player_award, player: player, award: award, position: 7)

      expect(field.default).to be_a(Proc)
      expect(field.default.call).to eq(8)
    end
  end

  describe "PlaylistEpisode" do
    let(:field) { position_field_for(Avo::Resources::PlaylistEpisode, PlaylistEpisode.new) }

    it "defaults to MAX+1" do
      playlist = create(:playlist)
      episode = create(:episode)
      create(:playlist_episode, playlist: playlist, episode: episode, position: 4)

      expect(field.default).to be_a(Proc)
      expect(field.default.call).to eq(5)
    end
  end
end
