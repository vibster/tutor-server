class Api::V1::ForumCommentsRepresenter < Roar::Decorator
  include Representable::JSON::Collection

  items extend: Api::V1::ForumCommentRepresenter
end
