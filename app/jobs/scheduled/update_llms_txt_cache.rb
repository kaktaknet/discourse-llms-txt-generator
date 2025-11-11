# frozen_string_literal: true

module Jobs
  class UpdateLlmsTxtCache < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.llms_txt_enabled

      if DiscourseLlmsTxt::Generator.should_update_cache?
        Rails.logger.info("[llms.txt] Updating cache due to new content")

        DiscourseLlmsTxt::Generator.clear_cache
        DiscourseLlmsTxt::Generator.generate_navigation
        DiscourseLlmsTxt::Generator.update_cache_timestamp

        Rails.logger.info("[llms.txt] Cache updated successfully")
      else
        Rails.logger.debug("[llms.txt] No new content, skipping cache update")
      end
    rescue => e
      Discourse.warn_exception(e, message: "Failed to update llms.txt cache")
    end
  end
end
