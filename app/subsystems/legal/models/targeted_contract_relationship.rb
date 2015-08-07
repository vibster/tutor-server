class Legal::Models::TargetedContractRelationship < Tutor::SubSystems::BaseModel

  validates :child_gid, presence: true,
                        uniqueness: { scope: :parent_gid }
  validates :parent_gid, presence: true

  def self.all_parent_gids_of(child_gid)
    immediate_parent_gids = where(child_gid: child_gid).all.collect(&:parent_gid)
    [
      immediate_parent_gids +
      immediate_parent_gids.collect do |parent_gid|
        parent_gid.nil? ? nil : all_parent_gids_of(parent_gid)
      end
    ].flatten.compact.uniq
  end

end
