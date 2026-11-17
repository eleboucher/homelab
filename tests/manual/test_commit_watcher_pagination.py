import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

import httpx


SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "kubernetes/apps/ai/hermes/app/skills/homelab-commit-watcher/fetch_k8s_repos.py"
)
SPEC = importlib.util.spec_from_file_location("watcher", SCRIPT)
watcher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(watcher)
NOW = datetime(2026, 11, 17, 10, tzinfo=timezone.utc)
REAL_CLIENT = httpx.Client


def commit(number, *, hours=2, bot=False, **overrides):
    return {
        "oid": f"{number:040x}",
        "messageHeadline": "feat(network): add a service",
        "messageBody": "",
        "committedDate": (NOW - timedelta(hours=hours)).isoformat(),
        "additions": 1,
        "deletions": 0,
        "changedFilesIfAvailable": 1,
        "author": {"user": {"login": "renovate[bot]" if bot else "operator"}},
        **overrides,
    }


def history(commits, cursor=None):
    return {
        "nodes": commits,
        "pageInfo": {"hasNextPage": cursor is not None, "endCursor": cursor},
    }


def repository(name, commits, cursor=None):
    return {
        "nameWithOwner": f"peer/{name}",
        "defaultBranchRef": {
            "name": "main",
            "target": {"id": f"tip-{name}", "history": history(commits, cursor)},
        },
    }


class PaginationTests(unittest.TestCase):
    def run_watcher(self, initial, pages=None, error=None):
        requests = []
        repos = [
            {"owner": {"login": "peer"}, "name": f"repo{i}"}
            for i in range(len(initial))
        ]

        def respond(request):
            payload = json.loads(request.content)
            requests.append(payload)
            variables = payload["variables"]
            if "id" not in variables:
                return httpx.Response(200, json={"data": initial})
            if error and pages is None:
                return httpx.Response(200, json={"errors": [{"message": "unavailable"}]})
            page = pages[(variables["id"], variables["cursor"])]
            return httpx.Response(200, json={"data": {"node": {"history": page}}})

        def client(**kwargs):
            kwargs["transport"] = httpx.MockTransport(respond)
            return REAL_CLIENT(**kwargs)

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            with (
                patch.object(watcher, "gh_token", return_value="test-token"),
                patch.object(watcher, "fetch_repos", return_value=repos),
                patch.object(watcher.httpx, "Client", side_effect=client),
                patch.object(watcher, "OUTPUT_DIR", output),
                patch.object(watcher.Path, "home", return_value=output),
                patch.object(watcher, "datetime", wraps=datetime) as clock,
                patch.dict(watcher.os.environ, {"SUMMARY_LLM_URL": ""}),
                redirect_stderr(io.StringIO()),
            ):
                clock.now.return_value = NOW
                if error:
                    with self.assertRaisesRegex(RuntimeError, error):
                        watcher.main()
                    self.assertFalse(list(output.glob("*.md")))
                    return
                watcher.main()
            feed = (output / "feed-2026-11-17.md").read_text()
            self.assertEqual(feed, (output / "commit-watcher-2026-11-17.md").read_text())
        return feed, requests

    def test_all_pages_reach_feed_before_filtering(self):
        older = commit(201, hours=72)
        initial = {
            "r0": repository("busy", [commit(i, bot=True) for i in range(100)], "page2"),
            "r1": repository("quiet", [commit(300)]),
        }
        pages = {
            ("tip-busy", "page2"): history(
                [commit(i) for i in range(100, 200)], "page3"
            ),
            ("tip-busy", "page3"): history(
                [
                    older,
                    commit(202, messageHeadline="Merge pull request #1"),
                    commit(203, messageBody="Co-authored-by: Claude <bot@anthropic.com>"),
                    commit(204, additions=0, changedFilesIfAvailable=0),
                ]
            ),
        }
        feed, requests = self.run_watcher(initial, pages)
        bullets = [line for line in feed.splitlines() if line.startswith("- ")]
        self.assertEqual(102, len(bullets))
        for number in [*range(100, 200), 201, 300]:
            self.assertEqual(1, feed.count(f"/commit/{number:040x}"))
        for number in [0, 202, 203, 204]:
            self.assertNotIn(f"/commit/{number:040x}", feed)
        self.assertTrue(bullets[0].startswith("- [24h] "))
        old_bullet = next(line for line in bullets if older["oid"] in line)
        self.assertFalse(old_bullet.startswith("- [24h] "))
        self.assertEqual(
            ["page2", "page3"],
            [request["variables"]["cursor"] for request in requests[1:]],
        )
        for request in requests:
            self.assertEqual("2026-11-10T10:00:00+00:00", request["variables"]["since"])
        for request in requests[1:]:
            self.assertEqual("tip-busy", request["variables"]["id"])
            self.assertIn("after: $cursor", request["query"])
            self.assertNotIn("defaultBranchRef", request["query"])

    def test_single_page_boundaries_and_missing_branches(self):
        for count in (0, 1, 100):
            with self.subTest(count=count):
                feed, requests = self.run_watcher(
                    {
                        "r0": repository("quiet", [commit(i) for i in range(count)]),
                        "r1": None,
                        "r2": {"defaultBranchRef": None},
                        "r3": {"defaultBranchRef": {"target": None}},
                    }
                )
                self.assertEqual(1, len(requests))
                self.assertEqual(count, feed.count("/commit/"))

    def test_later_page_failure_does_not_publish_partial_feed(self):
        self.run_watcher(
            {"r0": repository("busy", [commit(1)], "page2")}, error="unavailable"
        )

    def test_each_repository_uses_its_own_cursor_and_tip(self):
        feed, requests = self.run_watcher(
            {
                "r0": repository("first", [commit(1)], "first-page2"),
                "r1": repository("second", [commit(2)], "second-page2"),
            },
            {
                ("tip-first", "first-page2"): history([commit(3)]),
                ("tip-second", "second-page2"): history([commit(4)]),
            },
        )
        self.assertEqual(4, feed.count("/commit/"))
        self.assertEqual(3, len(requests))
        self.assertIn(f"peer/first/commit/{3:040x}", feed)
        self.assertIn(f"peer/second/commit/{4:040x}", feed)

    def test_missing_or_repeated_cursor_does_not_loop_or_publish(self):
        for cursor in (None, "page2"):
            with self.subTest(cursor=cursor):
                initial = repository("busy", [commit(1)], cursor)
                initial["defaultBranchRef"]["target"]["history"]["pageInfo"][
                    "hasNextPage"
                ] = True
                self.run_watcher(
                    {"r0": initial},
                    {("tip-busy", "page2"): history([commit(2)], "page2")},
                    error="pagination did not advance",
                )


if __name__ == "__main__":
    unittest.main()
