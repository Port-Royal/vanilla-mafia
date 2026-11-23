# The redesign draws every in-shell screen with the warm-paper tokens and the vm-* components. OLD_PALETTE matches the
# in-page colours it replaced: maroon and Tailwind's stock greys, blues, greens, yellows and reds.
module PaperStyle
  OLD_PALETTE = /maroon|-(?:neutral|gray|blue|green|yellow|red|amber|emerald)-\d{2,3}\b/

  # Markup whose classes a Stimulus controller owns: the player suggestions template (player_select_controller.js
  # marks the active option) and the autosave toggle and status (protocol_autosave_controller.js).
  JS_STYLED = "template, [data-protocol-autosave-target]".freeze
end

RSpec.shared_examples "a page in the paper style" do
  let(:paper_main) do
    Nokogiri::HTML(response.body).at_css("main#site-main").tap do |main|
      main.css(PaperStyle::JS_STYLED).each(&:remove)
    end
  end

  it "draws with the foundation components" do
    expect(paper_main.css(".vm-panel, .vm-table, .vm-btn")).not_to be_empty
  end

  it "keeps none of the old palette" do
    expect(paper_main.to_html.scan(PaperStyle::OLD_PALETTE).uniq).to be_empty
  end
end
