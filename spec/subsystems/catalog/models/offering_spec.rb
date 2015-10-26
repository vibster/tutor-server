require 'rails_helper'

RSpec.describe Catalog::Models::Offering, :type => :model do
  subject{ FactoryGirl.create :catalog_offering }

  it { is_expected.to validate_presence_of(:identifier) }
  it { is_expected.to validate_presence_of(:webview_url) }
  it { is_expected.to validate_presence_of(:description) }

  it 'disallows duplicate identifiers' do
    FactoryGirl.create(:catalog_offering, identifier: 'test')
    expect{
      FactoryGirl.create(:catalog_offering, identifier: 'test')
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end