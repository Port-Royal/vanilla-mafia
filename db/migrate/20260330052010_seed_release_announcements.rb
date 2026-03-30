class SeedReleaseAnnouncements < ActiveRecord::Migration[8.1]
  def up
    announcements = [
      {
        version: "0.29.0",
        grant_code: "subscriber",
        message_ru: "Подписчики: добавлен подкаст с RSS-лентой, личным токеном и автоматическим определением длительности эпизодов.",
        message_en: "Subscribers: podcast added with RSS feed, personal token, and automatic episode duration detection."
      },
      {
        version: "0.29.0",
        grant_code: "judge",
        message_ru: "Судьи: в боковом меню добавлена ссылка на раздел справки.",
        message_en: "Judges: help section link added to the sidebar."
      },
      {
        version: "0.29.0",
        grant_code: "admin",
        message_ru: "Администраторы: в боковом меню добавлена ссылка на раздел справки.",
        message_en: "Admins: help section link added to the sidebar."
      },
      {
        version: "0.29.0",
        grant_code: nil,
        message_ru: "Улучшена валидация контента новостей.",
        message_en: "Improved news content validation."
      }
    ]

    announcements.each do |attrs|
      Announcement.find_or_create_by!(attrs)
    end
  end

  def down
    Announcement.where(version: "0.29.0").delete_all
  end
end
