# Code Review Checklist

Comprehensive checklist for conducting thorough code reviews. Use alongside stack-specific references.

---

## Pre-Review Setup

- [ ] Understand the PR goal (what problem does it solve?)
- [ ] Identify files in scope
- [ ] Detect stacks present (Rails, React, etc.)
- [ ] Load relevant stack-specific references
- [ ] Check for related PRs or documentation

---

## General Principles

### Design
- [ ] Code is in appropriate location
- [ ] Proper separation of concerns
- [ ] Dependencies point in correct direction
- [ ]SOLID principles followed
- [ ] Appropriate abstraction level

### Functionality
- [ ] Code does what PR description claims
- [ ] Works for end users
- [ ] Edge cases handled (empty, null, boundary)
- [ ] Error cases handled gracefully
- [ ] No silent failures

### Complexity
- [ ] Methods under 50 lines
- [ ] Classes under 200 lines
- [ ] Nesting under 3 levels
- [ ] No clever code sacrificing readability
- [ ] Could new developer understand it?

### Naming
- [ ] Variables: descriptive, meaningful
- [ ] Methods: verb-based, clear purpose
- [ ] Classes: noun-based, single responsibility
- [ ] Constants: SCREAMING_SNAKE for true constants
- [ ] No abbreviations unless widely known
- [ ] Consistent casing throughout

### Comments
- [ ] Comments explain WHY, not WHAT
- [ ] No commented-out code
- [ ] Complex logic documented
- [ ] TODOs have ticket references
- [ ] Comments still accurate

### Style
- [ ] Follows project style guide
- [ ] Linter warnings addressed
- [ ] Consistent formatting
- [ ] No magic numbers

---

## Testing

### Coverage
- [ ] Unit tests for new code
- [ ] Integration tests if applicable
- [ ] Edge cases covered
- [ ] Error cases tested
- [ ] Happy path tested

### Quality
- [ ] Tests are readable
- [ ] Tests are maintainable
- [ ] Tests are deterministic
- [ ] No test interdependencies
- [ ] Proper setup/teardown

### Naming
- [ ] Descriptive test names
- [ ] `test_behavior_when_condition` format
- [ ] No generic names like `test1`

---

## Security

### Input Validation
- [ ] All user inputs validated
- [ ] Type checking in place
- [ ] Range checking for numbers
- [ ] Format validation for strings

### Authentication & Authorization
- [ ] Authentication on protected resources
- [ ] Authorization checks before actions
- [ ] Session management secure
- [ ] Password handling proper (hashing, not plaintext)

### Data Protection
- [ ] No hardcoded secrets
- [ ] Environment variables for config
- [ ] SQL injection prevented
- [ ] XSS prevented
- [ ] CSRF protection present
- [ ] Sensitive data not logged

### Dependencies
- [ ] No known vulnerable packages
- [ ] Dependencies up-to-date
- [ ] Minimal dependency usage

---

## Performance

### Algorithms
- [ ] Appropriate algorithm choice
- [ ] Reasonable time complexity
- [ ] No unnecessary iterations

### Database
- [ ] Efficient queries (no SELECT *)
- [ ] Proper indexes on queried columns
- [ ] N+1 queries prevented
- [ ] Connection pooling considered

### Caching
- [ ] Caching used where appropriate
- [ ] Cache invalidation handled
- [ ] Memory usage reasonable

### Resource Management
- [ ] Files properly closed
- [ ] Connections released
- [ ] No memory leaks
- [ ] Async operations handled

---

## Rails-Specific

### Models
- [ ] Validations present and appropriate
- [ ] Associations have `inverse_of`
- [ ] `dependent` specified for has_many
- [ ] Scopes are chainable
- [ ] No default_scope issues
- [ ] Callbacks have proper ordering

### Controllers
- [ ] `before_action` for auth
- [ ] Strong parameters used
- [ ] Error handling consistent
- [ ] No logic in controllers
- [ ] Proper HTTP status codes

### Views
- [ ] No business logic
- [ ] XSS prevention (no raw on user input)
- [ ] Helpers for reusable presentation
- [ ] No database queries

### Jobs
- [ ] Single responsibility in perform
- [ ] Retries with backoff
- [ ] Error handling appropriate
- [ ] Arguments serializable

### Migrations
- [ ] Reversible migrations
- [ ] Zero-downtime patterns
- [ ] Indexes for foreign keys
- [ ] No data loss risks

---

## React-Specific

### Components
- [ ] Single responsibility
- [ ] Under 200 lines
- [ ] Named exports preferred
- [ ] Props interface defined
- [ ] No prop drilling > 2-3 levels

### Hooks
- [ ] Rules of hooks followed
- [ ] Dependency arrays complete
- [ ] Cleanup in useEffect
- [ ] Custom hooks named use*

### State
- [ ] Immutable updates
- [ ] State colocated
- [ ] Server state in TanStack Query
- [ ] No unnecessary state

### TypeScript
- [ ] Strict mode enabled
- [ ] No `any` without justification
- [ ] Proper interfaces/types
- [ ] Event handlers typed

### Performance
- [ ] React.memo for pure components
- [ ] Stable keys (not index)
- [ ] Lazy loading for routes
- [ ] No unnecessary re-renders

### Accessibility
- [ ] Semantic HTML
- [ ] Button for clickable, not div
- [ ] Keyboard navigation works
- [ ] Alt text on images

---

## Documentation

### Code
- [ ] Complex logic explained
- [ ] Public APIs documented
- [ ] README updated if needed
- [ ] API docs updated

### Changes
- [ ] CHANGELOG updated
- [ ] Migration guide for breaking changes
- [ ] API versioning considered

---

## Post-Review

### For Author
- [ ] All P0 issues addressed
- [ ] All P1 issues addressed or scheduled
- [ ] P2 issues have follow-up tickets
- [ ] All comments addressed
- [ ] PR description updated if needed

### For Reviewer
- [ ] All findings documented
- [ ] Severity levels appropriate
- [ ] Actionable suggestions provided
- [ ] Good work acknowledged

---

## Finding Classification

Use this to classify each issue:

| Severity | Criteria | Action |
|----------|----------|--------|
| **P0** | Security, data loss, correctness | Must block merge |
| **P1** | Logic error, SOLID violation, perf | Should fix before merge |
| **P2** | Code smell, maintainability | Fix or create follow-up |
| **P3** | Style, naming, minor | Optional |

When in doubt, classify higher (P2 instead of P3).
