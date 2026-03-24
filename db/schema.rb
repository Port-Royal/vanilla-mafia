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

ActiveRecord::Schema[8.1].define(version: 2026_03_24_115021) do
  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "awards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "position"
    t.boolean "staff", default: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["staff"], name: "index_awards_on_staff"
  end

  create_table "competitions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ended_on"
    t.boolean "featured", default: false, null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.integer "parent_id"
    t.integer "position"
    t.string "slug", null: false
    t.date "started_on"
    t.datetime "updated_at", null: false
    t.index ["featured"], name: "index_competitions_on_featured"
    t.index ["kind"], name: "index_competitions_on_kind"
    t.index ["parent_id"], name: "index_competitions_on_parent_id"
    t.index ["slug"], name: "index_competitions_on_slug", unique: true
  end

  create_table "episodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "published_at"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "feature_toggles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: false, null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_feature_toggles_on_key", unique: true
  end

  create_table "game_participations", force: :cascade do |t|
    t.decimal "best_move", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.boolean "first_shoot", default: false
    t.integer "game_id", null: false
    t.decimal "minus", precision: 5, scale: 2, default: "0.0"
    t.text "notes"
    t.integer "player_id", null: false
    t.decimal "plus", precision: 5, scale: 2, default: "0.0"
    t.string "role_code"
    t.integer "seat"
    t.datetime "updated_at", null: false
    t.boolean "win", default: false
    t.index ["game_id", "player_id"], name: "index_game_participations_on_game_id_and_player_id", unique: true
    t.index ["game_id", "seat"], name: "index_game_participations_on_game_id_and_seat", unique: true
    t.index ["game_id"], name: "index_game_participations_on_game_id"
    t.index ["player_id"], name: "index_game_participations_on_player_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "competition_id", null: false
    t.datetime "created_at", null: false
    t.integer "game_number", null: false
    t.string "judge"
    t.string "name"
    t.date "played_on"
    t.string "result", default: "in_progress", null: false
    t.datetime "updated_at", null: false
    t.index ["competition_id", "game_number"], name: "index_games_on_competition_id_and_game_number", unique: true
    t.index ["competition_id"], name: "index_games_on_competition_id"
  end

  create_table "grants", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_grants_on_code", unique: true
  end

  create_table "news", force: :cascade do |t|
    t.integer "author_id", null: false
    t.integer "competition_id"
    t.datetime "created_at", null: false
    t.integer "game_id"
    t.datetime "published_at"
    t.string "status", default: "draft", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_news_on_author_id"
    t.index ["competition_id"], name: "index_news_on_competition_id"
    t.index ["game_id"], name: "index_news_on_game_id"
    t.index ["published_at"], name: "index_news_on_published_at"
  end

  create_table "player_awards", force: :cascade do |t|
    t.integer "award_id", null: false
    t.integer "competition_id"
    t.datetime "created_at", null: false
    t.integer "player_id", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["award_id"], name: "index_player_awards_on_award_id"
    t.index ["competition_id"], name: "index_player_awards_on_competition_id"
    t.index ["player_id", "award_id", "competition_id"], name: "idx_on_player_id_award_id_competition_id_3f522704bb", unique: true
    t.index ["player_id"], name: "index_player_awards_on_player_id"
  end

  create_table "player_claims", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "dispute", default: false, null: false
    t.text "evidence"
    t.integer "player_id", null: false
    t.text "rejection_reason"
    t.datetime "reviewed_at"
    t.integer "reviewed_by_id"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["player_id"], name: "index_player_claims_on_player_id"
    t.index ["reviewed_by_id"], name: "index_player_claims_on_reviewed_by_id"
    t.index ["status"], name: "index_player_claims_on_status"
    t.index ["user_id", "player_id"], name: "index_player_claims_on_user_id_and_player_id", unique: true
    t.index ["user_id"], name: "index_player_claims_on_user_id"
  end

  create_table "players", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_players_on_name", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.index ["code"], name: "index_roles_on_code", unique: true
  end

  create_table "taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.integer "taggable_id", null: false
    t.string "taggable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id", "taggable_type", "taggable_id"], name: "index_taggings_on_tag_id_and_taggable_type_and_taggable_id", unique: true
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_type", "taggable_id"], name: "index_taggings_on_taggable"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "telegram_authors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "telegram_user_id", null: false
    t.string "telegram_username"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["telegram_user_id"], name: "index_telegram_authors_on_telegram_user_id", unique: true
    t.index ["user_id"], name: "index_telegram_authors_on_user_id"
  end

  create_table "user_grants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "grant_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["grant_id"], name: "index_user_grants_on_grant_id"
    t.index ["user_id", "grant_id"], name: "index_user_grants_on_user_id_and_grant_id", unique: true
    t.index ["user_id"], name: "index_user_grants_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "locale", default: "ru", null: false
    t.boolean "notify_on_news_draft", default: true, null: false
    t.integer "player_id"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["player_id"], name: "index_users_on_player_id", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "competitions", "competitions", column: "parent_id"
  add_foreign_key "game_participations", "games"
  add_foreign_key "game_participations", "players"
  add_foreign_key "game_participations", "roles", column: "role_code", primary_key: "code"
  add_foreign_key "games", "competitions"
  add_foreign_key "news", "competitions"
  add_foreign_key "news", "games"
  add_foreign_key "news", "users", column: "author_id"
  add_foreign_key "player_awards", "awards"
  add_foreign_key "player_awards", "competitions"
  add_foreign_key "player_awards", "players"
  add_foreign_key "player_claims", "players"
  add_foreign_key "player_claims", "users"
  add_foreign_key "player_claims", "users", column: "reviewed_by_id"
  add_foreign_key "taggings", "tags"
  add_foreign_key "telegram_authors", "users"
  add_foreign_key "user_grants", "grants"
  add_foreign_key "user_grants", "users"
  add_foreign_key "users", "players"
end
