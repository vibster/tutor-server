module Catalog
  module Strategies
    module Direct
      class Offering < Entity

        wraps ::Catalog::Models::Offering

        exposes :id, :identifier, :is_tutor, :is_concept_coach, :description, :webview_url, :pdf_url, :ecosystem, :content_ecosystem_id

        alias_method :entity_ecosystem, :ecosystem
        def ecosystem
          entity_ecosystem ? ::Content::Ecosystem.new(strategy: entity_ecosystem) : nil
        end

      end
    end
  end
end