---
name: resolve-merge-conflicts
description: Use when you need to resolve an in-progress git merge/rebase conflict.
---

1. **See the current state** of the merge/rebase. Check git history, and the conflicting files.

2. **Find the primary sources** for each conflict. Understand deeply why each change was made, and what the original intent was. Read the commit messages, check the PRs, check original issues/tickets.

3. **Resolve each hunk.** Preserve both intents where possible. Where incompatible, pick the one matching the merge's stated goal and note the trade-off. Do **not** invent new behaviour. Always resolve; never `--abort`.

4. Discover the project's **automated checks** and run them — typically typecheck, then tests, then format. Fix anything the merge broke.

5. **Finish the merge/rebase.** Stage everything and commit. If rebasing, continue the rebase process until all commits are rebased. NEVER PUSH.

6. **Run the automated checks again** to ensure nothing is broken after the merge/rebase.

7. **Explain conflict to the user**. If the merge/rebase was complex, write a short summary of what was done and why. Include any trade-offs made, and any follow-up work that may be needed. If conflict is trivial say so and don't add any context.
