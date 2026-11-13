# Input validation harnesses

Ad hoc harnesses used to check the input validation added by the PRs split out
of #9461. They are kept here so the evidence behind those PRs is reproducible;
nothing in CI runs them yet.

Each prints one `PASS`/`FAIL` line per case and exits non-zero if any case
fails, so they work as-is if a workflow is ever added to run them.

## Running them

Two take the script under test as an argument, so they can be pointed at the
patched file or at the version on `main` to show the difference:

```bash
.github/scripts/tests/test-extract-payload.sh "$PWD/.github/scripts/extract-payload.sh"
.github/scripts/tests/test-release-branch.sh  "$PWD/.github/scripts/create-release-branch-and-pr.sh"
```

Two do not, for the reasons below:

```bash
.github/scripts/tests/test-tag-gate.sh after   # or: before
.github/scripts/tests/test-release-event-task.sh
```

| Harness | Covers | Cases |
|---|---|---|
| `test-extract-payload.sh` | `extract-payload.sh` allowlist, both the `workflow_dispatch` and `client_payload` paths | 15 |
| `test-release-branch.sh` | the `git_ref` check in `create-release-branch-and-pr.sh` | 9 |
| `test-tag-gate.sh` | the tag check in `community-operator-pr.yaml`'s *Determine release tag* step | 10 |
| `test-release-event-task.sh` | `validate_field` and the `sed` tag extraction in `tasks/send-github-release-event` | 14 |

## Known limitations

- **`test-tag-gate.sh` and `test-release-event-task.sh` embed a copy of the
  logic** rather than invoking the real source, because that logic lives inline
  in a workflow `run:` block and in a Tekton task `script:` respectively, with
  no file to execute. Those two copies can therefore drift from the originals.
  Extracting that logic into `.github/scripts/` would remove the duplication
  and is the better fix if these are ever wired into CI.
- `test-release-branch.sh` passes a deliberately invalid `dev_version` in every
  case, so an accepted `git_ref` stops at the *next* check instead. Both checks
  run before the script touches `git` or `gh`, so it has no side effects, but it
  proves the `git_ref` check was reached rather than that the script as a whole
  succeeds.
- `list-draft-community-operator-pr.sh` has no harness: it calls `gh` against
  the upstream repository before reaching its validation, so it cannot be run
  locally without credentials and a live repo.

The equivalent check for the buildservice controller is a real Go unit test,
`TestReconcileWebhookConfigApplyError`, which lives with the code and runs in
CI.
