# Discourse llms.txt Generator

| | | |
| - | - | - |
| :information_source: | **Summary** | Automatically generates llms.txt files that make your forum content discoverable by Large Language Models like ChatGPT, Claude, and other AI systems |
| :hammer_and_wrench: | **Repository Link** | https://github.com/kaktaknet/discourse-llms-txt-generator |
| :open_book: | **Install Guide** | [How to install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157) |

<br>

### Features

This plugin implements the [llms.txt standard](https://llmstxt.org/) - a proposed convention for providing LLM-friendly content from websites. Think of it as "robots.txt for AI" that helps your forum content appear in AI-generated responses.

**For detailed feature documentation**, see [README.md](https://github.com/kaktaknet/discourse-llms-txt-generator/blob/main/README.md)

**For technical documentation and development**, see [CONTRIBUTING.md](https://github.com/kaktaknet/discourse-llms-txt-generator/blob/main/CONTRIBUTING.md)

**Key capabilities:**

1. **Main Navigation File** (`/llms.txt`)
   - Structured overview of your forum with categories, subcategories, and latest topics
   - Helps AI systems understand your forum organization instantly
   - Automatically updates as your forum grows

2. **Full Content Index** (`/llms-full.txt`)
   - Complete forum index with all topics categorized and ready for AI consumption
   - Configurable filtering by views and topic count
   - Optional post excerpts for faster AI indexing

3. **Dynamic Per-Resource Files**
   - Generate llms.txt for any category: `/c/category-name/123/llms.txt`
   - Generate llms.txt for any topic: `/t/topic-slug/456/llms.txt`
   - Generate llms.txt for any tag: `/tag/tutorial/llms.txt`
   - Created on-demand without physical storage

4. **Sitemap Index** (`/sitemaps.txt`)
   - Complete list of all llms.txt URLs for efficient AI crawler discovery
   - Automatically integrates with robots.txt and sitemap.xml

5. **SEO Protection**
   - Canonical URLs in HTTP headers (RFC 6596 compliant)
   - Prevents duplicate content penalties from search engines
   - Proper attribution to original forum URLs

6. **Smart Caching**
   - Hourly background checks for new content
   - Only regenerates when necessary
   - Fast response times (under 50ms)

7. **Bot Control**
   - Block specific AI crawlers while allowing forum access
   - Comma-separated list of user agents to block
   - Automatic robots.txt integration via view connector

8. **Privacy & Security**
   - Private categories automatically excluded
   - Guardian permission checks for dynamic files
   - SQL-level security filtering
   - No personal data exposed

**Benefits for your forum:**

- **Increased Visibility**: Your content appears in ChatGPT, Claude, and other AI responses
- **Direct Attribution**: AI systems cite and link back to your forum
- **More Traffic**: Increased discovery through AI-powered search
- **Better GEO**: Generative Engine Optimization for AI systems
- **No Maintenance**: Automatic generation and updates

### Configuration

After installing the plugin, navigate to **Admin → Settings → Plugins → discourse-llms-txt-generator**

**Step 1: Enable the plugin**

Set `llms_txt_enabled` to `true` (enabled by default)

**Step 2: Configure indexing**

Set `llms_txt_allow_indexing` to `true` to allow AI crawlers access (enabled by default)

This setting controls whether llms.txt files appear in your robots.txt as allowed or disallowed.

**Step 3: Set content filters**

Configure these settings based on your forum size:

- `llms_txt_min_views`: Minimum topic views to include (default: 50)
- `llms_txt_posts_limit`: How many topics to include
  - `small`: 500 topics (recommended for large forums)
  - `medium`: 2,500 topics (recommended for most forums)
  - `large`: 5,000 topics
  - `all`: All topics (use cautiously on large forums)

**Step 4: Optional - Add custom description**

Fill in `llms_txt_full_description` with 2-4 sentences describing your forum's purpose and community. This helps AI systems provide more accurate information about your forum.

Example:
```
This forum is dedicated to discussing Python programming, with focus on web development,
data science, and machine learning. Our community includes beginners and experienced
developers sharing practical solutions and best practices.
```

**Step 5: Optional - Block specific bots**

If you want to block certain AI crawlers, enter their user agent names in `llms_txt_blocked_user_agents` as a comma-separated list:

Example: `Omgilibot, ChatGPT-User, CCBot`

**Step 6: Verify installation**

Visit your forum at:
- `/llms.txt` - Main navigation file
- `/llms-full.txt` - Full content index
- `/sitemaps.txt` - Complete sitemap

Check your `/robots.txt` to verify the integration.

### Settings

| Name | Default | Description |
|-|-|-|
| `llms_txt_enabled` | `true` | Enable or disable the plugin |
| `llms_txt_allow_indexing` | `true` | Allow AI crawlers to access llms.txt files (affects robots.txt) |
| `llms_txt_blocked_user_agents` | `""` | Comma-separated list of bot user agents to block from llms.txt files |
| `llms_txt_intro_text` | Custom text | Introduction text that appears in the main llms.txt file |
| `llms_txt_full_description` | `""` | Custom description for llms-full.txt to help AI understand your forum context |
| `llms_txt_min_views` | `50` | Minimum topic views required for inclusion in llms-full.txt |
| `llms_txt_posts_limit` | `medium` | Topic count limit: `small` (500), `medium` (2,500), `large` (5,000), or `all` |
| `llms_txt_include_excerpts` | `false` | Include post excerpts in llms-full.txt (increases file size significantly) |
| `llms_txt_post_excerpt_length` | `500` | Maximum excerpt length in characters (100-5000) if excerpts are enabled |
| `llms_txt_latest_topics_count` | `50` | Number of latest topics to show in main llms.txt file |
| `llms_txt_cache_minutes` | `60` | Cache duration in minutes for the navigation file |

**Important notes:**

- Enabling `llms_txt_include_excerpts` with `llms_txt_posts_limit` set to `all` may cause extremely large file sizes (potentially 10-100+ MB) and high server load on large forums
- Private categories are automatically excluded from all llms.txt files
- Dynamic per-resource files (categories, topics, tags) are not cached and generated on-demand
- The plugin uses view connectors for robots.txt integration - no need to manually edit robots.txt

### Technical Details

**Architecture:**
- On-demand generation without pre-generated files
- Smart caching with hourly background checks
- Permission-aware using Discourse Guardian
- SQL-level security filtering for private content
- Canonical URLs in HTTP headers to prevent SEO penalties

**Performance:**
- Navigation file cached for 60 minutes (configurable)
- Full content file generated on-demand
- Smart cache only regenerates when new content exists
- Response time under 50ms for cached content

**Compatibility:**
- Discourse 2.7.0+
- Ruby 2.7+
- Tested on Discourse 3.6.0.beta3

**Standards compliance:**
- llms.txt standard (https://llmstxt.org/)
- RFC 3986 (URL encoding for international characters)
- RFC 6596 (Canonical Link headers)

### Use Cases

**Community Forums:**
Your discussions and solutions appear when users ask AI assistants relevant questions, driving qualified traffic back to your forum.

**Documentation Sites:**
AI systems can reference your documentation and tutorials, providing accurate information with proper attribution.

**Support Forums:**
Users get direct answers from your knowledge base through AI assistants, with links back to full discussions.

**Technical Communities:**
Developers discover your forum content through AI-powered coding assistants, increasing community engagement.

### Maintenance

The plugin requires minimal maintenance:

- Cache automatically refreshes every hour
- Content updates happen automatically on post creation/editing
- No manual file generation needed
- Optional rake tasks available: `llms_txt:refresh` and `llms_txt:check`

### Troubleshooting

**Files not accessible:**
- Verify `llms_txt_enabled` is `true`
- Check that `llms_txt_allow_indexing` is `true`
- Confirm plugin is installed in Admin → Plugins

**Empty content:**
- Ensure you have public topics with sufficient views (check `llms_txt_min_views` setting)
- Verify categories are public (not read-restricted)
- Check `llms_txt_posts_limit` setting

**robots.txt integration not working:**
- Clear robots.txt cache: `Rails.cache.delete('robots_txt')`
- Use rake task: `bundle exec rake llms_txt:refresh`
- Restart Discourse: `./launcher restart app`

### Support

- GitHub Issues: https://github.com/kaktaknet/discourse-llms-txt-generator/issues
- Email: support@kaktak.net

### License

MIT License - Free and open-source software

### Credits

- Standard: [llms.txt by Jeremy Howard (Answer.AI)](https://llmstxt.org/)
- GitHub: https://github.com/AnswerDotAI/llms-txt
- Platform: [Discourse](https://www.discourse.org/)
