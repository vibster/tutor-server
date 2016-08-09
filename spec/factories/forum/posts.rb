FactoryGirl.define do
  factory :forum_post, class: 'Forum::Models::Post' do
    association :role, factory: :entity_role
    association :page, factory: :content_page
    association :exercise, factory: :content_exercise

    title 'Why is Ted So Bad at Math?'
    content 'He is really really bad'
  end
end
