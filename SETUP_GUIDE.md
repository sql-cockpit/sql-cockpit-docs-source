# SQL Cockpit Documentation Setup Guide

This guide explains the enhanced features configured for the SQL Cockpit documentation site.

## Features Overview

### 1. Color Customization
- **Primary Color**: Blue (#1976d2) - Professional and trustworthy
- **Accent Color**: Indigo (#3949ab) - Complementary highlight color
- **Dark Mode**: Fully supported with automatic system preference detection
- **Color Palette Toggle**: Users can switch between light, dark, and system modes

### 2. Typography & Fonts
- **Text Font**: System font stack (San Francisco, Segoe UI, Roboto)
- **Code Font**: Monospace stack (SF Mono, Consolas, Liberation Mono)
- **Custom fonts** can be enabled via Google Fonts in `mkdocs.yml`

### 3. Language Support
- **Default Language**: English (en)
- **Multi-language Ready**: Configuration prepared for additional languages
- **Search Language**: Configured for English with smart word separation

### 4. Logo & Icons
- **Custom Logo**: SVG logo in `assets/logo.svg`
- **Favicon**: Configure in `assets/favicon.png`
- **Material Icons**: Full Material Design icon library available
- **Social Icons**: GitHub, Docker, LinkedIn, Email in footer

### 5. Data Privacy
- **Cookie Consent**: Built-in consent management dialog
- **Analytics**: Optional with privacy-friendly alternatives (Matomo)
- **Generator Tag**: Disabled to reduce fingerprinting
- **No Third-Party Tracking**: Default configuration respects user privacy

### 6. Navigation
- **Tabbed Navigation**: Top-level sections as tabs
- **Sticky Tabs**: Navigation remains visible while scrolling
- **Section Indexes**: Automatic index pages for sections
- **Navigation Path**: Breadcrumb trail showing current location
- **Navigation Pruning**: Collapses inactive sections for clarity
- **Deep Linking**: URL tracking for direct links to sections

### 7. Site Search
- **Enhanced Search**: Smart word separation and highlighting
- **Search Suggestions**: Auto-complete for faster finding
- **Search Sharing**: Share search results via URL
- **Full-Text Indexing**: All content indexed for comprehensive search

### 8. Analytics (Optional)
```yaml
# Google Analytics 4
- analytics:
    provider: google
    property: G-XXXXXXXXXX

# Matomo (Privacy-Friendly)
- analytics:
    provider: matomo
    property: instance-id.matomo.cloud/1
```

### 9. Social Cards
- **Automatic Generation**: Social media preview images for all pages
- **Custom Styling**: Branded colors and fonts
- **Requirements**: Install Pillow (`pip install pillow`)

### 10. Blog
- **Blog Directory**: `/blog` with automatic post listing
- **Post Metadata**: Date, categories, tags, authors
- **Archive**: Automatic archive by date and categories
- **RSS Feed**: Automatic generation for subscribers

### 11. Tags
- **Tag System**: Organize content with tags
- **Tag Page**: Central tag listing at `/tags.md`
- **Tag Cloud**: Visual representation of popular tags

### 12. Versioning (with Mike)
```bash
# Install mike
pip install mike

# Deploy a new version
mike deploy --push 1.0 latest

# Set default version
mike set-default --push latest
```

### 13. Header Configuration
- **Auto-Hide**: Header hides on scroll down, shows on scroll up
- **Edit Button**: Direct link to edit page on GitHub
- **View Source**: Link to view source on GitHub
- **Search Bar**: Prominent search in header

### 14. Footer Configuration
- **Social Links**: GitHub, Docker, LinkedIn, Email
- **Copyright**: Custom copyright notice
- **Navigation**: Quick links to important sections
- **Made with Material**: Attribution to MkDocs Material

### 15. Git Repository Integration
- **Repository Link**: GitHub repository URL configured
- **Edit URI**: Direct editing links on each page
- **Issue Links**: Automatic linking to GitHub issues
- **Commit History**: View page history on GitHub

### 16. Comment System
Comments can be added via:
- **Giscus**: GitHub Discussions-based comments
- **Utterances**: GitHub Issues-based comments
- **Disqus**: Traditional comment system
- **Custom**: Any JavaScript-based comment system

Example Giscus integration in `extra_javascript`:
```javascript
<script src="https://giscus.app/client.js"
        data-repo="your-org/sql-cockpit"
        data-repo-id="..."
        data-category="Documentation"
        data-category-id="..."
        data-mapping="pathname"
        data-strict="0"
        data-reactions-enabled="1"
        data-emit-metadata="0"
        data-input-position="bottom"
        data-theme="preferred_color_scheme"
        data-lang="en"
        crossorigin="anonymous"
        async>
</script>
```

### 17. Build Optimization
- **HTML Minification**: Reduces file size
- **Static Templates**: 404 page served statically
- **Asset Optimization**: Automatic optimization of CSS and JS
- **Lazy Loading**: Images and content loaded on demand

### 18. Offline Usage (PWA)
Progressive Web App support can be enabled:
```yaml
extra:
  manifest: manifest.json
  pwa:
    installable: true
    sw_file: sw.js
```

## File Structure

```
/workspace
├── mkdocs.yml              # Main configuration
├── stylesheets/
│   └── extra.css           # Custom styles
├── javascripts/
│   └── mermaid-init.js     # Mermaid diagram initialization
├── includes/
│   └── mkdocs.md           # Auto-appended content
├── assets/
│   ├── logo.svg            # Site logo
│   └── favicon.png         # Favicon (create this)
├── blog/
│   ├── .index.md           # Blog index page
│   └── posts/              # Blog posts directory
├── tags.md                 # Tags listing page
└── docs/                   # Documentation content (if used)
```

## Installation Requirements

```bash
# Core requirements
pip install mkdocs mkdocs-material

# Additional plugins
pip install mkdocs-glightbox mkdocs-social-cards

# For blog and tags
# (Included in mkdocs-material >= 9.0)

# For social cards (image generation)
pip install pillow

# For versioning
pip install mike

# For Mermaid diagrams
# (Already configured in mkdocs.yml)
```

## Building the Site

```bash
# Local development server
mkdocs serve

# Build for production
mkdocs build

# Build with strict mode (fail on warnings)
mkdocs build --strict

# Deploy to GitHub Pages
mkdocs gh-deploy
```

## Maintenance Tips

1. **Regular Updates**: Keep dependencies updated for security and features
2. **Link Checking**: Use `mkdocs build --strict` to catch broken links
3. **Screenshot Updates**: Update screenshots when UI changes
4. **Version Management**: Use mike for major version documentation
5. **Backup**: Regular backups of documentation content

## Troubleshooting

### Common Issues

1. **Social cards not generating**: Install Pillow (`pip install pillow`)
2. **Blog not showing**: Ensure posts have proper date metadata
3. **Tags not working**: Create tags.md file and configure plugin
4. **Search not indexing**: Check language configuration
5. **Version selector missing**: Install and configure mike plugin

For more information, visit the [MkDocs Material Documentation](https://squidfunk.github.io/mkdocs-material/).
