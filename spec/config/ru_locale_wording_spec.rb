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

  it "names a sheriff's voiced check «Проверка в стол»" do
    expect(I18n.t("game_breakdowns.move_kinds.check_claim", locale: :ru)).to eq("Проверка в стол")
  end

  it "names a broken vote «Слом голосования»" do
    expect(I18n.t("game_breakdowns.move_kinds.split_break", locale: :ru)).to eq("Слом голосования")
  end

  it "names the sheriff's table reveal «Вскрытие в стол»" do
    expect(I18n.t("game_breakdowns.move_kinds.sheriff_reveal_table", locale: :ru)).to eq("Вскрытие в стол")
  end

  it "labels the judge fields «Судья»" do
    expect([ Game.human_attribute_name(:judge), GameBreakdown.human_attribute_name(:judge_name) ]).to all(eq("Судья"))
  end
end
