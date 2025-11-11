# frozen_string_literal: true

require 'cgi'

module DiscourseLlmsTxt
  class LlmsController < ::ApplicationController
    requires_plugin DiscourseLlmsTxt::PLUGIN_NAME

    skip_before_action :check_xhr, :preload_json, :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required

    before_action :check_enabled
    before_action :check_indexing_allowed
    before_action :track_access

    def index
      content = DiscourseLlmsTxt::Generator.generate_navigation

      respond_to do |format|
        format.text { render plain: content, content_type: "text/plain; charset=utf-8" }
        format.all { render plain: content, content_type: "text/plain; charset=utf-8" }
      end
    end

    def full
      content = DiscourseLlmsTxt::Generator.generate_full_content

      respond_to do |format|
        format.text { render plain: content, content_type: "text/plain; charset=utf-8" }
        format.all { render plain: content, content_type: "text/plain; charset=utf-8" }
      end
    end

    def sitemaps
      content = DiscourseLlmsTxt::Generator.generate_sitemaps

      respond_to do |format|
        format.text { render plain: content, content_type: "text/plain; charset=utf-8" }
        format.all { render plain: content, content_type: "text/plain; charset=utf-8" }
      end
    end

    def category
      category = Category.find_by_slug_path_with_id(params[:category_slug_path_with_id])
      return render_404 unless category && guardian.can_see?(category)

      canonical_url = "#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id}"
      response.headers['Link'] = "<#{canonical_url}>; rel=\"canonical\""

      content = DiscourseLlmsTxt::Generator.generate_category_llms(category)

      respond_to do |format|
        format.text { render plain: content, content_type: "text/plain; charset=utf-8" }
        format.all { render plain: content, content_type: "text/plain; charset=utf-8" }
      end
    end

    def topic
      topic = Topic.find_by(id: params[:topic_id])
      return render_404 unless topic && guardian.can_see?(topic)

      canonical_url = "#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}"
      response.headers['Link'] = "<#{canonical_url}>; rel=\"canonical\""

      content = DiscourseLlmsTxt::Generator.generate_topic_llms(topic)

      respond_to do |format|
        format.text { render plain: content, content_type: "text/plain; charset=utf-8" }
        format.all { render plain: content, content_type: "text/plain; charset=utf-8" }
      end
    end

    def tag
      tag = Tag.find_by_name(params[:tag_name])
      return render_404 unless tag && SiteSetting.tagging_enabled

      canonical_url = "#{Discourse.base_url}/tag/#{CGI.escape(tag.name)}"
      response.headers['Link'] = "<#{canonical_url}>; rel=\"canonical\""

      content = DiscourseLlmsTxt::Generator.generate_tag_llms(tag)

      respond_to do |format|
        format.text { render plain: content, content_type: "text/plain; charset=utf-8" }
        format.all { render plain: content, content_type: "text/plain; charset=utf-8" }
      end
    end

    private

    def render_404
      render plain: "Not found", status: :not_found
    end

    def check_enabled
      unless SiteSetting.llms_txt_enabled
        render plain: "llms.txt generator is disabled", status: :not_found
      end
    end

    def check_indexing_allowed
      unless SiteSetting.llms_txt_allow_indexing
        render plain: "Indexing is not allowed", status: :forbidden
      end
    end

    def track_access
      key = "access_count_#{action_name}"
      current_count = PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, key).to_i
      PluginStore.set(DiscourseLlmsTxt::PLUGIN_NAME, key, current_count + 1)

      PluginStore.set(
        DiscourseLlmsTxt::PLUGIN_NAME,
        "last_access_#{action_name}",
        Time.now.to_i
      )
    rescue => e
      Rails.logger.warn("Failed to track llms.txt access: #{e.message}")
    end
  end
end
