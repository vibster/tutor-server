class OpenStax::Cnx::V1::Fragment

  # Used to get the title
  TITLE_CSS = '[data-type="title"]'

  attr_reader :node, :labels

  def initialize(node:, title: nil, labels: nil)
    @node   = node
    @title  = title
    @labels = labels
  end

  def title
    return @title unless @title.nil?

    title_matches = node.css(TITLE_CSS)
    @title = title_matches.empty? ? nil : title_matches.map{ |nd| nd.content.strip }.uniq.join('; ')
  end

  def node_id
    @node_id ||= node.attribute('id').try :value
  end

  def labels
    @labels || []
  end

  def blank?
    false
  end

end