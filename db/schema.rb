# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_17_062204) do
  create_table "awards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "position"
    t.boolean "staff", default: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "game_number", null: false
    t.string "name"
    t.date "played_on"
    t.string "result"
    t.integer "season", null: false
    t.integer "series", null: false
    t.datetime "updated_at", null: false
    t.index ["season", "series", "game_number"], name: "index_games_on_season_and_series_and_game_number", unique: true
    t.index ["season", "series"], name: "index_games_on_season_and_series"
    t.index ["season"], name: "index_games_on_season"
  end

  create_table "player_awards", force: :cascade do |t|
    t.integer "award_id", null: false
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.integer "position"
    t.integer "season"
    t.datetime "updated_at", null: false
    t.index ["award_id"], name: "index_player_awards_on_award_id"
    t.index ["player_id", "award_id", "season"], name: "index_player_awards_on_player_id_and_award_id_and_season", unique: true
    t.index ["player_id"], name: "index_player_awards_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
  end

  create_table "ratings", force: :cascade do |t|
    t.decimal "best_move", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.boolean "first_shoot", default: false
    t.integer "game_id", null: false
    t.decimal "minus", precision: 5, scale: 2, default: "0.0"
    t.integer "player_id", null: false
    t.decimal "plus", precision: 5, scale: 2, default: "0.0"
    t.string "role_code"
    t.datetime "updated_at", null: false
    t.boolean "win", default: false
    t.index ["game_id", "player_id"], name: "index_ratings_on_game_id_and_player_id", unique: true
    t.index ["game_id"], name: "index_ratings_on_game_id"
    t.index ["player_id"], name: "index_ratings_on_player_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.index ["code"], name: "index_roles_on_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "player_awards", "awards"
  add_foreign_key "player_awards", "players"
  add_foreign_key "ratings", "games"
  add_foreign_key "ratings", "players"
  add_foreign_key "ratings", "roles", column: "role_code", primary_key: "code"
end
