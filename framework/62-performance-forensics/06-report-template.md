# Performance Forensics Report Template

## 1. Executive summary

- Why the target is slow:
- Primary bottleneck:
- Secondary bottlenecks:
- Affected layer classification:
- Expected maximum realistic improvement:
- Confidence:

## 2. Exact request flow

`Step | File/method/system | Work performed | Duration | Evidence`

## 3. Timing breakdown

`Stage | Cold duration | Warm duration | Expected duration | Evidence`

## 4. Complete checklist results

For every applicable checklist item:

`Category | Item | Status | Evidence | Notes`

Status must be one of: working correctly, defective, missing and applicable, not applicable, unable to verify.

## 5. Confirmed bottlenecks

`Priority | Bottleneck | Exact location | Root cause | Evidence | User impact`

## 6. Optimization candidates

`Priority | Optimization | Current implementation | Required change | Expected improvement | Effort | Risk | Files/queries affected`

Priorities: P0, P1, P2, P3, Rejected.

## 7. Best implementation package

- Immediate safe fixes:
- Database fixes:
- Backend fixes:
- Cache fixes:
- Pagination fixes:
- Frontend fixes:
- Infrastructure fixes:
- Advanced future fixes:

## 8. Rejected optimizations

List optimizations that already work, are irrelevant, add complexity without measurable gain, risk correctness/security, or are premature.

## 9. Verification plan

Define before-and-after targets for SQL rows query, SQL count query, Redis hit/miss, API total time, TTFB, payload size, serialization, download, frontend parse, render, time to interactive, p50, p95, p99, and concurrency.

## 10. Approval gate

Provide numbered implementation order and stop for approval.

## 11. Additional techniques discovered

List techniques and risks discovered outside the baseline checklist, or state that none were discovered and what evidence would be needed to reduce uncertainty.

## 12. Completeness statement

State which items were fully verified, source-inspected only, required runtime access, required production metrics, could not be verified, and what uncertainty remains. Do not say "fully optimized."
