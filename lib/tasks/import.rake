require "base64"
require "stringio"
require_relative "../scraper/base"
require_relative "../scraper/season_scraper"
require_relative "../scraper/game_scraper"
require_relative "../scraper/hall_scraper"
require_relative "../scraper/player_scraper"

namespace :import do
  desc "Import all data from chimafia.org"
  task scrape: :environment do
    puts "=== Starting import from chimafia.org ==="
    puts

    # Ensure roles exist
    Rake::Task["db:seed"].invoke

    game_index = phase1_scrape_seasons
    player_ids = phase2_scrape_games(game_index)
    phase3_scrape_hall
    phase4_scrape_players(player_ids)
    phase5_reset_sequences
    phase6_verify

    puts
    puts "=== Import complete ==="
  end
end

def phase1_scrape_seasons
  puts "--- Phase 1: Scraping seasons ---"
  scraper = Scraper::SeasonScraper.new
  seasons = parse_seasons(ENV["SEASONS"])
  games = scraper.scrape_all(seasons:)
  puts "Total games discovered: #{games.size}"
  puts
  games
end

def phase2_scrape_games(game_index)
  puts "--- Phase 2: Scraping games ---"
  scraper = Scraper::GameScraper.new
  player_ids = Set.new
  errors = []

  game_index.each_with_index do |game_info, idx|
    print "\rScraping game #{idx + 1}/#{game_index.size} (ID: #{game_info[:id]})..."

    result = scraper.scrape(game_info)
    unless result
      errors << game_info[:id]
      next
    end

    ActiveRecord::Base.transaction do
      create_game(result[:game])
      result[:game_participations].each do |participation_data|
        player_ids << participation_data[:player_id]
        create_player_and_participation(result[:game][:id], participation_data)
      end
    end
  end

  puts
  puts "Games scraped: #{game_index.size - errors.size}, errors: #{errors.size}"
  puts "Errors on game IDs: #{errors.join(', ')}" if errors.any?
  puts "Unique players discovered: #{player_ids.size}"
  puts
  player_ids
end

def phase3_scrape_hall
  puts "--- Phase 3: Scraping hall of fame ---"
  scraper = Scraper::HallScraper.new
  hall_data = scraper.scrape

  ActiveRecord::Base.transaction do
    # Create award definitions
    hall_data[:awards].each do |award_data|
      award = Award.find_or_initialize_by(title: award_data[:title], staff: false)
      award.description = award_data[:description]
      award.position = award_data[:position]
      award.save!
    end

    # Create staff award definitions and assign
    hall_data[:staff_awards].each do |sa|
      award = Award.find_or_initialize_by(title: sa[:award_title], staff: true)
      award.save!

      player = Player.find_by(id: sa[:player_id])
      next unless player

      PlayerAward.find_or_initialize_by(
        player: player,
        award: award,
        season: nil
      ).save!
    end

    # Assign player awards
    hall_data[:player_awards].each do |pa|
      award = Award.find_by(title: pa[:award_title], staff: false)
      unless award
        puts "WARNING: Award not found: #{pa[:award_title]}"
        next
      end

      player = Player.find_by(id: pa[:player_id])
      unless player
        puts "WARNING: Player not found: #{pa[:player_id]}"
        next
      end

      PlayerAward.find_or_initialize_by(
        player: player,
        award: award,
        season: pa[:season]
      ).save!
    end
  end

  # Attach icons outside the transaction to avoid holding DB locks during file I/O
  hall_data[:awards].each do |award_data|
    next unless award_data[:icon_data]

    award = Award.find_by(title: award_data[:title], staff: false)
    attach_icon(award, award_data[:icon_data]) if award && !award.icon.attached?
  end

  puts "Awards created: #{Award.count}"
  puts "Player awards assigned: #{PlayerAward.count}"
  puts
end

def phase4_scrape_players(player_ids)
  puts "--- Phase 4: Scraping player photos ---"
  scraper = Scraper::PlayerScraper.new
  attached = 0

  player_ids.each_with_index do |player_id, idx|
    print "\rScraping player #{idx + 1}/#{player_ids.size} (ID: #{player_id})..."

    player = Player.find_by(id: player_id)
    next unless player
    next if player.photo.attached?

    photo = scraper.scrape(player_id)
    next unless photo

    player.photo.attach(
      io: StringIO.new(photo[:data]),
      filename: "player_#{player_id}.jpg",
      content_type: photo[:content_type]
    )
    attached += 1
  end

  puts
  puts "Photos attached: #{attached}"
  puts
end

def phase5_reset_sequences
  puts "--- Phase 5: Resetting SQLite sequences ---"
  conn = ActiveRecord::Base.connection
  [ Game, Player ].each do |model|
    table = model.table_name
    max_id = model.maximum(:id) || 0
    conn.execute(
      "UPDATE sqlite_sequence SET seq = #{conn.quote(max_id)} WHERE name = #{conn.quote(table)}"
    )
    puts "Reset #{table} sequence to #{max_id}"
  end
  puts
end

def phase6_verify
  puts "--- Phase 6: Verification ---"
  puts "Games:        #{Game.count}"
  puts "Players:      #{Player.count}"
  puts "Participations: #{GameParticipation.count}"
  puts "Awards:       #{Award.count}"
  puts "PlayerAwards: #{PlayerAward.count}"
  puts "Photos:       #{ActiveStorage::Attachment.where(name: 'photo').count}"
end

def create_game(game_data)
  game = Game.find_or_initialize_by(id: game_data[:id])
  game.assign_attributes(
    season: game_data[:season],
    series: game_data[:series],
    game_number: game_data[:game_number],
    played_on: game_data[:played_on],
    name: game_data[:name],
    result: game_data[:result]
  )
  game.save!
end

def create_player_and_participation(game_id, participation_data)
  player = Player.find_or_initialize_by(id: participation_data[:player_id])
  player.name = participation_data[:player_name] if player.new_record? || player.name != participation_data[:player_name]
  player.save!

  participation = GameParticipation.find_or_initialize_by(game_id: game_id, player_id: player.id)
  participation.assign_attributes(
    role_code: participation_data[:role_code],
    win: participation_data[:win],
    plus: participation_data[:plus],
    minus: participation_data[:minus],
    best_move: participation_data[:best_move],
    first_shoot: participation_data[:first_shoot]
  )
  participation.save!
end

ALLOWED_ICON_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

def attach_icon(award, icon_data_uri)
  match = icon_data_uri.match(/\Adata:image\/([^;]+);base64,(.+)\z/m)
  return unless match

  content_type = "image/#{match[1]}"
  return unless ALLOWED_ICON_CONTENT_TYPES.include?(content_type)

  binary = Base64.strict_decode64(match[2])

  award.save! if award.new_record? # need persisted record for attach
  award.icon.attach(
    io: StringIO.new(binary),
    filename: "award_#{award.title.parameterize}.#{match[1].sub('jpeg', 'jpg')}",
    content_type: content_type
  )
rescue ArgumentError => e
  puts "ERROR: Invalid base64 for icon #{award.title}: #{e.message}"
end

def parse_seasons(value)
  return (1..5).to_a if value.blank?

  str = value.to_s.strip

  range_match = /\A(\d+)-(\d+)\z/.match(str)
  if range_match
    first = Integer(range_match[1])
    last = Integer(range_match[2])
    raise ArgumentError, "Invalid SEASONS range: #{first} must be <= #{last}" if first > last

    return (first..last).to_a
  end

  str.split(",").map do |segment|
    seg = segment.strip
    raise ArgumentError, "Invalid SEASONS segment: #{seg.inspect}" unless /\A\d+\z/.match?(seg)

    Integer(seg)
  end
end
