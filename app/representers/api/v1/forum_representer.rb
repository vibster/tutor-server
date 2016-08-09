module Api::V1
  class ForumRepresenter < Roar::Decorator

    include Roar::JSON
    include Representable::Coercion

    collection :posts,
                extend: Api::V1::ForumPostsRepresenter




  end
end
