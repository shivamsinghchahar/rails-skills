# Security Configuration Examples

## Complete Security Setup

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    # Force SSL in production
    config.force_ssl = true if Rails.env.production?
    
    # HSTS with preload
    config.ssl_options = {
      hsts: {
        max_age: 31536000,
        include_subdomains: true,
        preload: true
      }
    }
    
    # Secure cookies
    config.session_store :cookie_store,
      key: '_myapp_session',
      secure: Rails.env.production?,
      http_only: true,
      same_site: :strict
    
    # Content Security Policy
    config.content_security_policy do |policy|
      policy.default_src :self
      policy.script_src :self
      policy.style_src :self
      policy.img_src :self, :https, :data
      policy.font_src :self, :data
      policy.connect_src :self
      policy.form_action :self
      policy.frame_ancestors :none
    end
  end
end
```

## Security Initialization

```ruby
# config/initializers/security_headers.rb
Rails.application.configure do
  config.middleware.insert_before Rack::Runtime, Rack::MimeTypes
  
  config.x.secure_headers = {
    x_content_type_options: 'nosniff',
    x_frame_options: 'DENY',
    x_xss_protection: '1; mode=block'
  }
end

# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self, :unsafe_inline
    policy.style_src :self, :unsafe_inline
    policy.img_src :self, :data, :https
    policy.report_uri "/csp-reports"
  end
end

# config/initializers/secure_cookies.rb
Rails.application.configure do
  config.session_store :cookie_store,
    key: '_myapp_session',
    secure: !Rails.env.development?,
    http_only: true,
    same_site: :lax
end
```

## CI/CD Security Checks

```yaml
# .github/workflows/security.yml
name: Security Checks

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3.0
          bundler-cache: true
      
      - name: Run Brakeman
        run: bundle exec brakeman -q -z
      
      - name: Run bundler-audit
        run: bundle exec bundler-audit check --update
      
      - name: Run rubocop security
        run: bundle exec rubocop -D
      
      - name: Check for hardcoded secrets
        run: |
          grep -r "sk_test\|sk_live" --include="*.rb" . && exit 1 || true
          grep -r "password.*=" --include="*.rb" config && exit 1 || true
```

## Incident Response

When a vulnerability is found:

```ruby
# 1. Create issue tracker
class SecurityIssue < ApplicationRecord
  validates :cve, :severity, presence: true
  enum severity: { low: 0, medium: 1, high: 2, critical: 3 }
end

# 2. Track remediation
class SecurityRemedy
  def apply(cve_id)
    issue = SecurityIssue.find_by(cve: cve_id)
    
    case issue.cve
    when 'CVE-2021-12345'
      update_vulnerable_gem
    when 'CVE-2021-23456'
      patch_sql_injection
    end
    
    issue.update(status: 'resolved')
  end
end

# 3. Test the fix
RSpec.describe 'CVE-2021-12345' do
  it 'is fixed' do
    # Regression test
    expect { vulnerable_code }.to raise_error(SecurityError)
  end
end
```
