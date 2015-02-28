require 'rails_helper'

RSpec.describe TaskAccessPolicy do
  let(:requestor) { FactoryGirl.create(:user) }
  let(:task) { FactoryGirl.create(:task) }

  subject(:action_allowed) do
    TaskAccessPolicy.action_allowed?(action, requestor, task)
  end

  context 'when the action is :read' do
    let(:action) { :read }

    context 'and the requestor is human' do
      # already true for User

      context 'and the requestor has taskings in the task' do
        before { allow(task).to receive(:tasked_to?).with(requestor) { true } }

        it { should be true }
      end

      context 'and the requestor has no taskings in the task' do
        before { allow(task).to receive(:tasked_to?).with(requestor) { false } }

        it { should be false }
      end
    end

    context 'and the requestor is not human' do
      before { allow(requestor).to receive(:is_human?) { false } }

      it { should be false }
    end
  end

  [:create, :update, :destroy, :made_up].each do |disallowed_action|
    context "when the action is :#{disallowed_action}" do
      let(:action) { disallowed_action }

      it { should be false }
    end
  end
end
