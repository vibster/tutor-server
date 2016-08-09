class CreateForumComments < ActiveRecord::Migration
  def change
    create_table :forum_comments do |t|
      t.references :entity_role, index: true, null: false,
                   foreign_key: { on_update: :cascade, on_delete: :cascade }
      t.references :forum_post, index: true, 
                   foreign_key: true
      t.datetime :endorsed_at
      t.text :content

      t.timestamps null: false
    end
  end
end
