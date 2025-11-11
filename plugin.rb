# frozen_string_literal: true

# name: discourse-llms-txt-generator
# about: Automatically generates llms.txt and llms-full.txt for LLM optimization (GEO)
# version: 1.2.0
# authors: KakTak.net
# url: https://github.com/kaktaknet/discourse-llms-txt-generator
# required_version: 2.7.0

enabled_site_setting :llms_txt_enabled

after_initialize do
  module ::DiscourseLlmsTxt
    PLUGIN_NAME = "discourse-llms-txt-generator"
  end

  require_relative "lib/discourse_llms_txt/generator"
  require_relative "lib/discourse_llms_txt/engine"
  require_relative "app/controllers/discourse_llms_txt/llms_controller"
  require_relative "app/jobs/scheduled/update_llms_txt_cache"

  Discourse::Application.routes.append do
    get "/llms.txt" => "discourse_llms_txt/llms#index"
    get "/llms-full.txt" => "discourse_llms_txt/llms#full"
    get "/sitemaps.txt" => "discourse_llms_txt/llms#sitemaps"

    # Constraint allows matching full category path including subcategories
    get "/c/:category_slug_path_with_id/llms.txt" => "discourse_llms_txt/llms#category", constraints: { category_slug_path_with_id: /.*/ }

    get "/t/:topic_slug/:topic_id/llms.txt" => "discourse_llms_txt/llms#topic"
    get "/tag/:tag_name/llms.txt" => "discourse_llms_txt/llms#tag"
  end

  # Register sitemap entries using DiscourseEvent
  DiscourseEvent.on(:before_sitemap_refresh) do
    if SiteSetting.llms_txt_enabled && SiteSetting.llms_txt_allow_indexing
      SitemapUrl.create!(url: "/llms.txt", priority: 1.0, updated_at: Time.zone.now) rescue nil
      SitemapUrl.create!(url: "/llms-full.txt", priority: 0.9, updated_at: Time.zone.now) rescue nil
      SitemapUrl.create!(url: "/sitemaps.txt", priority: 0.8, updated_at: Time.zone.now) rescue nil
    end
  end

  # robots.txt integration is handled via view connector:
  # app/views/connectors/robots_txt_index/llms_txt.html.erb

  on(:post_created) do |post|
    DiscourseLlmsTxt::Generator.clear_cache if SiteSetting.llms_txt_enabled
  end

  on(:post_edited) do |post|
    DiscourseLlmsTxt::Generator.clear_cache if SiteSetting.llms_txt_enabled
  end
end
