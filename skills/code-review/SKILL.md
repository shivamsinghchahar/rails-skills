---
name: code-review
description: Perform comprehensive code reviews for any stack with automatic stack detection and severity-classified findings. Use when reviewing pull requests, analyzing code changes, performing security audits, or evaluating code quality. Supports Rails (Ruby), React (TypeScript/JavaScript), and is extensible for other stacks. Triggers on phrases like "review this PR", "code review", "review these changes", "analyze this code", "check for issues", or when explicitly requesting review of specific files or git diffs.
---

# Code Review

Comprehensive, stack-aware code review skill that automatically detects what languages/frameworks are in scope and routes to appropriate review logic.

## Review Modes

This skill operates in three modes based on what you provide:

| Mode | Trigger | How to Invoke |
|------|---------|---------------|
| **Git Diff** | `git diff` available | Default when reviewing PRs/changes |
| **File Review** | Specific files | "Review `app/models/user.rb` and `app/controllers/`" |
| **Snippet Review** | Code provided directly | "Review this code: `def foo; end`" |

## Workflow

```
1. SCOPE IDENTIFICATION
   ├── Git diff mode: Run git diff --name-only to get changed files
   ├── File mode: Use specified file paths
   └── Snippet mode: Analyze provided code directly

2. STACK DETECTION
   └── Match file patterns to stacks:
       ├── *.rb, app/models/, app/controllers/ → Rails
       ├── *.tsx, *.jsx, app/javascript/, components/ → React
       ├── *.py → Python (extend as needed)
       └── (always load general-review.md)

3. LOAD REFERENCES
   ├── Always: severity-levels.md, general-review.md
   └── Stack-specific: rails-review.md, react-review.md (when detected)

4. REVIEW EXECUTION
   └── For each file:
       ├── Apply general principles
       ├── Apply stack-specific checks
       └── Record findings with severity

5. OUTPUT GENERATION
   └── Interleave findings by severity (not by stack)
   └── Include inline code comments
```

## Output Format

```markdown
## Code Review Summary
**Files reviewed**: X | **Stacks detected**: Rails, React | **Assessment**: [APPROVE/REQUEST_CHANGES/COMMENT]

---

## Findings

### P0 - Critical
(none or list with fix examples)

### P1 - High
1. **[file:line]** Issue title
   - Impact description
   - ```language
     // Before (problematic)
     code
     
     // After (fixed)
     code
     ```

### P2 - Medium
...

### P3 - Low
...

---

::code-comment{file="path/to/file" line="42" severity="P1"}
Inline explanation of the issue and suggested fix.
::
```

## Inline Code Comments

Use this format for PR/tool integrations:

```text
::code-comment{file="app/models/user.rb" line="42" severity="P1"}
Consider using `find_by(email: email)` instead of `find_by_email(email)`
to avoid the deprecation warning in Rails 7.1+.
::
```

## Severity Levels

**P0 - Critical**: Security vulnerability, data loss risk, correctness bug
- Must block merge

**P1 - High**: Logic error, significant violation, performance regression
- Should fix before merge

**P2 - Medium**: Code smell, maintainability concern
- Fix in PR or create follow-up

**P3 - Low**: Style, naming, minor suggestion
- Optional improvement

See [severity-levels.md](references/severity-levels.md) for detailed definitions.

## Stack-Specific Reviews

### Rails Review

See [rails-review.md](references/rails-review.md) for:
- Models: validations, associations, N+1 prevention, scopes, callbacks
- Controllers: filters, params, error handling, responses
- Jobs: perform method, retries, error handling
- Mailers: deliver_later, templates
- Migrations: zero-downtime patterns, reversibility
- Views: XSS prevention, helpers

### React Review

See [react-review.md](references/react-review.md) for:
- Components: single responsibility, composition, exports
- Hooks: rules of hooks, dependency arrays, cleanup
- State: immutable updates, colocation, server vs client
- TypeScript: strict mode, no any, proper types
- Performance: React.memo, keys, lazy loading
- Accessibility: semantic HTML, keyboard nav, alt text

## General Review Principles

Always apply these universal principles regardless of stack:

See [general-review.md](references/general-review.md) for:
- Design: appropriate abstraction, separation of concerns
- Functionality: correct behavior, edge cases handled
- Complexity: simplicity, readability for future maintainers
- Tests: correctness, coverage, maintainability
- Naming: clarity, descriptiveness, consistency
- Comments: explain "why", not "what"
- Style: consistency with codebase conventions

## Master Checklist

For comprehensive reviews, see [review-checklist.md](references/review-checklist.md):
- General items (always check)
- Rails-specific items
- React-specific items

## Usage Examples

**Review current git changes:**
```
Review my current git diff for any issues.
```

**Review specific files:**
```
Review app/models/user.rb and app/controllers/users_controller.rb
```

**Review mixed stacks:**
```
This PR has Rails backend changes and React frontend changes.
Review everything.
```

**Quick scan:**
```
Just do a quick review, focus on critical issues.
```
