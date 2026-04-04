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

ActiveRecord::Schema[7.2].define(version: 2026_04_04_173000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "case_insights", force: :cascade do |t|
    t.bigint "encounter_case_id", null: false
    t.string "insight_type", null: false
    t.text "description", null: false
    t.text "application_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_case_id"], name: "index_case_insights_on_encounter_case_id"
  end

  create_table "case_outcomes", force: :cascade do |t|
    t.bigint "encounter_case_id", null: false
    t.string "category", null: false
    t.text "description", null: false
    t.string "impact_scope"
    t.string "evidence_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "outcome_direction", default: "positive", null: false
    t.index ["encounter_case_id"], name: "index_case_outcomes_on_encounter_case_id"
  end

  create_table "case_participants", force: :cascade do |t|
    t.bigint "encounter_case_id", null: false
    t.bigint "person_id", null: false
    t.string "participation_role", null: false
    t.text "contribution_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_case_id", "person_id", "participation_role"], name: "index_case_participants_uniqueness", unique: true
    t.index ["encounter_case_id"], name: "index_case_participants_on_encounter_case_id"
    t.index ["person_id"], name: "index_case_participants_on_person_id"
  end

  create_table "case_sources", force: :cascade do |t|
    t.bigint "encounter_case_id", null: false
    t.bigint "source_id", null: false
    t.string "citation_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_case_id", "source_id"], name: "index_case_sources_on_encounter_case_id_and_source_id", unique: true
    t.index ["encounter_case_id"], name: "index_case_sources_on_encounter_case_id"
    t.index ["source_id"], name: "index_case_sources_on_source_id"
  end

  create_table "case_tags", force: :cascade do |t|
    t.bigint "encounter_case_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_case_id", "tag_id"], name: "index_case_tags_on_encounter_case_id_and_tag_id", unique: true
    t.index ["encounter_case_id"], name: "index_case_tags_on_encounter_case_id"
    t.index ["tag_id"], name: "index_case_tags_on_tag_id"
  end

  create_table "edit_histories", force: :cascade do |t|
    t.string "item_type", null: false
    t.bigint "item_id", null: false
    t.string "action", null: false
    t.string "summary", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id", "created_at"], name: "index_edit_histories_on_item_type_and_item_id_and_created_at"
  end

  create_table "encounter_cases", force: :cascade do |t|
    t.string "slug", null: false
    t.string "title", null: false
    t.text "summary"
    t.text "background"
    t.date "happened_on"
    t.string "place"
    t.string "publication_status", default: "draft", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publication_status"], name: "index_encounter_cases_on_publication_status"
    t.index ["slug"], name: "index_encounter_cases_on_slug", unique: true
  end

  create_table "list_requests", force: :cascade do |t|
    t.string "requester_name", null: false
    t.string "requester_email", null: false
    t.string "request_theme", null: false
    t.text "request_purpose"
    t.integer "requested_count", default: 10, null: false
    t.string "delivery_format"
    t.string "budget_range"
    t.string "deadline_preference"
    t.text "note"
    t.string "status", default: "new", null: false
    t.string "payment_status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "package_key", default: "starter_10", null: false
    t.index ["created_at"], name: "index_list_requests_on_created_at"
    t.index ["package_key"], name: "index_list_requests_on_package_key"
    t.index ["payment_status"], name: "index_list_requests_on_payment_status"
    t.index ["status"], name: "index_list_requests_on_status"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "category"
    t.string "website_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.string "slug", null: false
    t.string "display_name", null: false
    t.text "summary"
    t.text "bio"
    t.string "publication_status", default: "draft", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publication_status"], name: "index_people_on_publication_status"
    t.index ["slug"], name: "index_people_on_slug", unique: true
  end

  create_table "person_affiliations", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "organization_id", null: false
    t.string "title"
    t.date "started_on"
    t.date "ended_on"
    t.boolean "primary_flag", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_person_affiliations_on_organization_id"
    t.index ["person_id", "organization_id", "title", "started_on"], name: "index_person_affiliations_uniqueness", unique: true
    t.index ["person_id"], name: "index_person_affiliations_on_person_id"
  end

  create_table "person_external_profiles", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "source_name", null: false
    t.string "external_id", null: false
    t.string "source_url", null: false
    t.datetime "fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "graph_tags", default: [], null: false, array: true
    t.text "graph_organizations", default: [], null: false, array: true
    t.index ["person_id"], name: "index_person_external_profiles_on_person_id"
    t.index ["source_name", "external_id"], name: "index_person_external_profiles_on_source_name_and_external_id", unique: true
  end

  create_table "person_tags", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id", "tag_id"], name: "index_person_tags_on_person_id_and_tag_id", unique: true
    t.index ["person_id"], name: "index_person_tags_on_person_id"
    t.index ["tag_id"], name: "index_person_tags_on_tag_id"
  end

  create_table "research_notes", force: :cascade do |t|
    t.bigint "person_id"
    t.bigint "encounter_case_id"
    t.string "note_kind", default: "research", null: false
    t.text "body", null: false
    t.string "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["encounter_case_id"], name: "index_research_notes_on_encounter_case_id"
    t.index ["person_id"], name: "index_research_notes_on_person_id"
    t.index ["status"], name: "index_research_notes_on_status"
  end

  create_table "sources", force: :cascade do |t|
    t.string "title", null: false
    t.string "url", null: false
    t.string "source_type"
    t.date "published_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url"], name: "index_sources_on_url", unique: true
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
    t.string "role", default: "editor", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "case_insights", "encounter_cases"
  add_foreign_key "case_outcomes", "encounter_cases"
  add_foreign_key "case_participants", "encounter_cases"
  add_foreign_key "case_participants", "people"
  add_foreign_key "case_sources", "encounter_cases"
  add_foreign_key "case_sources", "sources"
  add_foreign_key "case_tags", "encounter_cases"
  add_foreign_key "case_tags", "tags"
  add_foreign_key "person_affiliations", "organizations"
  add_foreign_key "person_affiliations", "people"
  add_foreign_key "person_external_profiles", "people"
  add_foreign_key "person_tags", "people"
  add_foreign_key "person_tags", "tags"
  add_foreign_key "research_notes", "encounter_cases"
  add_foreign_key "research_notes", "people"
end
