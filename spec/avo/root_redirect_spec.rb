# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avo root redirect" do
  it "sets home_path to games resource" do
    expect(Avo.configuration.home_path).to eq("/avo/resources/games")
  end
end
