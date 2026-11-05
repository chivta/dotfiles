#!/usr/bin/env python3
import json
import subprocess
from collections import defaultdict
from datetime import datetime, time

from sessions import local_time, previous_working_day

ORG = "amomama"
SEARCHES = ("author:@me", "reviewed-by:@me", "review-requested:@me")
MAX_PRS = 50
MAX_EVENTS = 100
QUERY = """
query($q: String!, $since: DateTime!, $prs: Int!, $events: Int!) {
  viewer { login }
  search(query: $q, type: ISSUE, first: $prs) {
    nodes {
      ... on PullRequest {
        number title url createdAt baseRefName headRefName
        author { login }
        repository { nameWithOwner }
        timelineItems(since: $since, first: $events, itemTypes: [
          PULL_REQUEST_REVIEW, MERGED_EVENT, CLOSED_EVENT, READY_FOR_REVIEW_EVENT, REVIEW_REQUESTED_EVENT
        ]) {
          nodes {
            __typename
            ... on PullRequestReview { state submittedAt author { ...person } }
            ... on MergedEvent { createdAt mergeRefName actor { ...person } }
            ... on ClosedEvent { createdAt actor { ...person } }
            ... on ReadyForReviewEvent { createdAt actor { ...person } }
            ... on ReviewRequestedEvent { createdAt actor { ...person } requestedReviewer { ...person } }
          }
        }
      }
    }
  }
}
fragment person on Actor { login ... on User { name } }
"""


def search(query, since):
    output = subprocess.run(
        ["gh", "api", "graphql", "-f", f"query={QUERY}", "-f", f"q={query}", "-f", f"since={since}",
         "-F", f"prs={MAX_PRS}", "-F", f"events={MAX_EVENTS}"],
        capture_output=True, text=True, check=True,
    ).stdout
    data = json.loads(output)["data"]
    return data["viewer"]["login"], data["search"]["nodes"]


def person(actor, me):
    if not actor:
        return "?"
    if actor["login"] == me:
        return "me"
    return f"{actor['name']} ({actor['login']})" if actor.get("name") else actor["login"]


def pr_events(pr, start, me):
    if local_time(pr["createdAt"]) >= start:
        yield pr["createdAt"], f"opened by {person(pr['author'], me)}"
    items = pr["timelineItems"]["nodes"]
    merged = any(item["__typename"] == "MergedEvent" for item in items)
    for item in items:
        kind = item["__typename"]
        if kind == "PullRequestReview" and item.get("submittedAt"):
            if item["author"] and item["author"]["login"] != pr["author"]["login"]:
                yield item["submittedAt"], f"review {item['state'].lower()} by {person(item['author'], me)}"
        elif kind == "MergedEvent":
            yield item["createdAt"], f"merged into {item['mergeRefName']} by {person(item['actor'], me)}"
        elif kind == "ClosedEvent" and not merged:
            yield item["createdAt"], f"closed without merge by {person(item['actor'], me)}"
        elif kind == "ReadyForReviewEvent":
            yield item["createdAt"], f"marked ready for review by {person(item['actor'], me)}"
        elif kind == "ReviewRequestedEvent":
            yield item["createdAt"], f"review requested from {person(item['requestedReviewer'], me)}"


def main():
    now = datetime.now().astimezone()
    start = datetime.combine(previous_working_day(now.date()), time.min).astimezone()
    prs = {}
    me = None
    for qualifier in SEARCHES:
        me, nodes = search(f"org:{ORG} is:pr {qualifier} updated:>={start:%Y-%m-%d}", start.isoformat())
        prs.update((pr["url"], pr) for pr in nodes if pr)

    days = defaultdict(lambda: defaultdict(list))
    for pr in prs.values():
        for timestamp, text in pr_events(pr, start, me):
            moment = local_time(timestamp)
            days[moment.date()][pr["url"]].append((moment, text))

    print(f"# GitHub PRs in {ORG} {start:%Y-%m-%d %H:%M} → {now:%Y-%m-%d %H:%M}")
    for day in sorted(days):
        print(f"\n## {day:%Y-%m-%d %A}")
        for url, events in days[day].items():
            pr = prs[url]
            print(f"\n### {pr['repository']['nameWithOwner']}#{pr['number']} · {pr['headRefName']} → "
                  f"{pr['baseRefName']} · {pr['title']} · author {person(pr['author'], me)}")
            for moment, text in sorted(events):
                print(f"- {moment:%H:%M} {text}")


if __name__ == "__main__":
    main()
