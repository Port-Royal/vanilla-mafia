require "rails_helper"

# The club calls the person running the game «Судья», not «Ведущий» — in every grammatical form.
RSpec.describe "config/locales/ru.yml wording" do
  let(:strings) do
    flatten = lambda do |value|
      case value
      when Hash then value.values.flat_map(&flatten)
      when Array then value.flat_map(&flatten)
      else [ value.to_s ]
      end
    end
    flatten.call(YAML.load_file(Rails.root.join("config/locales/ru.yml")))
  end

  it "never calls the judge «ведущий»" do
    expect(strings.grep(/ведущ/i)).to be_empty
  end

  it "labels the judge fields «Судья»" do
    expect([ Game.human_attribute_name(:judge), GameBreakdown.human_attribute_name(:judge_name) ]).to all(eq("Судья"))
  end
end
