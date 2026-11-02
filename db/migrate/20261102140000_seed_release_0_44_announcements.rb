class SeedRelease044Announcements < ActiveRecord::Migration[8.1]
  VERSION = "0.44.0".freeze

  def up
    announcements = [
      {
        version: VERSION,
        grant_code: "judge",
        message_ru: "Судьи: оверлей показывает выставленных, ночи (отстрел и проверки), фолы и техфолы, а значки ролей стали ярче. В результатах игры появилась ничья.",
        message_en: "Judges: the overlay now shows the nominees, the nights (shots and checks), fouls and technical fouls, and the role badges are brighter. A game can now end in a draw."
      },
      {
        version: VERSION,
        grant_code: "admin",
        message_ru: "Администраторы: готов живой протокол — судья ведёт игру с клавиатуры, а протокол и оверлей заполняются сами. Включите флаг live_protocol в разделе Feature Toggles админки, чтобы открыть его судьям.",
        message_en: "Admins: the live protocol is ready — the judge runs the game from the keyboard and the protocol and the overlay fill themselves. Switch on the live_protocol flag under Feature Toggles in the admin to open it to judges."
      }
    ]

    announcements.each { |attrs| Announcement.find_or_create_by!(attrs) }
  end

  def down
    Announcement.where(version: VERSION).delete_all
  end
end
