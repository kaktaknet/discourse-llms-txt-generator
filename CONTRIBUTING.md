# Contributing to discourse-llms-txt-generator

Thank you for considering contributing! 🎉

This guide provides comprehensive information for developers.
You'll learn how discourse-llms-txt-generator works internally and how to extend it.

---

## 📋 Table of Contents

### Getting Started
- [Code of Conduct](#-code-of-conduct)
- [How Can I Contribute?](#-how-can-i-contribute)
- [Development Setup](#-development-setup)

### Understanding the Project
- [Architecture Overview](#-architecture-overview)
- [How It Works](#-how-it-works)
- [Data Flow Pipeline](#-data-flow-pipeline)
- [Component Deep Dive](#-component-deep-dive)

### Development
- [Project Structure](#-project-structure)
- [Coding Standards](#-coding-standards)
- [Testing Guidelines](#-testing-guidelines)

### Contributing Code
- [Future Enhancement Ideas](#-future-enhancement-ideas)
- [Submitting Pull Requests](#-submitting-pull-requests)

### Resources
- [Development Tips](#-development-tips)
- [Additional Resources](#-additional-resources)

---

## 📜 Code of Conduct

This project follows [Discourse Community Guidelines](https://meta.discourse.org/guidelines).

**Key principles:**
- Be kind and respectful
- Provide constructive feedback
- Focus on the code, not the person
- Assume positive intent
- Help newcomers learn

---

## 🤝 How Can I Contribute?

### Reporting Bugs

**Before submitting:**
1. Check [existing issues](https://github.com/kaktaknet/discourse-llms-txt-generator/issues)
2. Update to latest version
3. Clear cache and test: `DiscourseLlmsTxt::Generator.clear_cache`
4. Check logs: `tail -f log/production.log | grep llms`

**Bug report template:**
```markdown
### Environment
- Plugin version: X.Y.Z
- Discourse version: X.Y.Z
- Ruby version: 3.2.X
- Platform: Docker / Manual

### Steps to Reproduce
1. Navigate to Admin → Settings
2. Change llms_txt_enabled to true
3. Visit /llms.txt

### Expected vs Actual
Expected: File should be generated
Actual: 404 error

### Logs
[Paste relevant log entries]
```

### Suggesting Features

**Feature request template:**
```markdown
### Problem Statement
What problem does this solve?

### Proposed Solution
How should it work?

### Use Case
Real-world scenario where this helps

### Alternatives Considered
Other approaches you've thought about
```

---

## 🔧 Development Setup

### Prerequisites

- Discourse development environment ([Setup Guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-for-development-using-docker/102009))
- Ruby 3.2+
- PostgreSQL 13+
- Redis 6+

### Install Plugin

```bash
# Clone into Discourse plugins directory
cd /var/www/discourse/plugins
git clone https://github.com/YOUR_USERNAME/discourse-llms-txt-generator.git

# Install dependencies
cd /var/www/discourse
bundle install

# Run migrations (if any)
bundle exec rake db:migrate

# Start development server
bundle exec rails s
```

### Verify Installation

```bash
# Check plugin loaded
rails c
> Discourse.plugins.map(&:name)
# Should include "discourse-llms-txt-generator"

# Test endpoints
curl http://localhost:3000/llms.txt
curl http://localhost:3000/llms-full.txt
```

---

## 🏗️ Architecture Overview

### Design Philosophy

The project follows these core principles:

**1. On-Demand Generation**
- No pre-generated files stored on disk
- Files created dynamically when requested
- Zero storage overhead

**Why it matters:** Eliminates sync issues, always returns current state, no maintenance needed.

**Example:**
```ruby
def index
  # No file read - generate fresh content
  content = DiscourseLlmsTxt::Generator.build_navigation
  render plain: content
end
```

**2. Smart Caching**
- Cache expensive operations (navigation file)
- Don't cache what changes frequently (full content)
- Auto-invalidate on content changes

**Why it matters:** Balance between performance and freshness.

**Example:**
```ruby
# Cache navigation (60 min default)
Discourse.cache.fetch("llms_txt_navigation", expires_in: cache_minutes.minutes) do
  build_navigation
end

# Don't cache full content (too large, changes often)
def build_full_content
  # Always fresh
end
```

**3. Permission-Aware**
- Respect Discourse's Guardian system
- Private categories excluded automatically
- Per-request permission checks

**Why it matters:** Security by design, no accidental leaks.

**Example:**
```ruby
# SQL-level filtering
.where(read_restricted: false)

# Controller-level checks
return render_404 unless guardian.can_see?(category)
```

**4. SEO-Safe**
- Canonical URLs in headers
- No duplicate content penalties
- Standards-compliant (RFC 6596)

**Why it matters:** Plugin enhances SEO, doesn't harm it.

**Example:**
```ruby
# Canonical header
response.headers['Link'] = "<#{canonical_url}>; rel=\"canonical\""
```

**5. View Connector Integration**
- Use Discourse's plugin system properly
- No event hacking
- Clean, maintainable code

**Why it matters:** Works across Discourse versions, no breaking changes.

**Example:**
```erb
<!-- app/views/connectors/robots_txt_index/llms_txt.html.erb -->
<%- if SiteSetting.llms_txt_enabled %>
# LLM Documentation Files
<%- end %>
```

### High-Level Architecture

```
User Request (GET /llms.txt)
         |
         v
    Controller (llms_controller.rb)
         |
         ├─> Check Settings (enabled? allow_indexing?)
         |
         ├─> Check Cache (Discourse.cache)
         |       |
         |       ├─> Cache Hit → Return cached content
         |       |
         |       └─> Cache Miss → Generate new content
         |                |
         v                v
    Generator (generator.rb)
         |
         ├─> Query Database (Category, Topic, Tag)
         |
         ├─> Build Markdown Content
         |
         ├─> Apply Filters (permissions, views)
         |
         └─> Return Content
                |
                v
         Controller → Render plain text → User
```

**Component Interaction:**

```
plugin.rb (Entry Point)
    ↓
Routes (Discourse::Application.routes)
    ↓
Controller Actions (LlmsController)
    ↓
Generator Methods (DiscourseLlmsTxt::Generator)
    ↓
Database Queries (Category, Topic, Post, Tag)
    ↓
Markdown Output → User
```

---

## 🔍 How It Works

### Lifecycle: From Request to Response

```
Step 1: User/Bot requests /llms.txt
         ↓
Step 2: Rails routes to LlmsController#index
         ↓
Step 3: Controller checks settings
         ↓
Step 4: Check cache (hit/miss)
         ↓
Step 5: Generator builds content
         ↓
Step 6: Return plain/text response
         ↓
Result: LLM receives structured markdown
```

**Detailed breakdown:**

#### Step 1: Request Routing

```ruby
# plugin.rb, line 22-31
Discourse::Application.routes.append do
  get "/llms.txt" => "discourse_llms_txt/llms#index"
  get "/llms-full.txt" => "discourse_llms_txt/llms#full"
  get "/sitemaps.txt" => "discourse_llms_txt/llms#sitemaps"

  # Dynamic routes with wildcards
  get "/c/:category_slug_path_with_id/llms.txt" => "discourse_llms_txt/llms#category",
      constraints: { category_slug_path_with_id: /.*/ }

  get "/t/:topic_slug/:topic_id/llms.txt" => "discourse_llms_txt/llms#topic"
  get "/tag/:tag_name/llms.txt" => "discourse_llms_txt/llms#tag"
end
```

**Explanation:**
- Rails routes map URL patterns to controller actions
- `constraints: { category_slug_path_with_id: /.*/ }` allows matching full category paths including subcategories like `/c/parent/child/123/llms.txt`

**Why this way:**
- Standard Rails RESTful routing
- Clean URLs for SEO
- Supports nested categories with wildcard constraint

**Key techniques:**
- Route wildcards for flexible matching
- Explicit controller namespace (`discourse_llms_txt/llms`)

#### Step 2: Controller Action

```ruby
# app/controllers/discourse_llms_txt/llms_controller.rb
def index
  # 1. Check if plugin enabled
  return render_404 unless SiteSetting.llms_txt_enabled

  # 2. Check if indexing allowed
  return render_403 unless SiteSetting.llms_txt_allow_indexing

  # 3. Track access
  track_access("index")

  # 4. Get or generate content
  content = DiscourseLlmsTxt::Generator.build_navigation

  # 5. Return as plain text
  render plain: content, content_type: "text/plain; charset=utf-8"
end
```

**Explanation:**
- Settings checked before any work done (fail fast)
- Analytics tracked for monitoring
- Content generated via Generator module
- Plain text response (not HTML)

**Why this way:**
- Security: Settings enforce access control
- Performance: Early exit if disabled
- Separation of concerns: Controller handles HTTP, Generator handles business logic

**Key techniques:**
- Guard clauses for early returns
- Module delegation for content generation
- Explicit content-type for LLM parsers

#### Step 3: Cache Check

```ruby
# lib/discourse_llms_txt/generator.rb
def self.build_navigation
  cache_minutes = SiteSetting.llms_txt_cache_minutes || 60

  Discourse.cache.fetch("llms_txt_navigation", expires_in: cache_minutes.minutes) do
    # Expensive operation only runs on cache miss
    generate_navigation_content
  end
end
```

**Explanation:**
- `Discourse.cache.fetch` checks cache first
- If cache hit: Returns cached content instantly
- If cache miss: Runs block, stores result, returns content
- Configurable TTL via settings

**Why this way:**
- Discourse's built-in cache infrastructure (Redis)
- Automatic expiration
- Thread-safe

**Key techniques:**
- Cache-aside pattern
- Configurable TTL
- Automatic serialization/deserialization

#### Step 4: Content Generation

```ruby
# lib/discourse_llms_txt/generator.rb
def self.generate_navigation_content
  output = StringIO.new

  # Site header
  output.puts "# #{SiteSetting.title}"
  output.puts "> #{SiteSetting.site_description}" if SiteSetting.site_description.present?
  output.puts

  # Intro text
  output.puts SiteSetting.llms_txt_intro_text if SiteSetting.llms_txt_intro_text.present?
  output.puts

  # Categories
  output.puts "## Categories and Subcategories"
  Category.where(read_restricted: false).order(:position).each do |category|
    output.puts "### [#{category.name}](#{category_url(category)})"
    output.puts category.description if category.description.present?

    # Subcategories
    category.subcategories.where(read_restricted: false).each do |subcat|
      output.puts "- [#{subcat.name}](#{category_url(subcat)}): #{subcat.description}"
    end
    output.puts
  end

  # Latest topics
  output.puts "## Latest Topics"
  latest_topics.limit(SiteSetting.llms_txt_latest_topics_count).each do |topic|
    date = topic.created_at.strftime("%Y-%m-%d")
    output.puts "- [#{topic.title}](#{topic_url(topic)}) - #{topic.category.name} (#{date})"
  end

  output.string
end
```

**Explanation:**
- `StringIO` for efficient string building
- Database queries for categories and topics
- Markdown formatting for structure
- URL helpers for proper links

**Why this way:**
- SQL filtering (`read_restricted: false`) prevents private content leaks
- StringIO faster than string concatenation
- Markdown is LLM-friendly format

**Key techniques:**
- StringIO for performance
- Eager loading to avoid N+1 queries
- SQL-level security filtering

#### Step 5: URL Encoding

```ruby
# lib/discourse_llms_txt/generator.rb
require 'cgi'

def self.category_url(category)
  "#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id}"
end

def self.topic_url(topic)
  "#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}"
end

def self.tag_url(tag_name)
  "#{Discourse.base_url}/tag/#{CGI.escape(tag_name)}"
end
```

**Explanation:**
- `CGI.escape` properly encodes international characters
- Cyrillic "тег-3" becomes "%D1%82%D0%B5%D0%B3-3"
- RFC 3986 compliant URLs

**Why this way:**
- Without encoding: URLs break for non-ASCII characters
- With encoding: Works correctly for all languages
- Standard library (`cgi`) - no dependencies

**Key techniques:**
- RFC 3986 URL encoding
- Applied to all dynamic URL components (slugs, tag names)

#### Step 6: Canonical URLs

```ruby
# app/controllers/discourse_llms_txt/llms_controller.rb
def category
  category = Category.find_by_slug_path_with_id(params[:category_slug_path_with_id])
  return render_404 unless category && guardian.can_see?(category)

  # HTTP Link header (RFC 6596)
  canonical_url = "#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id}"
  response.headers['Link'] = "<#{canonical_url}>; rel=\"canonical\""

  # Content footer
  content = DiscourseLlmsTxt::Generator.build_category_llms(category)
  content += "\n\n**Canonical:** #{canonical_url}\n"
  content += "**Original content:** #{canonical_url}\n"

  render plain: content, content_type: "text/plain; charset=utf-8"
end
```

**Explanation:**
- HTTP `Link` header tells search engines about canonical URL
- Content footer provides human/LLM-readable attribution
- Points to original forum URL, not llms.txt URL

**Why this way:**
- Prevents duplicate content SEO penalties
- Search engines index the canonical (forum) URL
- AI systems know where content originates

**Key techniques:**
- RFC 6596 Link header
- Dual attribution (header + content)
- Proper SEO protection

---

## 🔄 Data Flow Pipeline

### Pipeline Overview

```
Database → Query → Filter → Transform → Format → Output
   ↓         ↓       ↓         ↓          ↓        ↓
Topics → WHERE → Permissions → Markdown → Cache → HTTP
```

### Step 1: Database Query

```ruby
# lib/discourse_llms_txt/generator.rb
def self.latest_topics
  Topic
    .joins(:category)
    .where("categories.read_restricted = ?", false)  # Security filter
    .where(visible: true, archived: false)           # Visibility filter
    .order(created_at: :desc)                        # Most recent first
end
```

**What happens:**
- SQL JOIN between topics and categories tables
- Filter out private categories at SQL level
- Filter out hidden/archived topics
- Sort by creation date descending

**Why this way:**
- SQL-level filtering most efficient
- Database handles sorting/filtering (not Ruby)
- Single query, no N+1 problem

**Key techniques:**
- ActiveRecord query composition
- SQL-level security filtering
- Efficient JOINs

### Step 2: Content Filtering

```ruby
# lib/discourse_llms_txt/generator.rb
def self.topics_for_full_content
  min_views = SiteSetting.llms_txt_min_views || 50
  limit = case SiteSetting.llms_txt_posts_limit
    when "small" then 500
    when "medium" then 2500
    when "large" then 5000
    else nil  # No limit
  end

  query = latest_topics.where("views >= ?", min_views)
  query = query.limit(limit) if limit
  query
end
```

**What happens:**
- Apply minimum views threshold
- Apply configurable topic limit
- Return filtered query (lazy evaluation)

**Why this way:**
- Configurable via admin settings
- Performance control for large forums
- Quality filter (min_views)

**Key techniques:**
- Settings-driven behavior
- Lazy query evaluation (no execution until needed)
- Flexible limits

### Step 3: Markdown Generation

```ruby
# lib/discourse_llms_txt/generator.rb
def self.build_topic_llms(topic)
  output = StringIO.new

  # Header with metadata
  output.puts "# #{topic.title}"
  output.puts
  output.puts "**Category:** [#{topic.category.name}](#{category_url(topic.category)})"
  output.puts "**Created:** #{topic.created_at.utc.strftime('%Y-%m-%d %H:%M UTC')}"
  output.puts "**Views:** #{topic.views}"
  output.puts "**Replies:** #{topic.posts_count - 1}"

  topic_url_str = topic_url(topic)
  output.puts "**URL:** #{topic_url_str}"
  output.puts
  output.puts "---"
  output.puts

  # Posts
  topic.posts.order(:post_number).each do |post|
    output.puts "## Post ##{post.post_number} by @#{post.user.username}"
    output.puts
    output.puts post.raw  # Original markdown, not HTML
    output.puts
    output.puts "---"
    output.puts
  end

  # Canonical URLs
  output.puts "**Canonical:** #{topic_url_str}"
  output.puts "**Original content:** #{topic_url_str}"

  output.string
end
```

**What happens:**
- Build structured markdown with topic metadata
- Include all posts in chronological order
- Use `post.raw` (original markdown) not `post.cooked` (HTML)
- Add canonical URL attribution

**Why this way:**
- LLMs prefer markdown over HTML
- `post.raw` preserves original formatting
- Metadata helps LLMs understand context

**Key techniques:**
- StringIO for efficient string building
- Markdown structure with headers
- Canonical URL attribution

### Step 4: Cache Management

```ruby
# lib/discourse_llms_txt/generator.rb
CACHE_KEY = "llms_txt_navigation"

def self.clear_cache
  Discourse.cache.delete(CACHE_KEY)
  Rails.logger.info "[llms.txt] Cache cleared"
end

# plugin.rb
on(:post_created) do |post|
  DiscourseLlmsTxt::Generator.clear_cache if SiteSetting.llms_txt_enabled
end

on(:post_edited) do |post|
  DiscourseLlmsTxt::Generator.clear_cache if SiteSetting.llms_txt_enabled
end
```

**What happens:**
- Cache automatically cleared when posts created/edited
- Ensures content stays fresh
- Logs cache operations

**Why this way:**
- Event-driven cache invalidation
- Balance between performance and freshness
- No stale content served

**Key techniques:**
- Discourse event hooks (`on(:post_created)`)
- Automatic invalidation
- Logging for debugging

### Step 5: robots.txt Integration via View Connector

```erb
<!-- app/views/connectors/robots_txt_index/llms_txt.html.erb -->
<%- if SiteSetting.llms_txt_enabled %>

# LLM Documentation Files
<%- if SiteSetting.llms_txt_allow_indexing %>
Allow: /llms.txt
Allow: /llms-full.txt
Allow: /sitemaps.txt
Allow: /c/*/llms.txt
Allow: /t/*/llms.txt
Allow: /tag/*/llms.txt

Sitemap: <%= Discourse.base_url %>/sitemaps.txt
<%- else %>
Disallow: /llms.txt
Disallow: /llms-full.txt
Disallow: /sitemaps.txt
Disallow: /c/*/llms.txt
Disallow: /t/*/llms.txt
Disallow: /tag/*/llms.txt
<%- end %>

<%- if SiteSetting.llms_txt_blocked_user_agents.present? %>
<%- blocked_agents = SiteSetting.llms_txt_blocked_user_agents.split(',').map(&:strip).reject(&:empty?) %>
<%- if blocked_agents.any? %>
# Blocked bots for llms.txt files
<%- blocked_agents.each do |agent| %>
User-agent: <%= agent %>
Disallow: /llms.txt
Disallow: /llms-full.txt
Disallow: /sitemaps.txt
Disallow: /c/*/llms.txt
Disallow: /t/*/llms.txt
Disallow: /tag/*/llms.txt
<%- end %>
<%- end %>
<%- end %>
<%- end %>
```

**What happens:**
- Discourse's `robots_txt/index.erb` template includes: `<%= server_plugin_outlet "robots_txt_index" %>`
- Our view connector automatically injects content into that outlet
- robots.txt is dynamically generated with our rules

**Why this way:**
- The previous approach using `on(:robots_txt)` event **didn't work** because that event doesn't exist in Discourse
- View connectors are the **correct** way to extend Discourse templates
- Works across all Discourse versions
- Clean, maintainable code

**Key techniques:**
- Discourse plugin outlets (server-side)
- ERB templating
- Settings-driven content

---

## 🧩 Component Deep Dive

### Component 1: LlmsController

**Purpose:** Handle HTTP requests for llms.txt files

**Responsibilities:**
- Route handling
- Settings enforcement
- Permission checks
- Response formatting
- Analytics tracking

**Key Methods:**

```ruby
class DiscourseLlmsTxt::LlmsController < ::ApplicationController
  skip_before_action :check_xhr, :preload_json, :redirect_to_login_if_required

  # GET /llms.txt
  def index
    return render_404 unless SiteSetting.llms_txt_enabled
    return render_403 unless SiteSetting.llms_txt_allow_indexing

    track_access("index")
    content = DiscourseLlmsTxt::Generator.build_navigation
    render plain: content, content_type: "text/plain; charset=utf-8"
  end

  # GET /c/:category_slug_path_with_id/llms.txt
  def category
    category = Category.find_by_slug_path_with_id(params[:category_slug_path_with_id])
    return render_404 unless category && guardian.can_see?(category)

    canonical_url = "#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id}"
    response.headers['Link'] = "<#{canonical_url}>; rel=\"canonical\""

    content = DiscourseLlmsTxt::Generator.build_category_llms(category)
    content += "\n\n**Canonical:** #{canonical_url}\n"
    content += "**Original content:** #{canonical_url}\n"

    render plain: content, content_type: "text/plain; charset=utf-8"
  end

  private

  def track_access(type)
    PluginStore.set(DiscourseLlmsTxt::PLUGIN_NAME, "access_count_#{type}",
                    PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "access_count_#{type}").to_i + 1)
    PluginStore.set(DiscourseLlmsTxt::PLUGIN_NAME, "last_access_#{type}", Time.zone.now)
  end

  def render_403
    render plain: "Access denied", status: 403
  end

  def render_404
    raise Discourse::NotFound
  end
end
```

**Design Pattern:** Front Controller pattern - single entry point for all llms.txt requests

**Example Usage:**
```bash
curl https://forum.com/llms.txt
# → Calls index action
# → Returns navigation file

curl https://forum.com/c/support/2/llms.txt
# → Calls category action
# → Returns category-specific file
```

---

### Component 2: Generator Module

**Purpose:** Generate llms.txt content from database data

**Responsibilities:**
- Database queries
- Content formatting
- Markdown generation
- Cache management
- URL building

**Key Methods:**

```ruby
module DiscourseLlmsTxt
  class Generator
    CACHE_KEY = "llms_txt_navigation"
    PLUGIN_NAME = "discourse-llms-txt-generator"

    # Main navigation file
    def self.build_navigation
      cache_minutes = SiteSetting.llms_txt_cache_minutes || 60
      Discourse.cache.fetch(CACHE_KEY, expires_in: cache_minutes.minutes) do
        generate_navigation_content
      end
    end

    # Category-specific file
    def self.build_category_llms(category)
      output = StringIO.new

      output.puts "# #{category.name}"
      output.puts "> Category: #{SiteSetting.title}"
      output.puts
      output.puts category.description if category.description.present?
      output.puts

      # Subcategories
      if category.subcategories.where(read_restricted: false).any?
        output.puts "## Subcategories"
        output.puts
        category.subcategories.where(read_restricted: false).each do |subcat|
          output.puts "- [#{subcat.name}](#{category_url(subcat)}): #{subcat.description}"
        end
        output.puts
      end

      # Topics in this category
      output.puts "## Topics"
      output.puts
      category.topics.where(visible: true, archived: false)
        .order(views: :desc).limit(100).each do |topic|
        output.puts "- [#{topic.title}](#{topic_url(topic)}) (#{topic.views} views, #{topic.posts_count - 1} replies)"
      end

      output.string
    end

    # Clear cache
    def self.clear_cache
      Discourse.cache.delete(CACHE_KEY)
      Rails.logger.info "[llms.txt] Cache cleared"
    end

    private

    def self.category_url(category)
      "#{Discourse.base_url}/c/#{CGI.escape(category.slug)}/#{category.id}"
    end

    def self.topic_url(topic)
      "#{Discourse.base_url}/t/#{CGI.escape(topic.slug)}/#{topic.id}"
    end
  end
end
```

**Design Pattern:** Service Object pattern - encapsulates business logic

**Example Usage:**
```ruby
# From Rails console
content = DiscourseLlmsTxt::Generator.build_navigation
# → Returns full navigation markdown

DiscourseLlmsTxt::Generator.clear_cache
# → Clears cached content
```

---

### Component 3: Engine (Routes)

**Purpose:** Mount plugin routes into Discourse application

**Responsibilities:**
- Route configuration
- Plugin initialization

**Key Code:**

```ruby
# lib/discourse_llms_txt/engine.rb
module DiscourseLlmsTxt
  class Engine < ::Rails::Engine
    engine_name "discourse_llms_txt"
    isolate_namespace DiscourseLlmsTxt
  end
end
```

**Design Pattern:** Rails Engine - modular Rails application

**Why minimal:**
- Routes are defined in `plugin.rb` (Discourse convention)
- Engine just provides namespace isolation

---

### Component 4: Scheduled Job

**Purpose:** Hourly cache refresh with smart checking

**Responsibilities:**
- Check for new content
- Regenerate cache when needed
- Skip regeneration when not needed

**Key Methods:**

```ruby
# app/jobs/scheduled/update_llms_txt_cache.rb
module Jobs
  class UpdateLlmsTxtCache < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      return unless SiteSetting.llms_txt_enabled

      last_update = PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "last_cache_update")

      # Check if there's new content since last update
      has_new_content = if last_update
        Topic.where("created_at > ?", last_update).exists? ||
        Category.where("updated_at > ?", last_update).exists?
      else
        true  # First run
      end

      if has_new_content
        Rails.logger.info "[llms.txt] Updating cache due to new content"
        DiscourseLlmsTxt::Generator.clear_cache
        DiscourseLlmsTxt::Generator.build_navigation  # Regenerate
        PluginStore.set(DiscourseLlmsTxt::PLUGIN_NAME, "last_cache_update", Time.zone.now)
        Rails.logger.info "[llms.txt] Cache updated successfully"
      else
        Rails.logger.info "[llms.txt] No new content, skipping cache update"
      end
    end
  end
end
```

**Design Pattern:** Scheduled Job pattern with smart checking

**Example Usage:**
```ruby
# Runs automatically every hour via Sidekiq

# Manual trigger for testing:
Jobs::UpdateLlmsTxtCache.new.execute({})
```

---

## 📁 Project Structure

```
discourse-llms-txt-generator/
│
├── plugin.rb                          # Entry point, routes, event hooks
│   ├── after_initialize block         # Main initialization
│   ├── Routes configuration           # URL mappings
│   ├── Sitemap integration            # DiscourseEvent hooks
│   └── Event hooks                    # post_created, post_edited
│
├── app/
│   ├── controllers/
│   │   └── discourse_llms_txt/
│   │       └── llms_controller.rb     # HTTP request handlers
│   │           ├── index              # GET /llms.txt
│   │           ├── full               # GET /llms-full.txt
│   │           ├── sitemaps           # GET /sitemaps.txt
│   │           ├── category           # GET /c/:slug/llms.txt
│   │           ├── topic              # GET /t/:slug/:id/llms.txt
│   │           └── tag                # GET /tag/:name/llms.txt
│   │
│   ├── jobs/
│   │   └── scheduled/
│   │       └── update_llms_txt_cache.rb  # Hourly cache refresh job
│   │           └── execute            # Smart cache regeneration
│   │
│   └── views/
│       └── connectors/
│           └── robots_txt_index/
│               └── llms_txt.html.erb  # robots.txt integration
│                   ├── Allow/Disallow rules
│                   └── Blocked user agents
│
├── lib/
│   ├── discourse_llms_txt/
│   │   ├── engine.rb                  # Rails Engine configuration
│   │   │   └── Namespace isolation
│   │   │
│   │   └── generator.rb               # Content generation logic
│   │       ├── build_navigation       # Main navigation file
│   │       ├── build_full_content     # Full content index
│   │       ├── build_sitemaps         # Sitemap index
│   │       ├── build_category_llms    # Category-specific
│   │       ├── build_topic_llms       # Topic-specific
│   │       ├── build_tag_llms         # Tag-specific
│   │       └── clear_cache            # Cache invalidation
│   │
│   └── tasks/
│       └── llms_txt.rake              # Maintenance rake tasks
│           ├── llms_txt:refresh       # Clear caches, regenerate
│           └── llms_txt:check         # Verify configuration
│
├── config/
│   ├── locales/
│   │   ├── server.en.yml              # English translations
│   │   │   └── Site settings descriptions
│   │   │
│   │   └── server.ru.yml              # Russian translations
│   │       └── Настройки на русском
│   │
│   └── settings.yml                   # Plugin settings definitions
│       ├── llms_txt_enabled
│       ├── llms_txt_allow_indexing
│       ├── llms_txt_blocked_user_agents
│       ├── llms_txt_min_views
│       ├── llms_txt_posts_limit
│       ├── llms_txt_include_excerpts
│       └── llms_txt_cache_minutes
│
├── spec/
│   └── requests/
│       └── discourse_llms_txt/
│           └── llms_controller_spec.rb  # Integration tests
│               ├── describe "#index"
│               ├── describe "#full"
│               ├── describe "#sitemaps"
│               ├── describe "#category"
│               ├── describe "#topic"
│               └── describe "#tag"
│
├── README.md                          # User documentation
├── CONTRIBUTING.md                    # Developer guide (this file)
├── CHANGELOG.md                       # Version history
└── LICENSE                            # MIT License
```

**Component Descriptions:**

**plugin.rb:**
- Purpose: Plugin entry point and configuration
- Main responsibilities:
  - Define routes
  - Register event hooks
  - Integrate with sitemap
  - Load dependencies

**llms_controller.rb:**
- Purpose: Handle all HTTP requests
- Main responsibilities:
  - Validate settings
  - Check permissions
  - Generate responses
  - Track analytics
  - Set canonical headers

**generator.rb:**
- Purpose: Business logic for content generation
- Main responsibilities:
  - Database queries
  - Markdown formatting
  - URL building
  - Cache management

**update_llms_txt_cache.rb:**
- Purpose: Background job for cache maintenance
- Main responsibilities:
  - Hourly execution
  - Smart content checking
  - Cache regeneration

**llms_txt.html.erb:**
- Purpose: robots.txt integration
- Main responsibilities:
  - Allow/Disallow rules
  - Sitemap directive
  - Bot blocking

---

## 💻 Coding Standards

### Ruby Style Guide

Follow [Ruby Style Guide](https://rubystyle.guide/).

**Key rules:**
- Use 2 spaces for indentation (never tabs)
- Keep lines under 100 characters when possible
- Use `frozen_string_literal: true` comment
- Prefer double quotes for strings with interpolation
- Use single quotes for static strings

**Good Example:**
```ruby
# frozen_string_literal: true

class Generator
  def self.build_navigation
    "# #{SiteSetting.title}\n> #{SiteSetting.site_description}"
  end
end
```

**Bad Example:**
```ruby
class Generator
	def self.build_navigation # Tab indentation (bad)
		title = SiteSetting.title # Single line is fine, but...
		description = SiteSetting.site_description # ...this could be one expression
		"# " + title + "\n> " + description # String concatenation (bad, use interpolation)
	end
end
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `LlmsController` |
| Modules | PascalCase | `DiscourseLlmsTxt` |
| Methods | snake_case | `build_navigation` |
| Variables | snake_case | `cache_minutes` |
| Constants | SCREAMING_SNAKE_CASE | `CACHE_KEY` |
| Files | snake_case | `llms_controller.rb` |

### Comments

**Minimal comments** - code should be self-documenting.

Only add comments for:
- Complex logic that's not immediately obvious
- Non-obvious design decisions
- Workarounds for bugs

**Good comment (explains WHY):**
```ruby
# Constraint allows matching full category path including subcategories like /c/parent/child/123/llms.txt
get "/c/:category_slug_path_with_id/llms.txt" => "discourse_llms_txt/llms#category",
    constraints: { category_slug_path_with_id: /.*/ }
```

**Bad comment (explains WHAT - code is self-explanatory):**
```ruby
# This method clears the cache
def clear_cache
  Discourse.cache.delete(CACHE_KEY)
end
```

### Method Organization

```ruby
class Example
  # Class methods first
  def self.class_method
  end

  # Instance methods
  def instance_method
  end

  # Private methods last
  private

  def private_helper
  end
end
```

### Design Patterns

**When creating new generator methods:**

```ruby
# Template
def self.build_RESOURCE_llms(resource)
  output = StringIO.new

  # 1. Header with metadata
  output.puts "# #{resource.title}"
  output.puts

  # 2. Body content
  output.puts resource.description
  output.puts

  # 3. Canonical URLs (IMPORTANT)
  canonical_url = resource_url(resource)
  output.puts "**Canonical:** #{canonical_url}"
  output.puts "**Original content:** #{canonical_url}"

  output.string
end
```

**Rules:**
- Use StringIO for efficient string building
- Always include canonical URLs
- Use `puts` (adds newlines automatically)
- Return `output.string` at the end

---

## 🧪 Testing Guidelines

### Running Tests

**Run full test suite:**
```bash
bundle exec rspec plugins/discourse-llms-txt-generator/spec
```

**Run specific test file:**
```bash
bundle exec rspec plugins/discourse-llms-txt-generator/spec/requests/discourse_llms_txt/llms_controller_spec.rb
```

**Run specific test by line:**
```bash
bundle exec rspec plugins/discourse-llms-txt-generator/spec/requests/discourse_llms_txt/llms_controller_spec.rb:53
```

**Run with documentation format:**
```bash
bundle exec rspec plugins/discourse-llms-txt-generator/spec --format documentation
```

### Test Structure

All tests in: `spec/requests/discourse_llms_txt/llms_controller_spec.rb`

```ruby
describe DiscourseLlmsTxt::LlmsController do
  fab!(:category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, views: 100, category: category) }
  fab!(:tag) { Fabricate(:tag) }

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
    end

    it "returns 404 when plugin disabled" do
      SiteSetting.llms_txt_enabled = false
      get "/llms.txt"
      expect(response.status).to eq(404)
    end
  end
end
```

### Test Coverage

**Current coverage (22 tests):**

- ✅ 7 tests for `#index` (main navigation)
- ✅ 6 tests for `#full` (full content)
- ✅ 2 tests for `#sitemaps` (sitemap index)
- ✅ 2 tests for `#category` (category files)
- ✅ 2 tests for `#topic` (topic files)
- ✅ 3 tests for `#tag` (tag files)

### Common Test Patterns

**Testing HTTP responses:**
```ruby
get "/llms.txt"
expect(response.status).to eq(200)
expect(response.content_type).to include("text/plain")
```

**Testing content inclusion:**
```ruby
expect(response.body).to include("Expected text")
expect(response.body).not_to include("Unexpected text")
```

**Testing settings enforcement:**
```ruby
SiteSetting.llms_txt_enabled = false
get "/llms.txt"
expect(response.status).to eq(404)
```

**Testing canonical URLs:**
```ruby
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
```

### How to Add New Tests

1. **Open test file:**
   ```bash
   spec/requests/discourse_llms_txt/llms_controller_spec.rb
   ```

2. **Add test to appropriate describe block:**
   ```ruby
   describe "#index" do
     it "includes latest topics section" do
       # Setup
       topic = Fabricate(:topic, views: 100)

       # Action
       get "/llms.txt"

       # Assertions
       expect(response.status).to eq(200)
       expect(response.body).to include("## Latest Topics")
       expect(response.body).to include(topic.title)
     end
   end
   ```

3. **Run your test:**
   ```bash
   bundle exec rspec spec/requests/discourse_llms_txt/llms_controller_spec.rb:LINE_NUMBER
   ```

4. **Verify all tests pass:**
   ```bash
   bundle exec rspec plugins/discourse-llms-txt-generator/spec
   ```

### Manual Testing

**Test generated files:**
```bash
# Start dev server
bundle exec rails s

# Test endpoints
curl http://localhost:3000/llms.txt
curl http://localhost:3000/llms-full.txt
curl http://localhost:3000/sitemaps.txt
curl http://localhost:3000/c/general/1/llms.txt
curl http://localhost:3000/t/welcome/1/llms.txt
curl http://localhost:3000/tag/announcement/llms.txt
```

**Test settings:**
1. Navigate to `http://localhost:3000/admin/site_settings/category/plugins`
2. Find "discourse-llms-txt-generator"
3. Test each setting:
   - Disable plugin → verify 404
   - Disable indexing → verify 403
   - Change min_views → verify filtering
   - Block user agents → verify robots.txt

**Test cache:**
```ruby
# Rails console
rails c

# Clear cache
DiscourseLlmsTxt::Generator.clear_cache

# Check cache
Discourse.cache.read("llms_txt_navigation")
# nil = cache empty
# String = cache hit

# Check last update
PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "last_cache_update")
```

**Test sitemap and robots.txt:**

See [Test Sitemap and Robots.txt Integration](#test-sitemap-and-robotstxt-integration) section below.

---

### Test Sitemap and Robots.txt Integration

**Important:** After installing or updating the plugin, regenerate sitemap and clear robots.txt cache.

#### Refresh Sitemap and Robots.txt

```bash
cd /var/www/discourse

# Option 1: Use plugin rake task (recommended)
bundle exec rake llms_txt:refresh

# Option 2: Manual refresh
bundle exec rake sitemap:refresh
rails runner "Rails.cache.delete('robots_txt')"

# Option 3: Restart Discourse (clears all caches)
cd /var/discourse
./launcher restart app
```

#### Verify robots.txt

```bash
# Check if llms.txt entries present
curl http://localhost:3000/robots.txt | grep -A 10 "LLM Documentation"
```

**Expected output when `llms_txt_allow_indexing = true`:**
```
# LLM Documentation Files
Allow: /llms.txt
Allow: /llms-full.txt
Allow: /sitemaps.txt
Allow: /c/*/llms.txt
Allow: /t/*/llms.txt
Allow: /tag/*/llms.txt

Sitemap: http://localhost:3000/sitemaps.txt
```

**Expected output when `llms_txt_allow_indexing = false`:**
```
# LLM Documentation Files
Disallow: /llms.txt
Disallow: /llms-full.txt
Disallow: /sitemaps.txt
Disallow: /c/*/llms.txt
Disallow: /t/*/llms.txt
Disallow: /tag/*/llms.txt
```

#### Verify sitemap.xml

```bash
# Check main sitemap
curl http://localhost:3000/sitemap.xml

# Search for llms.txt entries
curl http://localhost:3000/sitemap.xml | grep llms
```

**Expected:** Should include `<url>` entries for `/llms.txt`, `/llms-full.txt`, and `/sitemaps.txt`

#### Check Plugin Status

```bash
# Quick configuration check
bundle exec rake llms_txt:check
```

**Output:**
- Plugin enabled status
- Indexing allowed status
- Test endpoint URLs

#### Troubleshooting Sitemap/Robots Issues

**Problem:** llms.txt files don't appear in sitemap.xml

**Solutions:**
1. **Clear sitemap cache:**
   ```bash
   rails runner "SitemapUrl.delete_all"
   bundle exec rake sitemap:refresh
   ```

2. **Check settings:**
   ```ruby
   rails c
   > SiteSetting.llms_txt_enabled
   > SiteSetting.llms_txt_allow_indexing
   ```

3. **Force regeneration:**
   ```bash
   bundle exec rake sitemap:regenerate
   ```

**Problem:** robots.txt doesn't show llms.txt rules

**Solutions:**
1. **Clear robots.txt cache:**
   ```bash
   rails runner "Rails.cache.delete('robots_txt')"
   ```

2. **Check view connector exists:**
   ```bash
   ls -la plugins/discourse-llms-txt-generator/app/views/connectors/robots_txt_index/
   # Should show: llms_txt.html.erb
   ```

3. **Check logs:**
   ```bash
   tail -f log/development.log | grep -i robot
   ```

**Problem:** Changes don't appear after updating settings

**Solution:** Always refresh after changing settings:
```bash
bundle exec rake llms_txt:refresh
```

---

## 🎯 Future Enhancement Ideas

### Enhancement 1: Admin UI Dashboard

**Current Limitation:**
No visual preview of generated llms.txt files. Admins must curl endpoints to see results.

**Proposed Enhancement:**
Add admin dashboard with live preview and statistics.

**Use Case:**
Admin wants to see how llms.txt looks before enabling for crawlers. Admin wants analytics on which bots are accessing files.

**Implementation Plan:**

**1. Create admin controller:**
```ruby
# app/controllers/discourse_llms_txt/admin_controller.rb
class DiscourseLlmsTxt::AdminController < Admin::AdminController
  def index
    # Dashboard view
  end

  def preview
    # Live preview of llms.txt
    @navigation = DiscourseLlmsTxt::Generator.build_navigation
    @full = DiscourseLlmsTxt::Generator.build_full_content
  end

  def analytics
    # Access statistics
    @stats = {
      index_count: PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "access_count_index"),
      full_count: PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "access_count_full"),
      last_access: PluginStore.get(DiscourseLlmsTxt::PLUGIN_NAME, "last_access_index")
    }
    render json: @stats
  end
end
```

**2. Add routes:**
```ruby
# plugin.rb
Discourse::Application.routes.append do
  namespace :admin, constraints: StaffConstraint.new do
    namespace :plugins do
      namespace :discourse_llms_txt do
        get "/" => "admin#index"
        get "/preview" => "admin#preview"
        get "/analytics" => "admin#analytics"
      end
    end
  end
end
```

**Files to Modify:**
- `plugin.rb` - Add admin routes
- `app/controllers/discourse_llms_txt/admin_controller.rb` - New controller
- `assets/javascripts/discourse/templates/admin/plugins-discourse-llms-txt.hbs` - Dashboard UI

**Estimated Effort:** 8-12 hours

**Priority:** Medium

---

### Enhancement 2: Custom Topic Filtering by Tags

**Current Limitation:**
Can only filter by minimum views. No tag-based filtering for llms-full.txt.

**Proposed Enhancement:**
Allow admins to include/exclude topics by tags in llms-full.txt.

**Use Case:**
Forum has "announcement" and "discussion" tags. Admin wants llms-full.txt to only include "announcement" topics.

**Implementation Plan:**

**1. Add settings:**
```yaml
# config/settings.yml
llms_txt_included_tags:
  type: list
  list_type: tag
  default: ""
  description: "Only include topics with these tags (empty = all tags)"

llms_txt_excluded_tags:
  type: list
  list_type: tag
  default: ""
  description: "Exclude topics with these tags"
```

**2. Update query:**
```ruby
# lib/discourse_llms_txt/generator.rb
def self.topics_for_full_content
  query = latest_topics.where("views >= ?", min_views)

  # Include tags filter
  if SiteSetting.llms_txt_included_tags.present?
    included_tags = SiteSetting.llms_txt_included_tags.split('|')
    query = query.joins(:tags).where("tags.name IN (?)", included_tags).distinct
  end

  # Exclude tags filter
  if SiteSetting.llms_txt_excluded_tags.present?
    excluded_tags = SiteSetting.llms_txt_excluded_tags.split('|')
    query = query.where.not(id: Topic.joins(:tags).where("tags.name IN (?)", excluded_tags).select(:id))
  end

  query
end
```

**Files to Modify:**
- `config/settings.yml` - Add tag filter settings
- `config/locales/server.en.yml` - Add setting descriptions
- `lib/discourse_llms_txt/generator.rb` - Update query logic
- `spec/requests/discourse_llms_txt/llms_controller_spec.rb` - Add tests

**Estimated Effort:** 4-6 hours

**Priority:** High

---

### Enhancement 3: Integration with discourse-solved Plugin

**Current Limitation:**
No indication of which topics have accepted solutions.

**Proposed Enhancement:**
Mark solved topics in llms.txt files, prioritize them in listings.

**Use Case:**
Support forum wants LLMs to prioritize solved topics with verified solutions.

**Implementation Plan:**

**1. Detect discourse-solved:**
```ruby
# lib/discourse_llms_txt/generator.rb
def self.solved_enabled?
  defined?(DiscourseSolved) && SiteSetting.solved_enabled
end
```

**2. Query solved topics:**
```ruby
def self.latest_topics
  query = Topic.joins(:category)
    .where("categories.read_restricted = ?", false)
    .where(visible: true, archived: false)

  # Prioritize solved topics if plugin enabled
  if solved_enabled?
    query = query.order("has_accepted_answer DESC NULLS LAST, created_at DESC")
  else
    query = query.order(created_at: :desc)
  end

  query
end
```

**3. Mark solved in output:**
```ruby
def self.build_full_content
  topics.each do |topic|
    solved_marker = topic.has_accepted_answer? ? " ✅ [Solved]" : ""
    output.puts "**[#{topic.category.name}](url)** - [#{topic.title}](url)#{solved_marker}"
  end
end
```

**Files to Modify:**
- `lib/discourse_llms_txt/generator.rb` - Add solved detection and markers
- `spec/requests/discourse_llms_txt/llms_controller_spec.rb` - Add tests for solved integration

**Estimated Effort:** 3-4 hours

**Priority:** Medium

---

## 🚀 Submitting Pull Requests

### Before Submitting

**Checklist:**
- [ ] Code follows [Ruby Style Guide](https://rubystyle.guide/)
- [ ] All tests pass: `bundle exec rspec plugins/discourse-llms-txt-generator/spec`
- [ ] New features have tests
- [ ] README.md updated (if user-facing changes)
- [ ] CHANGELOG.md updated (add entry under "Unreleased")
- [ ] No rubocop violations

### PR Template

```markdown
## Description
[Brief description of what changed and why]

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing Done
[Describe how you tested this]

**Manual testing:**
- [ ] Tested on development server
- [ ] Checked /llms.txt endpoint
- [ ] Verified settings work correctly

**Automated testing:**
- [ ] All existing tests pass
- [ ] Added new tests for new functionality

## Related Issues
Fixes #issue_number

## Screenshots (if applicable)
[Add screenshots for UI changes]

## Breaking Changes
[List any breaking changes and migration path]
```

### Commit Message Format

```
Short summary (50 chars or less)

Detailed explanation if needed. Wrap at 72 characters.

- Bullet points are okay
- Use imperative mood ("Add feature" not "Added feature")
- Reference issues: "Fixes #123"
```

**Good examples:**
```
Add canonical URLs to prevent duplicate content penalties

Fix URL encoding for Cyrillic characters in slugs

Implement view connector for robots.txt integration
```

**Bad examples:**
```
Fixed stuff (too vague)
Added canonical URLs and also fixed a bug and updated docs (too much in one commit)
feature (not descriptive)
```

---

## 💡 Development Tips

### Debugging

**Enable debug logging:**
```ruby
# lib/discourse_llms_txt/generator.rb
def self.build_navigation
  Rails.logger.info "[llms.txt] Building navigation, cache_minutes: #{cache_minutes}"
  content = generate_navigation_content
  Rails.logger.info "[llms.txt] Generated #{content.length} bytes"
  content
end
```

**View logs:**
```bash
# Development
tail -f log/development.log | grep llms

# Production
tail -f /var/www/discourse/logs/production.log | grep llms
```

**Rails console debugging:**
```ruby
rails c

# Test generator
content = DiscourseLlmsTxt::Generator.build_navigation
puts content

# Check cache
Discourse.cache.read("llms_txt_navigation")

# Check settings
SiteSetting.llms_txt_enabled
SiteSetting.llms_txt_allow_indexing

# Check database
Category.where(read_restricted: false).count
Topic.where(visible: true).count
```

### Common Pitfalls

#### 1. N+1 Queries

**❌ Bad:**
```ruby
topics.each do |topic|
  category_name = topic.category.name  # N+1 query!
end
```

**✅ Good:**
```ruby
topics.includes(:category).each do |topic|
  category_name = topic.category.name  # Single query
end
```

**Why:** Without `includes`, Rails runs a separate SQL query for each topic's category. With `includes`, Rails loads all categories in one query.

---

#### 2. Missing URL Encoding

**❌ Bad:**
```ruby
"#{Discourse.base_url}/tag/#{tag_name}"  # Breaks for "тег-3"
```

**✅ Good:**
```ruby
"#{Discourse.base_url}/tag/#{CGI.escape(tag_name)}"  # Works for all characters
```

**Why:** International characters must be percent-encoded for URLs to work correctly.

---

#### 3. String Concatenation Instead of StringIO

**❌ Bad:**
```ruby
output = ""
topics.each do |topic|
  output += "- #{topic.title}\n"  # Creates new string each iteration
end
```

**✅ Good:**
```ruby
output = StringIO.new
topics.each do |topic|
  output.puts "- #{topic.title}"  # Appends to buffer
end
output.string
```

**Why:** String concatenation creates a new string object each time (O(n²) complexity). StringIO is much faster for building large strings.

---

#### 4. Forgetting Canonical URLs

**❌ Bad:**
```ruby
def build_topic_llms(topic)
  output = StringIO.new
  output.puts "# #{topic.title}"
  output.string  # Missing canonical URLs!
end
```

**✅ Good:**
```ruby
def build_topic_llms(topic)
  output = StringIO.new
  output.puts "# #{topic.title}"

  topic_url_str = topic_url(topic)
  output.puts "**Canonical:** #{topic_url_str}"
  output.puts "**Original content:** #{topic_url_str}"

  output.string
end
```

**Why:** Canonical URLs prevent duplicate content SEO penalties and provide proper attribution.

---

### Testing in Development

**Quick development cycle:**

```bash
# 1. Make code changes
vim lib/discourse_llms_txt/generator.rb

# 2. Clear cache
rails runner "DiscourseLlmsTxt::Generator.clear_cache"

# 3. Test endpoint
curl http://localhost:3000/llms.txt

# 4. Run tests
bundle exec rspec plugins/discourse-llms-txt-generator/spec

# 5. Check logs
tail -f log/development.log | grep llms
```

**Hot reloading:**
```bash
# Development server auto-reloads most changes
bundle exec rails s

# For some changes, need manual reload:
rails runner "Rails.application.reloader.reload!"
```

---

## 📚 Additional Resources

### Discourse Plugin Development

- [Discourse Plugin Development Guide](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins/30515)
- [Discourse API Documentation](https://docs.discourse.org/)
- [Discourse Source Code](https://github.com/discourse/discourse)

### Ruby and Rails

- [Ruby Style Guide](https://rubystyle.guide/)
- [Rails Guides](https://guides.rubyonrails.org/)
- [ActiveRecord Query Interface](https://guides.rubyonrails.org/active_record_querying.html)

### Standards and RFCs

- [llms.txt Standard](https://llmstxt.org/)
- [RFC 3986 - URL Encoding](https://tools.ietf.org/html/rfc3986)
- [RFC 6596 - Canonical Link Header](https://tools.ietf.org/html/rfc6596)

### Testing

- [RSpec Documentation](https://rspec.info/documentation/)
- [Discourse Testing Guide](https://meta.discourse.org/t/discourse-plugin-testing/30534)

---

## Questions?

- **Issues**: [GitHub Issues](https://github.com/kaktaknet/discourse-llms-txt-generator/issues)
- **Discourse Meta**: [Plugin Topic](https://meta.discourse.org/t/discourse-llms-txt-generator)
- **Email**: support@kaktak.net

---

Thank you for contributing! 🎉
