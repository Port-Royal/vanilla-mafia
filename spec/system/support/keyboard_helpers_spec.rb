require "rails_helper"

RSpec.describe KeyboardHelpers do
  let(:keydowns) { page.evaluate_script("window.keydowns") }

  before do
    visit root_path
    page.execute_script(<<~JS)
      window.keydowns = []
      document.addEventListener("keydown", (e) => window.keydowns.push([e.code, e.shiftKey, e.ctrlKey]))
    JS
  end

  context "with plain keys" do
    before { press_keys("1", "n", :return) }

    it "dispatches each key with its physical code" do
      expect(keydowns).to eq([ [ "Digit1", false, false ], [ "KeyN", false, false ], [ "Enter", false, false ] ])
    end
  end

  context "with a chord" do
    before { press_keys([ :shift, "d" ], [ :control, "z" ]) }

    it "holds the modifiers while the key goes down" do
      expect(keydowns).to eq([ [ "ShiftLeft", true, false ], [ "KeyD", true, false ], [ "ControlLeft", false, true ], [ "KeyZ", false, true ] ])
    end
  end
end
