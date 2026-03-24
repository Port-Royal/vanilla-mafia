class SeedGrantsAndMigrateUserRoles < ActiveRecord::Migration[8.1]
  def up
    now = Time.current

    grant_rows = %w[user judge editor admin].map do |code|
      { code: code, created_at: now, updated_at: now }
    end

    Grant.insert_all(grant_rows)

    grant_ids_by_code = Grant.pluck(:code, :id).to_h

    User.find_each do |user|
      grant_id = grant_ids_by_code[user.role]
      next unless grant_id

      UserGrant.create!(user_id: user.id, grant_id: grant_id)
    end
  end

  def down
    UserGrant.delete_all
    Grant.delete_all
  end
end
