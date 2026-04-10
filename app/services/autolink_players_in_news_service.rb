require "set"

class AutolinkPlayersInNewsService
  FEATURE_KEY = "news_autolink_players".freeze

  def self.call(news)
    new(news).call
  end

  def initialize(news)
    @news = news
  end

  def call
    return unless FeatureToggle.enabled?(FEATURE_KEY)

    original_html = @news.content.body.to_html
    new_html = rewrite_html(original_html)
    return if new_html == original_html

    @news.update!(content: new_html)
  end

  private

  def rewrite_html(html)
    players = players_by_length_desc
    return html if players.empty?

    fragment = Nokogiri::HTML.fragment(html)
    linked_ids = Set.new
    fragment.traverse do |node|
      next unless node.text?
      next if inside_anchor?(node)

      link_matches_in_node(node, players, linked_ids)
    end
    fragment.to_html
  end

  def players_by_length_desc
    Player.pluck(:id, :name)
          .sort_by { |_id, name| -name.length }
          .map { |id, name| [ id, Regexp.new("(?<!\\p{L})#{Regexp.escape(name)}(?!\\p{L})", Regexp::IGNORECASE) ] }
  end

  def link_matches_in_node(text_node, players, linked_ids)
    text = text_node.content
    matches = collect_matches(text, players, linked_ids)
    return if matches.empty?

    replace_node_with_matches(text_node, text, matches)
    matches.each { |_start, _finish, id, _matched| linked_ids << id }
  end

  def collect_matches(text, players, linked_ids)
    raw = players.filter_map do |id, regex|
      next if linked_ids.include?(id)

      match = regex.match(text)
      next unless match

      [ match.begin(0), match.end(0), id, match[0] ]
    end
    drop_overlaps(raw.sort_by { |start, finish, _id, _matched| [ start, -(finish - start) ] })
  end

  def drop_overlaps(matches)
    result = []
    last_end = 0
    matches.each do |match|
      start, finish, _id, _matched = match
      next if start < last_end

      result << match
      last_end = finish
    end
    result
  end

  def replace_node_with_matches(text_node, text, matches)
    doc = text_node.document
    cursor = matches.reduce(0) do |pos, (start, finish, id, matched)|
      text_node.add_previous_sibling(doc.create_text_node(text[pos...start]))
      text_node.add_previous_sibling(build_anchor(doc, id, matched))
      finish
    end
    text_node.add_previous_sibling(doc.create_text_node(text[cursor..]))
    text_node.remove
  end

  def build_anchor(doc, id, matched)
    anchor = Nokogiri::XML::Node.new("a", doc)
    anchor["href"] = "/players/#{id}"
    anchor.add_child(doc.create_text_node(matched))
    anchor
  end

  def inside_anchor?(node)
    node.ancestors.any? { |ancestor| ancestor.name == "a" }
  end
end
