class CreateForumPosts < ActiveRecord::Migration
  def change
    create_table :forum_posts do |t|
      t.references :entity_role, index: true, null: false,
                   foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.references :content_page, index: true,
                   foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.references :content_exercise, index: true,
                   foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.string :title, null: false
      t.text :content, null: false

      t.timestamps null: false
    end
  end
end
