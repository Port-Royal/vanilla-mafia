class SeedSubscriberGrant < ActiveRecord::Migration[8.1]
  def up
    Grant.find_or_create_by!(code: "subscriber")
  end

  def down
    Grant.find_by(code: "subscriber")&.destroy!
  end
end
