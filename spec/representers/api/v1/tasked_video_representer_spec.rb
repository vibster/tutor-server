require 'rails_helper'

RSpec.describe Api::V1::TaskedVideoRepresenter, :type => :representer do
  it 'should represent a video' do
    task_step = FactoryGirl.create(:tasked_video).task_step
    json = Api::V1::TaskedVideoRepresenter.new(task_step.tasked).to_json

    expect(JSON.parse(json)).to eq({
      id: task_step.id,
      type: 'video',
      title: task_step.tasked.title,
      is_completed: false,
      content_url: task_step.tasked.url,
      content_html: task_step.tasked.content,
      video_url: task_step.tasked.video_url
    }.stringify_keys)
  end
end
