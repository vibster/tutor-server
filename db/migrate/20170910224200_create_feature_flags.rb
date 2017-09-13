class CreateFeatureFlags < ActiveRecord::Migration
  def change
    create_table :feature_flags do |t|
      t.integer :name
      t.boolean :value
      t.boolean :is_global, index: true
      t.references :course_profile_course,
                   null: true,
                   index: true,
                   foreign_key: { on_update: :cascade,  on_delete: :cascade }
    end

    add_index :feature_flags, [:name, :course_profile_course_id],
              unique: true, name: :index_ffs_on_name_course

    add_index :feature_flags, [:name, :is_global],
              unique: true, name: :index_ffs_on_name_global
  end
end
