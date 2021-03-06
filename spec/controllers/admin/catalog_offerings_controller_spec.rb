require 'rails_helper'

RSpec.describe Admin::CatalogOfferingsController, type: :controller do
  let(:admin) do
    profile = FactoryBot.create :user_profile,
                                 :administrator,
                                 username: 'admin',
                                 full_name: 'Administrator'
    strategy = User::Strategies::Direct::User.new(profile)
    User::User.new(strategy: strategy)
  end
  let!(:offering)  { FactoryBot.create(:catalog_offering) }
  let(:attributes) { FactoryBot.build(:catalog_offering).attributes }

  before { controller.sign_in(admin) }

  it 'displays offerings' do
    get :index
    expect(response).to have_http_status(:success)
  end

  context 'creating an offering' do
    let(:attributes) { FactoryBot.build(:catalog_offering).attributes }

    it 'complains about blank fields' do
      expect{
        post :create, { offering: attributes.except('description') }
        expect(controller).to set_flash[:error].to(/Description can\'t be blank/).now
      }.to_not change(Catalog::Models::Offering, :count)
    end

    it 'can create offering' do
      expect{
        response = post :create, { offering: attributes }
        expect(response).to redirect_to action: 'index'
      }.to change(Catalog::Models::Offering, :count).by(1)
    end

    it 'can have duplicated sf book names' do
      FactoryBot.create(:catalog_offering, salesforce_book_name: "Blah")
      attributes["salesforce_book_name"] = "Blah"
      expect{
        response = post :create, { offering: attributes }
        expect(response).to redirect_to action: 'index'
      }.to change(Catalog::Models::Offering, :count).by(1)
    end
  end

  context 'editing an offering' do
    it 'complains about blank fields' do
      attrs = offering.attributes
      attrs['webview_url']=''
      expect{
        put :update, { id: offering.id, offering: attrs }
        expect(controller).to set_flash[:error].to(/Webview url can\'t be blank/).now
      }.to_not change(Catalog::Models::Offering, :count)
    end

    it 'can update an offering' do
      expect(offering.is_tutor).to be false
      expect(offering.is_concept_coach).to be false
      expect(offering.does_cost).to be false
      response = put :update,
                     id: offering.id,
                     offering: offering.attributes.merge(
                       'is_tutor' => 't',
                       'is_concept_coach' => 't',
                       'does_cost' => 't'
                     )
      expect(response).to redirect_to action: 'index'
      offering.reload
      expect(offering.is_tutor).to be true
      expect(offering.is_concept_coach).to be true
      expect(offering.does_cost).to be true
    end
  end

  context 'deleting an offering' do
    it 'can delete an offering' do
      expect { delete :destroy, id: offering.id }.to(
        change { Catalog::Models::Offering.count }.by(-1)
      )
      expect { offering.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(response).to redirect_to action: 'index'
    end

    it 'does not delete the offering if it has courses' do
      FactoryBot.create :course_profile_course, offering: offering
      expect { delete :destroy, id: offering.id }.not_to change { Catalog::Models::Offering.count }
      expect { offering.reload }.not_to raise_error
    end
  end

end
