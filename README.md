# SQL Cockpit Documentation

Documentation for SQL Cockpit - PowerShell-based SQL tooling suite.

## Quick Start

### Viewing the Documentation

The latest documentation is available at [https://sql-cockpit.github.io/sql-cockpit/](https://sql-cockpit.github.io/sql-cockpit/).

### Building Locally

```bash
# Install dependencies
pip install -r requirements-docs.txt

# Serve documentation locally
mkdocs serve
```

Open your browser to `http://127.0.0.1:8000` to view the documentation.

## Documentation Versioning

This project uses [mike](https://github.com/jimporter/mike) for documentation versioning. Multiple versions of the documentation are hosted on the `gh-pages` branch.

### Available Versions

- **latest** - The most recent development version
- **1.0** - The current stable release

To switch between versions, use the version selector in the navigation bar when viewing the documentation site.

### Deploying a New Version

To deploy a new version of the documentation:

```bash
# Configure git user (if not already configured)
git config user.email "your-email@example.com"
git config user.name "Your Name"

# Deploy a new version (e.g., 1.1)
mike deploy 1.1

# Update the 'latest' alias to point to the new version
mike deploy --update-aliases 1.1 latest

# Push changes to gh-pages branch
mike deploy --push 1.1 latest
```

### Serving Specific Versions Locally

```bash
# Serve a specific version
mike serve 1.0

# Serve the latest version
mike serve latest
```

### Managing Versions

```bash
# List all deployed versions
mike list

# Set default version
mike set-default 1.1

# Delete a version
mike delete 1.0
```

For more detailed information, see [VERSIONING.md](docs/VERSIONING.md).

## Contributing

We welcome contributions! Please read our [Contributing Guide](docs/CONTRIBUTING.md) for guidelines on:

- Documentation standards
- Configuration documentation format
- Working with generated pages
- Mermaid diagrams
- Code references in documentation

## Project Structure

```
sql-cockpit/
├── docs/                 # Documentation source files
├── blog/                 # Blog posts
├── includes/             # Reusable content snippets
├── scripts/              # Documentation generation scripts
├── stylesheets/          # Custom CSS
├── javascripts/          # Custom JavaScript
├── mkdocs.yml            # MkDocs configuration
├── requirements-docs.txt # Python dependencies
└── SETUP_GUIDE.md        # Setup instructions
```

## License

Copyright &copy; 2026 - SQL Cockpit Team
