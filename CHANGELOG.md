# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New setting `llms_txt_include_excerpts` to optionally include post excerpts (up to 500 characters) in llms-full.txt topic list
- Setting `llms_txt_post_excerpt_length` re-enabled for controlling excerpt length (was removed in v1.1.0, now restored)
- Warning documentation about combining excerpts with "all" posts limit

### Fixed
- **SECURITY**: Private category topics no longer appear in public llms.txt files
  - Added `.joins(:category).where(categories: { read_restricted: false })` filter to all topic queries
  - Affects: `/llms.txt`, `/llms-full.txt`, `/sitemaps.txt`, `/tag/{name}/llms.txt`
  - Dynamic files (`/c/{id}/llms.txt`, `/t/{id}/llms.txt`) already protected via Guardian
  - Topics from restricted categories now properly filtered from public content

### Removed
- `llms_txt_max_categories` setting (never used in code)
- `llms_txt_max_posts_per_topic` setting (no longer needed after v1.1.0 simplification)

## [1.2.0] - 2025-11-09

### Added
- **Dynamic llms.txt files** for any resource (categories, topics, tags)
  - `/c/:category_slug/:id/llms.txt` - Category-specific llms.txt with subcategories and topics
  - `/t/:topic_slug/:id/llms.txt` - Full topic content with all posts in markdown
  - `/tag/:tag_name/llms.txt` - All topics with specific tag
  - Virtual file generation (no physical files created, generated on-demand)
  - Respects Discourse permission system via Guardian
- **sitemaps.txt file** - Complete index of all llms.txt URLs
  - Lists main files, all public categories, topics (limited), and tags
  - Automatically referenced in robots.txt Sitemap directive
  - Cached for performance
  - Helps LLM crawlers discover all available llms.txt resources

### Changed
- **Code simplification**: Removed verbose bilingual comments, kept minimal English comments for complex logic only
- Dynamic routes now support full category paths including subcategories

### Performance
- On-demand generation for dynamic files (no pre-generation overhead)
- Smart caching applied to sitemaps.txt
- Limited topic URLs in sitemaps.txt to prevent massive file sizes
- Memory efficient with `.find_each` for large datasets

### Technical Details
- New generator methods: `generate_sitemaps`, `generate_category_llms`, `generate_topic_llms`, `generate_tag_llms`
- New controller actions: `sitemaps`, `category`, `topic`, `tag`
- Enhanced robots.txt integration with wildcard patterns for dynamic URLs
- Topic llms.txt uses `post.raw` (markdown) instead of `post.cooked` (HTML) for LLM processing

## [1.1.0] - 2025-11-09

### Added
- **Custom forum description** for llms-full.txt (`llms_txt_full_description` setting)
  - Appears at the top of llms-full.txt
  - Optional field with guidance against marketing content
  - Helps LLMs better understand your forum's purpose
- **User-Agent blocking** for specific bots (`llms_txt_blocked_user_agents` setting)
  - Comma-separated list of bots to block from llms.txt files
  - Automatically generates robots.txt rules
  - Blocked bots can still access the main forum
- **Smart cache management** with scheduled job
  - Hourly checks for new content (topics/categories)
  - Only updates cache when necessary
  - Tracks last update timestamp
  - Reduces unnecessary regeneration
- **Latest topics display** in llms.txt
  - Shows up to 50 most recent topics (configurable)
  - Replaces "popular topics" for better LLM relevance

### Changed
- **Complete restructure of llms.txt**:
  - Now shows categories with subcategories hierarchically
  - Displays latest topics instead of popular topics
  - Better organized for LLM parsing
- **Simplified llms-full.txt format**:
  - Custom description displayed first (if provided)
  - Categories and subcategories with detailed descriptions
  - Topics in compact format: `**Category** - [Title](link)`
  - Removed post excerpts for better performance
  - Focuses on topic discovery rather than content
- **Generator rewrite**:
  - `generate_categories_with_subcategories`: Hierarchical category display
  - `generate_latest_topics`: Shows recent topics
  - `generate_topics_list`: Simplified format for full.txt
  - `should_update_cache?`: Smart cache invalidation
- **Enhanced robots.txt integration**:
  - Generates User-Agent specific rules
  - Maintains backwards compatibility

### Removed
- `llms_txt_popular_topics_count` setting (replaced by `llms_txt_latest_topics_count`)
- Post excerpts from llms-full.txt (simplified to topic links only, but re-added as optional in later version)

### Performance
- Reduced generation time for llms-full.txt (no post processing)
- Smart hourly cache checks instead of per-post regeneration
- Better database query optimization with `.includes(:category)`
- Less memory usage with simplified format

### Migration Notes
For users upgrading from 1.0.0:
- Old settings will be safely ignored
- Set `llms_txt_latest_topics_count` (default: 50, recommended)
- Optionally configure `llms_txt_full_description`
- Optionally configure `llms_txt_blocked_user_agents`
- llms.txt and llms-full.txt formats have changed (LLMs will adapt automatically)

## [1.0.0] - 2025-11-08

### Added
- Initial release of discourse-llms-txt-generator plugin
- Automatic generation of `/llms.txt` navigation file
- Automatic generation of `/llms-full.txt` full content file
- Configurable site settings for content filtering
- Integration with Discourse robots.txt
- Integration with Discourse sitemap.xml
- Smart caching system for navigation file
- Access tracking and analytics
- Support for public categories and topics
- Respect for Discourse permission system
- Comprehensive test suite
- Full documentation in README.md

### Configuration Options
- Enable/disable plugin
- Control AI crawler indexing
- Customize introduction text
- Set minimum topic views threshold
- Configure posts limit (small/medium/large/all)
- Adjust cache duration
- Control category display count
- Set popular topics count
- Limit posts per topic
- Configure post excerpt length

### Security
- CSRF protection properly handled
- Public endpoint security
- Privacy-aware content filtering
- No authentication required (public files)

### Performance
- Intelligent caching for navigation file
- Configurable limits to prevent overload
- Efficient database queries
- On-demand generation for full content

[1.2.0]: https://github.com/kaktaknet/discourse-llms-txt-generator/releases/tag/v1.2.0
[1.1.0]: https://github.com/kaktaknet/discourse-llms-txt-generator/releases/tag/v1.1.0
[1.0.0]: https://github.com/kaktaknet/discourse-llms-txt-generator/releases/tag/v1.0.0
