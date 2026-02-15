---
name: rails-security-audits
description: Audit Rails applications for security vulnerabilities using Brakeman, Bundler Audit, and security best practices. Use when scanning for CVEs, setting up security checks, or implementing security headers.
---

# Rails Security Audits

Identify and fix security vulnerabilities in Rails applications. This skill covers vulnerability scanning, dependency auditing, and security best practices.

## Quick Start

Add security gems:
```ruby
group :development, :test do
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
end
```

Run security scans:
```bash
# Scan for Rails vulnerabilities
bundle exec brakeman

# Audit dependencies for known vulnerabilities
bundle exec bundler-audit check --update

# Update vulnerability database
bundle exec bundler-audit update
```

Setup security headers in Rails:
```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self, :unsafe_inline
    policy.style_src :self, :unsafe_inline
  end
end
```

## Core Topics

**Brakeman Security**: See [brakeman-security.md](brakeman-security.md) for static analysis and common vulnerabilities.

**Bundler Audit**: See [bundler-audit.md](bundler-audit.md) for dependency vulnerability tracking.

**Security Headers**: See [csp-headers.md](csp-headers.md) for content security policy and headers.

**Patterns**: See [patterns.md](patterns.md) for common vulnerabilities and fixes.

## Examples

See [examples.md](examples.md) for configurations.
