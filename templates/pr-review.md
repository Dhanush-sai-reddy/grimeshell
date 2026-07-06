# PR Review Checklist

**PR**: #[NUMBER]
**Author**: [AUTHOR]
**Reviewer**: [REVIEWER]
**Date**: [DATE]

---

## Code Quality

- [ ] Code is readable and self-documenting
- [ ] No unnecessary complexity or over-engineering
- [ ] Functions are small and single-purpose (< 50 lines)
- [ ] No duplicated code — shared logic is extracted
- [ ] Variable and function names are descriptive
- [ ] No commented-out code left behind
- [ ] No TODO/FIXME without a linked issue

## Correctness

- [ ] Logic is correct and handles edge cases
- [ ] Error handling is present and appropriate
- [ ] No off-by-one errors
- [ ] Null/undefined checks where needed
- [ ] Async operations handled correctly (await, error callbacks)
- [ ] No race conditions

## Security

- [ ] No hardcoded secrets, API keys, or passwords
- [ ] User input is validated and sanitized
- [ ] No SQL injection / command injection vectors
- [ ] Authentication/authorization checks in place
- [ ] Sensitive data is not logged

## Testing

- [ ] New code has tests (unit, integration as appropriate)
- [ ] Existing tests still pass
- [ ] Edge cases are tested
- [ ] Test names describe the scenario being tested
- [ ] No flaky tests introduced

## Performance

- [ ] No unnecessary database queries (N+1 problem)
- [ ] No blocking operations in hot paths
- [ ] Large lists are paginated
- [ ] Heavy computations are cached or debounced
- [ ] No memory leaks (event listeners cleaned up, subscriptions unsubscribed)

## Git Hygiene

- [ ] Commit messages follow convention (`type: description`)
- [ ] Commits are atomic and logical
- [ ] No merge commits (rebased on main)
- [ ] Branch name follows pattern (`feature/`, `fix/`, `refactor/`)
- [ ] No unrelated changes bundled in

## Documentation

- [ ] Public functions/APIs are documented
- [ ] README updated if behavior changed
- [ ] Breaking changes are called out
- [ ] Architecture decision recorded (if applicable → `knowledge/decisions.md`)

## Deployment

- [ ] No breaking changes to env vars or config without migration plan
- [ ] Database migrations are reversible
- [ ] Feature flags used for risky changes
- [ ] Monitoring/alerting updated if needed

---

## Summary

**Verdict**: [ ] Approve | [ ] Request Changes | [ ] Comment Only

**Notes**:
> 

---

> *Template from SHELLLL brain — `templates/pr-review.md`*
