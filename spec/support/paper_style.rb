# The redesign draws every in-shell screen with the warm-paper tokens and the vm-* components. OLD_PALETTE matches the
# in-page colours it replaced: maroon and any of Tailwind's stock palettes with a shade (gray-100, red-600, ...). The
# paper tokens (ink, gold, line, alert-ink, ...) carry no shade, so they never match.
module PaperStyle
  STOCK_PALETTES = %w[
    slate gray zinc neutral stone red orange amber yellow lime green emerald teal cyan sky blue indigo violet purple
    fuchsia pink rose
  ].freeze

  OLD_PALETTE = /maroon|-(?:#{STOCK_PALETTES.join("|")})-\d{2,3}\b/

  # The flash notice is a vm-panel on every page; it says nothing about the page's own markup.
  FOUNDATION = ".vm-panel:not([role]), .vm-table, .vm-btn".freeze
end

RSpec.shared_examples "a page in the paper style" do
  let(:paper_main) { Nokogiri::HTML(response.body).at_css("main#site-main") }

  it "draws with the foundation components" do
    expect(paper_main.css(PaperStyle::FOUNDATION)).not_to be_empty
  end

  it "keeps none of the old palette" do
    expect(paper_main.to_html.scan(PaperStyle::OLD_PALETTE).uniq).to be_empty
  end
end
