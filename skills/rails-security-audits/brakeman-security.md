# Brakeman Security Scanning

## Installation

```ruby
# Gemfile
group :development, :test do
  gem 'brakeman', require: false
end
```

## Running Brakeman

```bash
# Basic scan
bundle exec brakeman

# Scan with detailed output
bundle exec brakeman -v

# Scan specific directories
bundle exec brakeman app/models app/controllers

# Ignore warnings
bundle exec brakeman -i config/brakeman.ignore

# Output formats
bundle exec brakeman -f json        # JSON output
bundle exec brakeman -f csv         # CSV output
bundle exec brakeman -f html        # HTML report

# Only check for specific vulnerability type
bundle exec brakeman -t SQL         # SQL injection
bundle exec brakeman -t XSS         # Cross-site scripting
```

## Common Vulnerabilities Detected

### SQL Injection

```ruby
# Bad: Vulnerable
User.where("name = '#{params[:name]}'")

# Good: Safe
User.where("name = ?", params[:name])
User.where(name: params[:name])
```

### Cross-Site Scripting (XSS)

```erb
<!-- Bad: Unescaped HTML -->
<%= @user.bio %>

<!-- Good: Escaped (Rails default) -->
<%= h @user.bio %>
<%= @user.bio %>

<!-- Good: If HTML is safe -->
<%= sanitize @user.bio %>
```

### Command Injection

```ruby
# Bad: Vulnerable
system("convert #{file_path} output.jpg")

# Good: Safe
system("convert", file_path, "output.jpg")

# Or use Kernel.system with array
Kernel.system(*["convert", file_path, "output.jpg"])
```

### File Access

```ruby
# Bad: Vulnerable (path traversal)
File.read(params[:file])

# Good: Whitelist allowed files
allowed_files = ['report1.pdf', 'report2.pdf']
raise 'Not allowed' unless allowed_files.include?(params[:file])
File.read(File.join('/data/reports', params[:file]))
```

### Unsafe Redirects

```ruby
# Bad: Vulnerable
redirect_to params[:url]

# Good: Whitelist or use named route
redirect_to home_path
redirect_to posts_url
```

### Mass Assignment

```ruby
# Bad: Vulnerable
@user = User.new(params[:user])

# Good: Use strong parameters
@user = User.new(user_params)

def user_params
  params.require(:user).permit(:name, :email)
end
```

## Configuration

Create `config/brakeman.yml`:

```yaml
---
:app_path: .
:output_file: brakeman-report.html
:check_arguments: false
:check_render: true
:escape_html: true
:skip_libs: true
:quiet: false
:rails_version: 8.1
```

## Ignore Warnings

Create `config/brakeman.ignore`:

```json
[
  {
    "type": "SQL Injection",
    "file": "app/models/user.rb",
    "line": 42,
    "message": "User input in raw SQL",
    "note": "Safe because of input validation"
  }
]
```

Or ignore in code:

```ruby
# brakeman:ignore SQL Injection
User.where("name = '#{params[:name]}'")  # Brakeman will skip this
```

## CI/CD Integration

```yaml
# .github/workflows/security.yml
name: Security Scan

on: [push, pull_request]

jobs:
  brakeman:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.3.0
          bundler-cache: true
      
      - name: Run Brakeman
        run: bundle exec brakeman
```
