# Documentation Versioning Guide

This project uses [mike](https://github.com/jimporter/mike) for documentation versioning, which integrates with MkDocs Material theme.

## What is Mike?

Mike is a tool that allows you to build and deploy multiple versions of your MkDocs documentation. Each version is built separately and deployed to the `gh-pages` branch, allowing users to switch between different versions of your documentation.

## Setup

### Prerequisites

Mike is already included in `requirements-docs.txt`. If you need to install it manually:

```bash
pip install mike
```

## Local Development

### Deploying a New Version

To deploy a new version locally:

```bash
# Deploy version 1.0 and mark it as latest
mike deploy 1.0 latest

# Deploy only a new version (without updating aliases)
mike deploy 2.0

# Deploy with a custom title
mike deploy 1.0 --title "Version 1.0 (Stable)"
```

### Previewing Versions Locally

```bash
# Serve all deployed versions locally
mike serve

# Serve a specific version
mike serve --dev-addr localhost:8000 1.0
```

### Managing Versions

```bash
# List all deployed versions
mike list

# Set a different version as latest
mike set-default latest

# Delete a version
mike delete 1.0

# Rebuild an existing version
mike deploy 1.0 --rebuild
```

### Pushing to Remote

```bash
# Deploy and push to gh-pages branch in one command
mike deploy --push 1.0 latest

# Push existing local versions to remote
mike push
```

## CI/CD Integration

The GitHub Actions workflow (`.github/workflows/deploy-docs.yml`) is configured to automatically deploy documentation versions on push to main/master branches.

### Workflow Configuration

The current workflow:
1. Installs dependencies including mike
2. Configures git user for commits
3. Deploys version `1.0` and marks it as `latest`
4. Pushes to the `gh-pages` branch

### Customizing Versions in CI

To deploy different versions via CI, you can:

1. **Use environment variables:**
   ```yaml
   env:
     MIKE_VERSION: ${{ github.ref_name }}  # Uses branch name as version
   ```

2. **Deploy based on tags:**
   ```yaml
   on:
     push:
       tags:
         - 'v*'
   
   steps:
     - name: Deploy version from tag
       run: mike deploy --push ${GITHUB_REF#refs/tags/v} latest
   ```

## Version Selector

The version selector dropdown appears automatically in the navigation bar when multiple versions are deployed. Users can switch between versions using this selector.

The version selector is configured in `mkdocs.yml`:

```yaml
extra:
  version:
    provider: mike
```

## Best Practices

### Version Naming

- Use semantic versioning: `1.0`, `1.1`, `2.0`, etc.
- Use meaningful aliases: `latest`, `stable`, `dev`
- Consider using branch names for development versions

### When to Create New Versions

Create new versions when:
- Releasing a major/minor version of your software
- Making breaking changes to documented features
- Wanting to preserve historical documentation

### Keeping Versions Updated

- Update the `latest` alias when releasing new versions
- Consider deprecating old versions by removing them
- Document which versions are still supported

## Troubleshooting

### Common Issues

**Issue: Version selector not appearing**
- Ensure `extra.version.provider` is set to `mike` in `mkdocs.yml`
- Verify at least two versions are deployed

**Issue: Changes not reflecting**
- Clear browser cache
- Rebuild the version: `mike deploy <version> --rebuild`

**Issue: Git authentication errors**
- Ensure you have proper credentials for pushing to gh-pages
- In CI, verify the deploy key or token has write access

## Example Workflow

```bash
# Initial setup
mike deploy 1.0 latest --push

# Release a new version
mike deploy 2.0 latest --push

# Fix a typo in version 1.0
mike deploy 1.0 --rebuild --push

# Remove an old version
mike delete 0.9 --push

# Check what's deployed
mike list
```

## Resources

- [Mike Documentation](https://github.com/jimporter/mike)
- [MkDocs Material Versioning](https://squidfunk.github.io/mkdocs-material/setup/setting-up-versioning/)
- [Mike PyPI Package](https://pypi.org/project/mike/)
