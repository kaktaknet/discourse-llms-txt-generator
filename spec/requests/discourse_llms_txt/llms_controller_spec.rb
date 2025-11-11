# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseLlmsTxt::LlmsController do
  before do
    SiteSetting.llms_txt_enabled = true
    SiteSetting.llms_txt_allow_indexing = true
  end

  describe "#index" do
    it "returns llms.txt navigation file" do
      get "/llms.txt"

      expect(response.status).to eq(200)
      expect(response.content_type).to include("text/plain")
      expect(response.body).to include(SiteSetting.title)
      expect(response.body).to include("## Categories and Subcategories")
      expect(response.body).to include("## Latest Topics")
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.llms_txt_enabled = false

      get "/llms.txt"

      expect(response.status).to eq(404)
    end

    it "returns 403 when indexing is not allowed" do
      SiteSetting.llms_txt_allow_indexing = false

      get "/llms.txt"

      expect(response.status).to eq(403)
    end

    it "includes site description" do
      get "/llms.txt"

      expect(response.body).to include(SiteSetting.site_description)
    end

    it "tracks access count" do
      expect {
        get "/llms.txt"
      }.to change {
        PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "access_count_index").to_i
      }.by(1)
    end
  end

  describe "#full" do
    fab!(:topic) { Fabricate(:topic, views: 100) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    it "returns llms-full.txt content file" do
      get "/llms-full.txt"

      expect(response.status).to eq(200)
      expect(response.content_type).to include("text/plain")
      expect(response.body).to include("Full Content")
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.llms_txt_enabled = false

      get "/llms-full.txt"

      expect(response.status).to eq(404)
    end

    it "returns 403 when indexing is not allowed" do
      SiteSetting.llms_txt_allow_indexing = false

      get "/llms-full.txt"

      expect(response.status).to eq(403)
    end

    it "includes topic with sufficient views" do
      SiteSetting.llms_txt_min_views = 50

      get "/llms-full.txt"

      expect(response.body).to include(topic.title)
    end

    it "excludes topic with insufficient views" do
      SiteSetting.llms_txt_min_views = 200

      get "/llms-full.txt"

      expect(response.body).not_to include(topic.title)
    end

    it "tracks access count" do
      expect {
        get "/llms-full.txt"
      }.to change {
        PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "access_count_full").to_i
      }.by(1)
    end
  end

  describe "#sitemaps" do
    it "returns sitemaps.txt file" do
      get "/sitemaps.txt"

      expect(response.status).to eq(200)
      expect(response.content_type).to include("text/plain")
      expect(response.body).to include("/llms.txt")
      expect(response.body).to include("/llms-full.txt")
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.llms_txt_enabled = false

      get "/sitemaps.txt"

      expect(response.status).to eq(404)
    end
  end

  describe "#category" do
    fab!(:category) { Fabricate(:category) }

    it "returns category llms.txt" do
      get "/c/#{category.slug}/#{category.id}/llms.txt"

      expect(response.status).to eq(200)
      expect(response.content_type).to include("text/plain")
      expect(response.body).to include(category.name)
    end

    it "includes canonical URL in Link header" do
      get "/c/#{category.slug}/#{category.id}/llms.txt"

      canonical_url = "#{Discourse.base_url}/c/#{category.slug}/#{category.id}"
      expect(response.headers['Link']).to eq("<#{canonical_url}>; rel=\"canonical\"")
    end

    it "includes canonical URL in response body" do
      get "/c/#{category.slug}/#{category.id}/llms.txt"

      canonical_url = "#{Discourse.base_url}/c/#{category.slug}/#{category.id}"
      expect(response.body).to include("**Canonical:** #{canonical_url}")
      expect(response.body).to include("**Original content:** #{canonical_url}")
    end

    it "returns 404 for non-existent category" do
      get "/c/non-existent/999999/llms.txt"

      expect(response.status).to eq(404)
    end
  end

  describe "#topic" do
    fab!(:topic) { Fabricate(:topic) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    it "returns topic llms.txt" do
      get "/t/#{topic.slug}/#{topic.id}/llms.txt"

      expect(response.status).to eq(200)
      expect(response.content_type).to include("text/plain")
      expect(response.body).to include(topic.title)
      expect(response.body).to include(post.raw)
    end

    it "includes canonical URL in Link header" do
      get "/t/#{topic.slug}/#{topic.id}/llms.txt"

      canonical_url = "#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}"
      expect(response.headers['Link']).to eq("<#{canonical_url}>; rel=\"canonical\"")
    end

    it "includes canonical URL in response body" do
      get "/t/#{topic.slug}/#{topic.id}/llms.txt"

      canonical_url = "#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}"
      expect(response.body).to include("**Canonical:** #{canonical_url}")
      expect(response.body).to include("**Original content:** #{canonical_url}")
    end

    it "returns 404 for non-existent topic" do
      get "/t/non-existent/999999/llms.txt"

      expect(response.status).to eq(404)
    end
  end

  describe "#tag" do
    fab!(:tag) { Fabricate(:tag) }

    before do
      SiteSetting.tagging_enabled = true
    end

    it "returns tag llms.txt" do
      get "/tag/#{tag.name}/llms.txt"

      expect(response.status).to eq(200)
      expect(response.content_type).to include("text/plain")
      expect(response.body).to include(tag.name)
    end

    it "includes canonical URL in Link header" do
      get "/tag/#{tag.name}/llms.txt"

      canonical_url = "#{Discourse.base_url}/tag/#{tag.name}"
      expect(response.headers['Link']).to eq("<#{canonical_url}>; rel=\"canonical\"")
    end

    it "includes canonical URL in response body" do
      get "/tag/#{tag.name}/llms.txt"

      canonical_url = "#{Discourse.base_url}/tag/#{tag.name}"
      expect(response.body).to include("**Canonical:** #{canonical_url}")
      expect(response.body).to include("**Original content:** #{canonical_url}")
    end

    it "returns 404 for non-existent tag" do
      get "/tag/non-existent-tag/llms.txt"

      expect(response.status).to eq(404)
    end

    it "returns 404 when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      get "/tag/#{tag.name}/llms.txt"

      expect(response.status).to eq(404)
    end
  end
end
