# frozen_string_literal: true

require 'cgi'

module DiscourseLlmsTxt
  class Generator
    CACHE_KEY_NAV = "llms_txt_navigation"
    CACHE_KEY_FULL = "llms_txt_full_content"
    CACHE_KEY_SITEMAPS = "llms_txt_sitemaps"
    CACHE_KEY_LAST_CHECK = "llms_txt_last_content_check"
    CACHE_KEY_LAST_UPDATE = "llms_txt_last_update_timestamp"

    class << self
      def generate_navigation
        Rails.cache.fetch(CACHE_KEY_NAV, expires_in: cache_duration) do
          build_navigation
        end
      end

      def generate_full_content
        build_full_content
      end

      def clear_cache
        Rails.cache.delete(CACHE_KEY_NAV)
        Rails.cache.delete(CACHE_KEY_FULL)
        Rails.cache.delete(CACHE_KEY_SITEMAPS)
        Rails.cache.delete(CACHE_KEY_LAST_CHECK)
      end

      # Smart cache update check - only regenerate if needed
      def should_update_cache?
        last_check = Rails.cache.read(CACHE_KEY_LAST_CHECK)
        return true if last_check.nil? || last_check < 1.hour.ago

        last_topic = Topic.maximum(:created_at)
        last_category = Category.maximum(:updated_at)

        return true if last_topic && last_topic > last_check
        return true if last_category && last_category > last_check

        false
      end

      def update_cache_timestamp
        Rails.cache.write(CACHE_KEY_LAST_CHECK, Time.now, expires_in: 2.hours)
        Rails.cache.write(CACHE_KEY_LAST_UPDATE, Time.now, expires_in: 30.days)
      end

      def last_update_time
        Rails.cache.read(CACHE_KEY_LAST_UPDATE) || Time.now
      end

      def generate_sitemaps
        Rails.cache.fetch(CACHE_KEY_SITEMAPS, expires_in: cache_duration) do
          build_sitemaps
        end
      end

      def generate_category_llms(category)
        build_category_llms(category)
      end

      def generate_topic_llms(topic)
        build_topic_llms(topic)
      end

      def generate_tag_llms(tag)
        build_tag_llms(tag)
      end

      private

      def build_navigation
        content = <<~MARKDOWN
          # #{SiteSetting.title}
          > #{SiteSetting.site_description}

          #{SiteSetting.llms_txt_intro_text}

          ## Categories and Subcategories
          #{generate_categories_with_subcategories}

          ## Latest Topics
          #{generate_latest_topics}

          ## Additional Resources
          #{generate_optional_links}
        MARKDOWN

        content.strip
      end

      def build_full_content
        content = <<~MARKDOWN
          # #{SiteSetting.title} - Full Content

          > #{SiteSetting.site_description}

        MARKDOWN

        if SiteSetting.llms_txt_full_description.present?
          content += <<~MARKDOWN

            ## About This Forum

            #{SiteSetting.llms_txt_full_description}

          MARKDOWN
        end

        content += <<~MARKDOWN

          [← Back to Navigation (llms.txt)](#{Discourse.base_url}/llms.txt)

          ---

          ## Categories and Subcategories

          #{generate_categories_with_subcategories_detailed}

          ---

          ## Topics

          #{generate_topics_list}

        MARKDOWN

        content
      end

      def generate_categories_with_subcategories
        parent_categories = Category.secured
          .where(read_restricted: false, parent_category_id: nil)
          .order(position: :asc)

        return "No public categories available" if parent_categories.empty?

        result = []

        parent_categories.each do |category|
          description = category.description_excerpt || "No description"
          result << "### [#{category.name}](#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id})"
          result << "#{description}"

          subcategories = Category.secured
            .where(read_restricted: false, parent_category_id: category.id)
            .order(position: :asc)

          if subcategories.any?
            result << ""
            subcategories.each do |subcat|
              subdesc = subcat.description_excerpt || "No description"
              result << "- [#{subcat.name}](#{Discourse.base_url}/c/#{CGI.escape(subcat.slug)}/#{subcat.id}): #{subdesc}"
            end
          end

          result << ""
        end

        result.join("\n")
      end

      def generate_categories_with_subcategories_detailed
        parent_categories = Category.secured
          .where(read_restricted: false, parent_category_id: nil)
          .order(position: :asc)

        return "No public categories available" if parent_categories.empty?

        result = []

        parent_categories.each do |category|
          result << "### [#{category.name}](#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id})"

          if category.description.present?
            result << ""
            result << category.description_excerpt
            result << ""
          end

          subcategories = Category.secured
            .where(read_restricted: false, parent_category_id: category.id)
            .order(position: :asc)

          if subcategories.any?
            result << "**Subcategories:**"
            result << ""
            subcategories.each do |subcat|
              subdesc = subcat.description_excerpt || "No description"
              result << "- **[#{subcat.name}](#{Discourse.base_url}/c/#{CGI.escape(subcat.slug)}/#{subcat.id})**: #{subdesc}"
            end
            result << ""
          end
        end

        result.join("\n")
      end

      def generate_latest_topics
        limit = [SiteSetting.llms_txt_latest_topics_count, 50].min

        topics = Topic.visible
          .where(archetype: "regular")
          .joins(:category)
          .where(categories: { read_restricted: false })
          .order(created_at: :desc)
          .limit(limit)
          .includes(:category)

        return "No topics yet" if topics.empty?

        topics.map do |topic|
          category_name = topic.category&.name || "Uncategorized"
          "- [#{topic.title}](#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}) - #{category_name} (#{topic.created_at.strftime("%Y-%m-%d")})"
        end.join("\n")
      end

      def generate_topics_list
        limit = posts_limit

        topics = Topic.visible
          .where(archetype: "regular")
          .joins(:category)
          .where(categories: { read_restricted: false })
          .where("topics.views >= ?", SiteSetting.llms_txt_min_views)
          .order(created_at: :desc)
          .includes(:category)

        topics = topics.limit(limit) if limit

        return "No topics available" if topics.empty?

        result = []

        topics.each do |topic|
          category_name = topic.category&.name || "Uncategorized"
          category_url = topic.category ? "#{Discourse.base_url}/c/#{CGI.escape(topic.category.slug)}/#{topic.category.id}" : ""

          if category_url.present?
            result << "**[#{category_name}](#{category_url})** - [#{topic.title}](#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id})"
          else
            result << "**#{category_name}** - [#{topic.title}](#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id})"
          end

          if SiteSetting.llms_txt_include_excerpts
            first_post = topic.first_post
            if first_post&.raw.present?
              excerpt = first_post.raw.truncate(SiteSetting.llms_txt_post_excerpt_length, separator: ' ', omission: '...')
              result << "  > #{excerpt}"
              result << ""
            end
          end
        end

        result.join("\n")
      end

      def generate_optional_links
        links = []

        links << "- [Full Documentation (llms-full.txt)](#{Discourse.base_url}/llms-full.txt): Complete forum content"

        if SiteSetting.respond_to?(:about_page_url) && SiteSetting.about_page_url.present?
          links << "- [About](#{SiteSetting.about_page_url}): About this community"
        end

        if SiteSetting.respond_to?(:faq_url) && SiteSetting.faq_url.present?
          links << "- [FAQ](#{SiteSetting.faq_url}): Frequently asked questions"
        end

        if SiteSetting.respond_to?(:tos_url) && SiteSetting.tos_url.present?
          links << "- [Terms of Service](#{SiteSetting.tos_url}): Community guidelines"
        end

        if SiteSetting.respond_to?(:privacy_policy_url) && SiteSetting.privacy_policy_url.present?
          links << "- [Privacy Policy](#{SiteSetting.privacy_policy_url}): Privacy information"
        end

        links.join("\n")
      end

      def posts_limit
        case SiteSetting.llms_txt_posts_limit
        when "small"
          500
        when "medium"
          2500
        when "large"
          5000
        when "all"
          nil
        else
          2500
        end
      end

      def cache_duration
        SiteSetting.llms_txt_cache_minutes.minutes
      end

      def build_sitemaps
        urls = []

        urls << "#{Discourse.base_url}/llms.txt"
        urls << "#{Discourse.base_url}/llms-full.txt"

        # Build proper path for subcategories (parent/child/id)
        Category.secured
          .where(read_restricted: false)
          .find_each do |category|
            path = category.parent_category_id ?
              "#{CGI.escape(category.parent_category.slug)}/#{CGI.escape(category.slug)}/#{category.id}" :
              "#{CGI.escape(category.slug)}/#{category.id}"
            urls << "#{Discourse.base_url}/c/#{path}/llms.txt"
          end

        # Limited to avoid massive file size
        Topic.visible
          .where(archetype: "regular")
          .joins(:category)
          .where(categories: { read_restricted: false })
          .where("topics.views >= ?", SiteSetting.llms_txt_min_views)
          .order(created_at: :desc)
          .limit(posts_limit || 5000)
          .find_each do |topic|
            urls << "#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}/llms.txt"
          end

        if SiteSetting.tagging_enabled
          Tag.find_each do |tag|
            urls << "#{Discourse.base_url}/tag/#{CGI.escape(tag.name)}/llms.txt"
          end
        end

        urls.join("\n")
      end

      def build_category_llms(category)
        category_url = "#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id}"

        content = <<~MARKDOWN
          # #{category.name}
          > Category: #{SiteSetting.title}

          #{category.description}

          **Category URL:** #{category_url}

        MARKDOWN

        subcategories = Category.secured
          .where(read_restricted: false, parent_category_id: category.id)
          .order(position: :asc)

        if subcategories.any?
          content += "## Subcategories\n\n"
          subcategories.each do |subcat|
            content += "- [#{subcat.name}](#{Discourse.base_url}/c/#{CGI.escape(subcat.slug)}/#{subcat.id}): #{subcat.description_excerpt}\n"
          end
          content += "\n"
        end

        topics = Topic.visible
          .where(category_id: category.id, archetype: "regular")
          .order(created_at: :desc)
          .limit(100)

        if topics.any?
          content += "## Topics\n\n"
          topics.each do |topic|
            content += "- [#{topic.title}](#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}) (#{topic.views} views, #{topic.posts_count - 1} replies)\n"
          end
        end

        content += <<~MARKDOWN

          **Canonical:** #{category_url}
          **Original content:** #{category_url}
        MARKDOWN

        content
      end

      def build_topic_llms(topic)
        topic_url = "#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}"

        content = <<~MARKDOWN
          # #{topic.title}

          **Category:** [#{topic.category.name}](#{Discourse.base_url}/c/#{CGI.escape(topic.category.slug)}/#{topic.category.id})
          **Created:** #{topic.created_at.strftime("%Y-%m-%d %H:%M UTC")}
          **Views:** #{topic.views}
          **Replies:** #{topic.posts_count - 1}
          **URL:** #{topic_url}

          ---

        MARKDOWN

        # Uses post.raw (original markdown) instead of post.cooked (rendered HTML)
        topic.posts
          .where(hidden: false, deleted_at: nil)
          .order(post_number: :asc)
          .each do |post|
            author = post.user ? post.user.username : "deleted"
            content += "## Post ##{post.post_number} by @#{author}\n\n"
            content += "#{post.raw}\n\n"
            content += "---\n\n"
          end

        content += <<~MARKDOWN

          **Canonical:** #{topic_url}
          **Original content:** #{topic_url}
        MARKDOWN

        content
      end

      def build_tag_llms(tag)
        tag_url = "#{Discourse.base_url}/tag/#{CGI.escape(tag.name)}"

        content = <<~MARKDOWN
          # Tag: #{tag.name}
          > #{SiteSetting.title}

          **Tag URL:** #{tag_url}

          ## Topics with this tag

        MARKDOWN

        topics = Topic.visible
          .joins(:tags, :category)
          .where(tags: { name: tag.name }, archetype: "regular")
          .where(categories: { read_restricted: false })
          .order(created_at: :desc)
          .limit(100)

        if topics.any?
          topics.each do |topic|
            category_name = topic.category&.name || "Uncategorized"
            content += "- [#{topic.title}](#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}) - #{category_name} (#{topic.views} views)\n"
          end
        else
          content += "No topics found with this tag.\n"
        end

        content += <<~MARKDOWN

          **Canonical:** #{tag_url}
          **Original content:** #{tag_url}
        MARKDOWN

        content
      end
    end
  end
end
