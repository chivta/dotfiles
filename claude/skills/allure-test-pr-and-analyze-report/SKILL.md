---
name: allure-test-pr-and-analyze-report
description: Run autotests on a PR by label, then read the failures out of the resulting Allure report.
disable-model-invocation: true
argument-hint: "PR number (defaults to the current branch's PR)"
---

# Allure: test a PR and analyze the report

Label the PR to trigger the autotest workflow, wait for the bot's result comment, pull the failures out of the Allure report, and explain them against the PR diff.

Run from the repo checkout so `gh` resolves the repo. Written against `amomama/amo_cms`; verify the label names with `gh label list` in any other repo.

## 1. Resolve the PR and pick the label

`gh pr view $ARGUMENTS --json number,headRefName,labels` — no argument means the current branch's PR.

Two labels trigger tests, and they are not interchangeable:

| Label | What it runs |
|---|---|
| `Run autotests` | tests only, against whatever is already deployed to stage |
| `Deploy and test` | builds the PR branch, deploys it to stage, then tests |

`Deploy and test` overwrites the shared stage environment. Ask the user which label to use and name that consequence; never pick it silently.

Adding a label that is already on the PR fires no `labeled` event, so the workflow won't start. If the chosen label is in the PR's current labels, remove it first:

```
gh pr edit <N> --remove-label "<label>"
```

## 2. Label, then wait

Capture the cutoff timestamp before labeling — it separates this run's comment from older ones.

```
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
gh pr edit <N> --add-label "<label>"
```

Wait with a Bash call using `run_in_background: true`, so the notification arrives when the comment lands:

```
until gh api "repos/<owner>/<repo>/issues/<N>/comments?since=$since" \
        --jq '.[] | select(.user.login=="github-actions[bot]") | select(.body|test("allure"))' \
      | grep -q .; do sleep 60; done
```

A stage test run takes about 12 minutes; `Deploy and test` adds the build and deploy on top. If nothing lands within 40 minutes, check `gh run list --branch <headRefName> --limit 5` — a job that fails before the test step posts no comment at all.

## 3. Extract the report URL

The bot comment looks like this:

```
### Build 3982: "<commit message>"
Autotests results for **cms-api-stage-tests** ❤️:
Passed tests: 824; Failed tests: 12; Skipped tests: 49; All tests: 885; Duration: 11.87 min
[Detailed Allure report](https://allure.amomama.xyz/allure/reports/<uuid>/)
```

Match `https://allure\.amomama\.xyz/allure/reports/[0-9a-f-]+/`. Several workflows can each post their own comment, so key on the bolded suite name (`cms-api-stage-tests`) and report every suite that ran.

The comment's "Failed tests" number lumps `failed` and `broken` together and omits `unknown`. Take the real counts from the report.

## 4. Read the report

The host is public — no auth, no token.

```
R=https://allure.amomama.xyz/allure/reports/<uuid>
curl -s "$R/widgets/summary.json" | jq .
curl -s "$R/data/suites.json" -o suites.json
jq -c '[.. | objects | select(.uid and .status and (.children|not))
        | select(.status!="passed" and .status!="skipped")]
       | .[] | {uid,name,status,newFailed,parameters}' suites.json
```

`newFailed: true` marks a test that was passing in the previous run — that flag is the fastest split between regressions the PR caused and failures already sitting on stage.

Then, per uid, the actual error:

```
curl -s "$R/data/test-cases/<uid>.json" | jq '{fullName,status,statusMessage}'
```

`statusMessage` is the assertion ("JSON path data[0].id doesn't match. Expected: <295170> Actual: null"). The same file carries `statusTrace`, `testStage` with per-step detail, and `links`; pull those only for failures the message alone doesn't explain.

`data/suites.csv` holds the same tree with no error messages. Use it only when the user asks for a CSV.

## 5. Report back

Group by cause, not by test — twelve tests tripping on one changed response field is one finding, not twelve. Per group: the assertion, the tests hit, and whether `gh pr diff` explains it.

Account for every non-passing uid. `unknown` and `skipped` counts belong in the summary even when they need no analysis; a test that stopped running is a result too.
