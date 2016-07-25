FactoryGirl.define do
  factory :forum_comment, class: 'Forum::Models::Comment' do
    association :role, factory: :entity_role
    content 'Content'
  end
end
