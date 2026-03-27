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

ActiveRecord::Schema[7.2].define(version: 2026_03_27_225645) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "encounter_notes", force: :cascade do |t|
    t.bigint "author_user_id", null: false
    t.bigint "subject_user_id", null: false
    t.date "encountered_on"
    t.string "encounter_place"
    t.text "note", null: false
    t.text "next_action"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_user_id", "subject_user_id"], name: "index_encounter_notes_on_author_user_id_and_subject_user_id"
    t.index ["author_user_id"], name: "index_encounter_notes_on_author_user_id"
    t.index ["subject_user_id"], name: "index_encounter_notes_on_subject_user_id"
  end

  create_table "favorites", force: :cascade do |t|
    t.bigint "owner_user_id", null: false
    t.bigint "target_user_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["owner_user_id", "target_user_id"], name: "index_favorites_on_owner_user_id_and_target_user_id", unique: true
    t.index ["owner_user_id"], name: "index_favorites_on_owner_user_id"
    t.index ["target_user_id"], name: "index_favorites_on_target_user_id"
    t.check_constraint "owner_user_id <> target_user_id", name: "favorites_owner_target_check"
  end

  create_table "profile_tags", force: :cascade do |t|
    t.bigint "profile_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["profile_id", "tag_id"], name: "index_profile_tags_on_profile_id_and_tag_id", unique: true
    t.index ["profile_id"], name: "index_profile_tags_on_profile_id"
    t.index ["tag_id"], name: "index_profile_tags_on_tag_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "display_name", null: false
    t.text "bio"
    t.string "organization"
    t.string "role"
    t.string "visibility_level", default: "member", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_profiles_on_user_id", unique: true
    t.check_constraint "visibility_level::text = ANY (ARRAY['public'::character varying, 'member'::character varying, 'private'::character varying]::text[])", name: "profiles_visibility_level_check"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_name"], name: "index_tags_on_normalized_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "encounter_notes", "users", column: "author_user_id"
  add_foreign_key "encounter_notes", "users", column: "subject_user_id"
  add_foreign_key "favorites", "users", column: "owner_user_id"
  add_foreign_key "favorites", "users", column: "target_user_id"
  add_foreign_key "profile_tags", "profiles"
  add_foreign_key "profile_tags", "tags"
  add_foreign_key "profiles", "users"
end
