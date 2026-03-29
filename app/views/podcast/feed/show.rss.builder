xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0",
        "xmlns:itunes" => "http://www.itunes.apple.com/dtds/podcast-1.0.dtd",
        "xmlns:content" => "http://purl.org/rss/1.0/modules/content/" do
  xml.channel do
    xml.title @podcast.title
    xml.description @podcast.description
    xml.language @podcast.language
    xml.tag! "itunes:author", @podcast.author
    xml.tag! "itunes:summary", @podcast.description
    xml.tag! "itunes:explicit", "no"

    if @podcast.category.present?
      xml.tag! "itunes:category", text: @podcast.category
    end

    if @podcast.cover.attached?
      xml.tag! "itunes:image", href: url_for(@podcast.cover)
    end

    @episodes.each do |episode|
      xml.item do
        xml.title episode.title
        xml.description episode.description if episode.description.present?
        xml.pubDate episode.published_at.rfc2822
        xml.guid({ isPermaLink: "false" }, "episode-#{episode.id}")

        if episode.audio.attached?
          xml.enclosure url: url_for(episode.audio),
                        length: episode.audio.byte_size,
                        type: episode.audio.content_type
        end
      end
    end
  end
end
