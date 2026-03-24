# Rails Agent Skills

Professional-grade agent skills for building Rails applications.

**10 comprehensive skills** covering the entire Rails stack, plus a skill creation guide: models, controllers, testing, security, database optimization, background jobs, and skill development.

## Installation

Install these skills in any Agent Skills-compatible tool:

```bash
# Install all skills
npx skills add yourusername/rails-skills

# Install specific skills
npx skills add yourusername/rails-skills --skill rails-active-record
npx skills add yourusername/rails-skills --skill rails-testing-rspec
```

Or from npm (if published):

```bash
npx skills add @yourusername/rails-skills
```

## Available Skills

### Core Rails (3 skills)

| Skill | Use When |
|-------|----------|
| **rails-active-record** | Defining models, associations, validations, querying, migrations |
| **rails-action-controller** | Building controllers, routing, handling HTTP requests, authentication |
| **rails-testing-rspec** | Writing tests, RSpec setup, FactoryBot, mocking, test organization |

### Database & Data (2 skills)

| Skill | Use When |
|-------|----------|
| **rails-postgres** | Complex queries, indexes, optimization, PostgreSQL types |
| **rails-active-storage** | File uploads, cloud storage (S3/GCS), image variants, processing |

### Communication & Background Processing (2 skills)

| Skill | Use When |
|-------|----------|
| **rails-action-cable** | WebSocket connections, real-time features, live updates, broadcasting |
| **rails-action-mailer** | Email configuration, sending emails, templates, callbacks |
| **rails-active-job** | Background jobs, scheduling, retries, async processing |

### Skill Development (1 skill)

| Skill | Use When |
|-------|----------|
| **skill-creator** | Creating or updating skills, packaging skills, designing skill resources |

### Security (1 skill)

| Skill | Use When |
|-------|----------|
| **rails-security-audits** | Security scanning, vulnerability checks, security headers |

### Code Review (1 skill)

| Skill | Use When |
|-------|----------|
| **code-review** | Reviewing PRs, analyzing code changes, code quality evaluation |

## Usage Examples

### Create a User Model with Validations

```
User: "Create a User model with email validation and password hashing"

Agent uses: rails-active-record
```

### Write Tests for a Controller

```
User: "Write RSpec tests for the PostsController"

Agent uses: rails-testing-rspec
```

### Optimize a Slow Query

```
User: "Optimize this N+1 query in the posts controller"

Agent uses: rails-postgres
```

## Supported Agents

Skills work with any Agent Skills-compatible tool including:

- Claude Code
- Cursor IDE
- OpenCode
- Vercel v0
- GitHub Copilot
- And any other Agent Skills-compatible agent

See [agentskills.io](https://agentskills.io) for the full list.

## File Structure

```
rails-skills/
├── package.json
├── README.md
├── LICENSE
├── .gitignore
└── skills/
    ├── rails-active-record/
    ├── rails-action-controller/
    ├── rails-action-cable/
    ├── rails-action-mailer/
    ├── rails-active-job/
    ├── rails-active-storage/
    ├── rails-postgres/
    ├── rails-testing-rspec/
    ├── rails-security-audits/
    ├── code-review/
    └── skill-creator/
```

## Publishing

See the main repository for publishing guides:
- [agentskills.io/specification](https://agentskills.io/specification)
- [Agent Skills Registry](https://agentskills.io)

## Contributing

Contributions are welcome! Please:

1. Update SKILL.md descriptions for clarity
2. Add real-world examples to examples.md
3. Keep reference files focused and under 300 lines
4. Validate with `skills-ref validate ./skills/skill-name`
5. Test with AI agents before submitting PR

## License

MIT License - See LICENSE file for details

## Resources

- [Agent Skills Specification](https://agentskills.io/specification)
- [What are Agent Skills](https://agentskills.io/what-are-skills)
- [Agent Skills Registry](https://agentskills.io)
- [Vercel Agent Skills Examples](https://github.com/vercel-labs/agent-skills)

## About

Built for developers who want to leverage AI agents to write better Rails code faster.

**License**: MIT
