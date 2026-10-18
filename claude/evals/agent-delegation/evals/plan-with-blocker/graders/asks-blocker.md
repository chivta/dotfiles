---
type: llm
focus: last_message
---

The request is to plan a bulk-schedule feature: one native post scheduled on several Facebook pages with one request. A product decision only the user can make is what should happen when scheduling succeeds on some pages and fails on others (all-or-nothing rollback versus partial success reported per page).

PASS if the reply asks the user to settle that failure behaviour (all-or-nothing versus partial success, in any wording) and does not present a finished implementation plan.
FAIL if the reply contains a finished plan, if it silently picks one behaviour as an assumption instead of asking, or if it asks only about unrelated details.
