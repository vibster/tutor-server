module Api::V1
  class ForumCommentRepresenter < Roar::Decorator

    include Roar::JSON
    include Representable::Coercion

    property :content,
             type: String,
             readable: true,
             writeable: false,
             schema_info: { required: true }

    property :author_name,
             as: :author

  end
end
