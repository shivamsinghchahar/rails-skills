---
name: rails-skill-index
description: Master index of all Rails agent skills covering controllers, testing, PostgreSQL, real-time communication, file storage, background jobs, and security.
---

# Rails Agent Skills - Complete Index

**9 comprehensive skills** for building professional Rails applications.

## Skills Overview

### Core Rails Foundations (3 skills)

| Skill | Files | Focus |
|-------|-------|-------|
| **rails-active-record** | 9 | Models, associations, validations, migrations, querying, callbacks, inheritance |
| **rails-action-controller** | 7 | HTTP requests, RESTful routing, parameters, authentication, callbacks, sessions, error handling |
| **rails-testing-rspec** | 6 | RSpec setup, FactoryBot, mocking, test organization |

### Real-Time Communication (1 skill)

| Skill | Files | Focus |
|-------|-------|-------|
| **rails-action-cable** | 6 | WebSocket connections, channels, broadcasting, real-time features, testing |

### File Management (1 skill)

| Skill | Files | Focus |
|-------|-------|-------|
| **rails-active-storage** | 9 | File uploads, cloud storage (S3/GCS), image variants, direct uploads, testing |

### Data Layer (1 skill)

| Skill | Files | Focus |
|-------|-------|-------|
| **rails-postgres** | 5 | Complex queries, indexes, optimization, UUID, JSON/JSONB, custom types |

### Email & Background Processing (2 skills)

| Skill | Files | Focus |
|-------|-------|-------|
| **rails-action-mailer** | 6 | Email configuration, sending emails, templates, callbacks, interceptors |
| **rails-active-job** | 7 | Job definition, scheduling, retries, error handling, monitoring |

### Code Quality & Security (1 skill)

| Skill | Files | Focus |
|-------|-------|-------|
| **rails-security-audits** | 6 | Brakeman, bundler-audit, CSP, vulnerability scanning |

### Code Review (1 skill)

| Skill | Files | Focus |
|-------|-------|-------|
| **code-review** | 6 | Universal review with auto-detection for Rails, React, extensible for other stacks |

---

## Skill Descriptions for Agent Discovery

### rails-active-record
Master Active Record for building complex model relationships, querying, validations, migrations, and advanced patterns. Use when defining model associations, implementing validations, creating database migrations, querying complex datasets, or building inheritance patterns with STI.

### rails-active-storage
Master Rails Active Storage for file attachments, cloud storage integration, image transformations, and direct uploads. Use when implementing file uploads, managing S3/GCS storage, generating image variants, processing direct uploads, or testing file handling.

### rails-action-controller
Build Rails Action Controllers to handle HTTP requests with RESTful actions, routing, strong parameters, callbacks, and filters. Use when creating API endpoints, handling authentication/authorization, managing request lifecycles, working with cookies/sessions, or building both JSON and HTML responses.

### rails-action-cable
Master Action Cable for real-time WebSocket communication in Rails. Use when building live chat, notifications, presence tracking, collaborative editing, live dashboards, or any real-time feature requiring instant server-to-client updates.

### rails-action-mailer
Configure and send emails with Action Mailer including templates, callbacks, and interceptors. Use when setting up email delivery, creating email templates, handling mail callbacks, or testing email functionality.

### rails-testing-rspec
Write Rails tests with RSpec, FactoryBot, and mocking patterns. Use when creating tests, writing specs for models/controllers/requests, setting up test fixtures, or mocking external services.

### rails-postgres
Write efficient PostgreSQL queries in Rails using ActiveRecord, raw SQL, indexes, and query optimization. Use PostgreSQL native types including UUID, JSON/JSONB, arrays, ranges, and enums. Use when building complex queries, optimizing N+1 issues, creating indexes, debugging slow queries, or storing complex data structures.

### rails-active-job
Build background jobs with Active Job including job definition, scheduling, retries, and error handling. Use when creating jobs, managing queues, scheduling recurring tasks, or handling async processing.

### rails-security-audits
Audit Rails applications for security vulnerabilities using Brakeman, Bundler Audit, and security best practices. Use when scanning for CVEs, setting up security checks, or implementing security headers.

### code-review
Perform comprehensive code reviews for any stack with automatic stack detection and severity-classified findings. Use when reviewing pull requests, analyzing code changes, performing security audits, or evaluating code quality. Supports Rails (Ruby), React (TypeScript/JavaScript), and is extensible for other stacks. Triggers on phrases like "review this PR", "code review", "review these changes", "analyze this code", or when explicitly requesting review of specific files or git diffs.

### skill-creator
Create and package custom agent skills with proper structure, metadata, and documentation. Use when designing new skills, following skill development best practices, or extending the agent skill ecosystem.

---

## File Structure Summary

```
skills/
├── rails-active-record/
│   ├── SKILL.md                      (metadata + quick start)
│   ├── associations.md               (has_many, belongs_to, has_one, polymorphic, through)
│   ├── validations.md                (presence, uniqueness, custom validators, conditional)
│   ├── inheritance.md                (STI, polymorphism, class table inheritance)
│   ├── querying.md                   (scopes, eager loading, N+1 prevention, optimization)
│   ├── migrations.md                 (create tables, schema changes, zero-downtime migrations)
│   ├── patterns.md                   (callbacks, soft deletes, transactions, optimization)
│   ├── examples.md                   (real-world implementations)
│   ├── advanced-composite-keys.md    (composite primary keys, multi-column identifiers)
│   ├── advanced-databases.md         (multiple databases, sharding, replication)
│   ├── advanced-encryption.md        (encrypted columns, secrets management)
│   ├── references/
│   │   ├── associations-advanced.md  (advanced relationship patterns)
│   │   ├── callbacks-lifecycle.md    (lifecycle hooks, callback ordering)
│   │   ├── querying-advanced.md      (complex queries, subqueries, window functions)
│   │   └── performance-optimization.md (caching, indexing, query analysis)
│   └── scripts/
│       ├── model-scaffold.sh         (model generation scripts)
│       └── migration-helper.sh       (migration utilities)
│
├── rails-action-controller/
│   ├── SKILL.md                      (metadata + quick start)
│   ├── routing-params.md             (RESTful routes, strong parameters, path/query)
│   ├── filters-callbacks.md          (before/after/around filters, callbacks)
│   ├── patterns.md                   (error handling, responders, request lifecycle)
│   ├── examples.md                   (real-world controller implementations)
│   ├── references/
│   │   ├── sessions-cookies.md       (session management, cookie handling, storage)
│   │   ├── authentication-advanced.md (JWT, API tokens, OAuth, authorization)
│   │   └── streaming-downloads.md    (file downloads, streaming responses)
│   └── scripts/
│       ├── rest-controller-scaffold.sh
│       └── api-controller-template.sh
│
├── rails-action-cable/
│   ├── SKILL.md                      (metadata + quick start)
│   ├── references/
│   │   ├── channels-basics.md        (channel definition, subscriptions, streams)
│   │   ├── client-side-integration.md (JavaScript consumer, connection setup)
│   │   ├── connection-setup.md       (ActionCable server configuration, authentication)
│   │   ├── examples.md               (real-world implementations)
│   │   ├── streaming-broadcasting.md (broadcasting messages, stream updates)
│   │   └── testing.md                (testing ActionCable channels)
│   └── scripts/
│
├── rails-action-mailer/
│   ├── SKILL.md                   (metadata + quick start)
│   ├── callbacks-interceptors.md  (before/after callbacks, mail interception)
│   ├── configuration.md           (SMTP setup, environment configuration)
│   ├── examples.md                (real-world email implementations)
│   ├── mailers-views.md           (mailer classes, email templates, layouts)
│   ├── sending-emails.md          (deliver_now, deliver_later, queuing)
│   ├── testing.md                 (testing mailers, email assertions)
│   └── references/
│       └── advanced-patterns.md   (complex email workflows, templates)
│
├── rails-active-job/
│   ├── SKILL.md                   (metadata + quick start)
│   ├── references/
│   │   ├── job-basics/            (job definition, perform method)
│   │   ├── queue-management/      (queue names, priority, scheduling)
│   │   ├── advanced-features/     (retries, error handling, callbacks)
│   │   └── examples/              (real-world job implementations)
│   └── scripts/
│
├── rails-active-storage/
│   ├── SKILL.md                        (metadata + quick start)
│   ├── attaching-files.md              (has_one_attached, has_many_attached)
│   ├── direct-uploads.md               (S3/GCS direct uploads, signed URLs)
│   ├── examples.md                     (real-world file upload implementations)
│   ├── file-operations.md              (validation, size limits, deletion)
│   ├── serving-and-transformations.md  (image variants, processing, URLs)
│   ├── setup-and-configuration.md      (service setup, cloud storage configuration)
│   ├── testing.md                      (testing file attachments)
│   ├── references/
│   └── scripts/
│
├── rails-postgres/
│   ├── SKILL.md                   (metadata + quick start)
│   ├── examples.md                (real-world query and type examples)
│   └── references/
│       ├── queries.md             (SQL patterns, complex queries, optimization)
│       ├── indexes.md             (index strategies, performance tuning)
│       ├── types.md               (UUID, JSON/JSONB, arrays, ranges, enums)
│       └── advanced.md            (window functions, CTEs, advanced patterns)
│
├── rails-testing-rspec/
│   ├── SKILL.md                   (metadata + quick start)
│   ├── rspec-setup.md             (RSpec configuration, test environment)
│   ├── factories-fixtures.md       (FactoryBot, fixtures, test data)
│   ├── mocking-stubbing.md        (double, stub, allow, expect)
│   ├── patterns.md                (test organization, best practices)
│   ├── examples.md                (real-world test implementations)
│   └── scripts/
│
├── rails-security-audits/
│   ├── SKILL.md                   (metadata + quick start)
│   ├── brakeman-security.md       (Brakeman setup, vulnerability scanning)
│   ├── bundler-audit.md           (Bundler Audit, dependency vulnerability checks)
│   ├── csp-headers.md             (Content Security Policy, security headers)
│   ├── patterns.md                (security best practices, common vulnerabilities)
│   ├── examples.md                (real-world security implementations)
│   └── scripts/
│
├── code-review/
│   ├── SKILL.md                   (entry point, detection, workflow)
│   └── references/
│       ├── severity-levels.md     (P0-P3 definitions)
│       ├── general-review.md      (universal principles)
│       ├── rails-review.md        (Rails-specific patterns)
│       ├── react-review.md        (React-specific patterns)
│       └── review-checklist.md    (master checklist)
│
└── skill-creator/
    ├── SKILL.md                   (metadata + quick start)
    ├── LICENSE.txt                (MIT license template)
    ├── references/                (skill development guides)
    └── scripts/                   (skill scaffolding, validation tools)
```

---

## How AI Agents Use These Skills

**Automatic discovery**: Agent loads SKILL.md metadata. Only reads full content when triggered by:
- Explicit user requests ("Create a migration...", "Write tests...")
- Keyword matches in user input
- Contextual relevance to the task

**Progressive disclosure**: 
- SKILL.md = quick reference + entry points
- Reference files = detailed patterns, loaded only when needed
- Examples.md = real-world implementations

**Performance**: 
- Metadata pre-loaded (59 bytes each)
- Reference files loaded on-demand (~500-5000 tokens each)
- Scripts ready for execution (0 tokens in context until run)

---

## Skill Dependency Matrix

```
No hard dependencies - skills compose naturally:

rails-active-record ─┬─→ rails-testing-rspec (test models)
                     └─→ rails-postgres (query optimization, custom types)

rails-action-controller ┬─→ rails-testing-rspec (test controllers)
                        └─→ rails-security-audits (protect endpoints)
```

---

## Next Steps

1. **Use with AI agents**: Upload `skills/` folder to your AI agent
2. **Test discovery**: Ask the agent to "create a User model" → triggers rails-active-record
3. **Compose skills**: "Test the migration and model" → uses multiple skills together
4. **Customize**: Edit SKILL.md descriptions for your specific project patterns
5. **Extend**: Add custom .md files for team-specific practices (coding standards, deployment process, etc.)

---

## Best Practices Applied

✅ **Concise descriptions** (max 1024 chars each)  
✅ **Progressive disclosure** (metadata → body → references → files)  
✅ **One-level-deep links** (all references link directly from SKILL.md)  
✅ **Consistent naming** (gerund form: rails-{domain}-{feature})  
✅ **Clear trigger conditions** (what to use each skill for)  
✅ **Real-world examples** (production patterns, not academic)  
✅ **No time-sensitive content** (valid from 2024 onward)
