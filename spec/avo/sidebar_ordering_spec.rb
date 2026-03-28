# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avo sidebar ordering" do
  let(:labels) do
    Avo::BaseResource.descendants
      .select { |r| r.visible_on_sidebar }
      .sort_by { |r| r.navigation_label }
      .map { |r| r.navigation_label }
  end

  it "hides join-table resources from sidebar" do
    hidden = Avo::BaseResource.descendants.reject { |r| r.visible_on_sidebar }

    expect(hidden).to include(
      Avo::Resources::GameParticipation,
      Avo::Resources::PlaylistEpisode,
      Avo::Resources::UserGrant
    )
  end

  it "keeps admin-managed resources visible" do
    visible = Avo::BaseResource.descendants.select { |r| r.visible_on_sidebar }

    expect(visible).to include(
      Avo::Resources::PlayerAward
    )
  end

  it "groups podcast resources together" do
    podcast_labels = labels.select { |l| l.start_with?("Podcast") }

    expect(podcast_labels.size).to eq(2)

    indices = podcast_labels.map { |l| labels.index(l) }
    expect(indices.max - indices.min).to eq(1)
  end

  it "puts settings at the end" do
    settings_idx = labels.index { |l| l.start_with?("Settings") }

    expect(settings_idx).to be > labels.index("Players")
    expect(settings_idx).to be > labels.index("Games")
  end

  it "shows competitions before players" do
    expect(labels.index("Competitions")).to be < labels.index("Players")
  end
end
