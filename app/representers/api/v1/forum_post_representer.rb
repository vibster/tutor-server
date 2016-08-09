module Api::V1
  class ForumPostRepresenter < Roar::Decorator

    include Roar::JSON
    include Representable::Coercion


    property :title,
             type: String,
             readable: true,
             writeable: false,
             schema_info: { required: true }

    property :content,
             type: String,
             readable: true,
             writeable: false,
             schema_info: { required: true }

    collection :comment,
                extend: Api::V1::ForumCommentsRepresenter




  end
end
