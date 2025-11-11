# frozen_string_literal: true

desc "Regenerate sitemap and robots.txt to include llms.txt files"
task "llms_txt:refresh" => :environment do
  puts "Clearing robots.txt cache..."
  Rails.cache.delete("robots_txt")

  puts "Regenerating sitemap..."
  if defined?(Jobs::GenerateSitemap)
    Jobs.enqueue(:generate_sitemap)
    puts "Sitemap regeneration enqueued"
  elsif defined?(SitemapRefresh)
    SitemapRefresh.refresh!
    puts "Sitemap refreshed"
  else
    puts "Warning: Could not find sitemap generation method"
    puts "Try running: rake sitemap:refresh"
  end

  puts "Clearing llms.txt cache..."
  DiscourseLlmsTxt::Generator.clear_cache

  puts "Done! Visit #{Discourse.base_url}/sitemap.xml and #{Discourse.base_url}/robots.txt to verify"
  puts ""
  puts "If llms.txt files still don't appear in sitemap.xml, try:"
  puts "  rake sitemap:refresh"
  puts "  rake sitemap:regenerate"
end

desc "Check if llms.txt is properly configured"
task "llms_txt:check" => :environment do
  puts "Checking llms.txt configuration..."
  puts ""
  puts "Settings:"
  puts "  llms_txt_enabled: #{SiteSetting.llms_txt_enabled}"
  puts "  llms_txt_allow_indexing: #{SiteSetting.llms_txt_allow_indexing}"
  puts ""

  if SiteSetting.llms_txt_enabled
    puts "✓ Plugin is enabled"
  else
    puts "✗ Plugin is disabled - enable it in Admin → Settings → Plugins"
  end

  if SiteSetting.llms_txt_allow_indexing
    puts "✓ Indexing is allowed"
  else
    puts "✗ Indexing is disabled"
  end

  puts ""
  puts "Testing endpoints:"

  routes = [
    "/llms.txt",
    "/llms-full.txt",
    "/sitemaps.txt"
  ]

  routes.each do |route|
    url = "#{Discourse.base_url}#{route}"
    puts "  #{url}"
  end

  puts ""
  puts "To refresh robots.txt and sitemap, run:"
  puts "  rake llms_txt:refresh"
end
