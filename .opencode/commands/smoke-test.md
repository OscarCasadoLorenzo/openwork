---
description: Run the full multiagent smoke test suite — verifies orchestrator context, delegation routing, JSON contract compliance, and tool isolation across fresh isolated sessions
agent: build
---

Run the smoke test suite using isolated headless sessions (zero history contamination):

!`bash scripts/smoke-test.sh`

After the tests complete:

1. Report a structured summary of each test step and its result (PASS / FAIL / SKIP)
2. For any FAILED test, explain:
   - What the test was verifying
   - What the likely root cause is
   - The exact fix needed in which file
3. For any SKIPPED test, explain what needs to be configured to enable it
4. If all tests pass, confirm the multiagent system is working correctly end-to-end

Important: the smoke test uses `opencode run` which starts completely fresh sessions with no history from this conversation. Results are based solely on the files on disk.
