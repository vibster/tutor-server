FactoryGirl.define do
  factory :forum_post, class: 'Forum::Models::Post' do
    association :role, factory: :entity_role
    association :page, factory: :content_page
    association :exercise, factory: :content_exercise

    title 'Test'
    content 'Content'
  end
end
