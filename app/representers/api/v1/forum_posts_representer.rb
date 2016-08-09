class Api::V1::ForumPostsRepresenter < Roar::Decorator
  include Representable::JSON::Collection

  items extend: Api::V1::ForumPostRepresenter
end
