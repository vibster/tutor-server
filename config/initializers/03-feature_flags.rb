begin
  FeatureFlag.initialize_globals!
rescue ActiveRecord::StatementInvalid => ee
  if ee.message.starts_with?("PG::UndefinedTable")
    Rails.logger.info { "Skipping feature flag globals b/c migration hasn't run yet"}
  else
    raise
  end
end
