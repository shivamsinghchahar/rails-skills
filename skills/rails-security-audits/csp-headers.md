# Content Security Policy and Headers

## Content Security Policy (CSP)

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    # Default source for all resources
    policy.default_src :self
    
    # Scripts
    policy.script_src :self, :unsafe_inline, :unsafe_eval
    
    # Stylesheets
    policy.style_src :self, :unsafe_inline
    
    # Images
    policy.img_src :self, :data, :https
    
    # Fonts
    policy.font_src :self, :data
    
    # XHR, WebSocket, EventSource
    policy.connect_src :self
    
    # Form submission
    policy.form_action :self
    
    # Frame embedding
    policy.frame_ancestors :none
    
    # Report violations
    policy.report_uri "/csp-reports"
  end
  
  # Report-only mode (development)
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src)
end
```

## Strict CSP

```ruby
# More restrictive
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :none
    policy.script_src :self
    policy.style_src :self
    policy.img_src :self
    policy.font_src :self
    policy.connect_src :self
    policy.form_action :self
    policy.frame_ancestors :none
    policy.base_uri :self
    policy.object_src :none
  end
end
```

## Other Security Headers

```ruby
# config/initializers/secure_headers.rb
Rails.application.configure do
  # Prevent browsers from MIME-sniffing
  config.middleware.insert_before Rack::Runtime, Rack::MimeTypes
  config.x.secure_headers = {
    x_content_type_options: 'nosniff',
    x_frame_options: 'DENY',
    x_xss_protection: '1; mode=block',
    strict_transport_security: {
      max_age: 31536000,
      include_subdomains: true,
      preload: true
    }
  }
end
```

## Middleware Configuration

```ruby
# config/application.rb
module MyApp
  class Application < Rails::Application
    config.middleware.use Rack::HostAuthorization, hosts: [
      'example.com',
      /example\.(com|org)/
    ]
    
    # HSTS (HTTP Strict Transport Security)
    config.ssl_options = {
      hsts: { max_age: 31536000, preload: true }
    }
  end
end
```

## Testing CSP

```ruby
# spec/support/csp_helpers.rb
def expect_csp_header
  expect(response.headers['Content-Security-Policy']).to be_present
end

def expect_hsts_header
  expect(response.headers['Strict-Transport-Security']).to be_present
end

# Usage in specs
describe PostsController do
  it 'sets CSP header' do
    get posts_path
    expect_csp_header
  end
end
```

## Report CSP Violations

```ruby
# app/controllers/csp_reports_controller.rb
class CspReportsController < ApplicationController
  skip_forgery_protection
  
  def create
    report = params[:csp_report]
    
    SecurityAlert.create!(
      blocked_uri: report['blocked_uri'],
      document_uri: report['document_uri'],
      violation_report_data: report
    )
    
    render json: { status: 'received' }
  end
end

# config/routes.rb
post '/csp-reports', to: 'csp_reports#create'
```

## Browser Compatibility

CSP support by browser:
- Chrome/Chromium: Full support
- Firefox: Full support
- Safari: Full support
- IE: Limited support

Use feature detection in views:

```erb
<meta http-equiv="Content-Security-Policy" content="...">

<script>
  // Only for modern browsers with nonce
  if (document.currentScript?.nonce) {
    // Safe to use inline scripts
  }
</script>
```
