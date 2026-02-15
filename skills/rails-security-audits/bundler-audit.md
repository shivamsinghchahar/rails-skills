# Bundler Audit

## Installation

```ruby
# Gemfile
group :development, :test do
  gem 'bundler-audit', require: false
end
```

## Running Bundler Audit

```bash
# Check for known vulnerabilities
bundle exec bundler-audit check

# Update vulnerability database
bundle exec bundler-audit update

# Check and show details
bundle exec bundler-audit check --verbose

# Generate JSON report
bundle exec bundler-audit check --json > audit.json
```

## Common Vulnerabilities

### Outdated Gem Versions

```
Name: rails
Version: 6.0.0
Advisory: CVE-2021-22942
Criticality: High
URL: https://github.com/rails/rails/security/advisories/GHSA-4xpg-poq8-fcpg
Title: Potential CSRF vulnerability
Solution: upgrade to >= 6.0.4.7
```

### Known Issues

Rails gems frequently have security updates. Always monitor for:
- Authentication bypasses
- SQL injection vulnerabilities
- XSS vulnerabilities
- Denial of service

## Configuration

Create `config/bundler-audit.yml`:

```yaml
---
ignore:
  - CVE-2021-12345  # Pending fix, safe in our usage
  - CVE-2021-23456
```

## Ignore Specific Vulnerabilities

```bash
# Create ignore file
bundle exec bundler-audit check --update

# Edit ignored vulnerabilities
# config/bundler-audit.yml
---
ignore:
  - CVE-2021-12345  # Safe because we don't use affected feature
```

## Update Dependencies

```bash
# Check for updates
bundle outdated

# Update gem
bundle update rails --patch

# Update all dependencies
bundle update

# Update bundler-audit database
bundle exec bundler-audit update
```

## CI/CD Integration

```yaml
# .github/workflows/audit.yml
name: Bundler Audit

on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3.0
          bundler-cache: true
      
      - name: Run bundler-audit
        run: |
          gem install bundler-audit
          bundler-audit check --update --ignore config/bundler-audit.yml
```

## Continuous Monitoring

### Dependabot (GitHub)

Enable automatic dependency updates:

1. Go to repository settings
2. Enable "Dependabot" alerts and updates
3. Configure `dependabot.yml`:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: bundler
    directory: "/"
    schedule:
      interval: weekly
    open-pull-requests-limit: 10
    reviewers:
      - you@example.com
```

### Snyk

Monitor for vulnerabilities:

```bash
# Install Snyk
npm install -g snyk

# Test dependencies
snyk test

# Monitor for updates
snyk monitor
```
