class SeedGameBreakdownAnnouncements < ActiveRecord::Migration[8.1]
  VERSION = "0.41.0".freeze

  def up
    announcements = [
      {
        version: VERSION,
        grant_code: "judge",
        message_ru: "Судьи: добавлен раздел «Разборы» — пофазный разбор игры с речами, ходами, голосованиями и ночами.",
        message_en: "Judges: the Breakdowns section is here — a phase-by-phase analysis of a game with speeches, moves, votings and nights."
      },
      {
        version: VERSION,
        grant_code: "admin",
        message_ru: "Администраторы: добавлен раздел «Разборы» — пофазный разбор игры, доступный судьям и администраторам.",
        message_en: "Admins: the Breakdowns section is here — a phase-by-phase analysis of a game, available to judges and admins."
      }
    ]

    announcements.each { |attrs| Announcement.find_or_create_by!(attrs) }
  end

  def down
    Announcement.where(version: VERSION).delete_all
  end
end
