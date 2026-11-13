#!/usr/bin/env bash
# Exercise the tag check exactly as community-operator-pr.yaml's "Determine
# release tag" step runs it, with the inputs bound to env vars as the workflow
# now binds them.
set -uo pipefail

MODE="$1"   # "after" = with the new check, "before" = main's behaviour
pass=0
fail=0

run_step() {
  # Mirrors the run: block. EVENT_NAME / RELEASE_TAG_EVENT / RELEASE_TAG_INPUT
  # arrive via env, as the workflow sets them.
  local out rc
  out=$( {
    set -uo pipefail
    if [ "${EVENT_NAME}" == "release" ]; then
      RELEASE_TAG="${RELEASE_TAG_EVENT}"
    else
      RELEASE_TAG="${RELEASE_TAG_INPUT}"
    fi
    if [[ "$MODE" == "after" ]]; then
      if [[ ! "${RELEASE_TAG}" =~ ^[A-Za-z0-9][A-Za-z0-9._/+-]*$ ]]; then
        echo "Error: release tag contains disallowed characters: '${RELEASE_TAG}'" >&2
        exit 1
      fi
    fi
    echo "tag=${RELEASE_TAG}"
  } 2>&1 )
  rc=$?
  printf '%s' "$out"
  return "$rc"
}

check() {
  local label="$1" want="$2" event="$3" tag="$4"
  local out rc got
  if [[ "$event" == "release" ]]; then
    out=$(EVENT_NAME=release RELEASE_TAG_EVENT="$tag" RELEASE_TAG_INPUT="" run_step); rc=$?
  else
    out=$(EVENT_NAME=workflow_dispatch RELEASE_TAG_EVENT="" RELEASE_TAG_INPUT="$tag" run_step); rc=$?
  fi
  [[ $rc -eq 0 ]] && got="accepted" || got="rejected"
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-36s -> %s\n' "$label" "$got"; pass=$((pass + 1))
  else
    printf '  FAIL  %-36s -> %s (wanted %s)\n' "$label" "$got" "$want"; fail=$((fail + 1))
  fi
}

echo "release event (github.event.release.tag_name):"
check "v0.1.5"                   accepted release "v0.1.5"
check "v1.2.3-rc.1"              accepted release "v1.2.3-rc.1"
check "command substitution"     rejected release 'v0.1.5$(id)'
check "semicolon chain"          rejected release "v0.1.5; id"
check "backticks"                rejected release 'v`id`'
check "leading dash"             rejected release "-oProxyCommand=id"
check "newline into GITHUB_OUTPUT" rejected release $'v0.1.5\ntag=evil'

echo "workflow_dispatch (inputs.release_tag):"
check "v0.1.5"                   accepted dispatch "v0.1.5"
check "pipe"                     rejected dispatch "v0.1.5 | id"
check "quote break-out"          rejected dispatch 'v0.1.5" ; id ; "'

echo
echo "passed=$pass failed=$fail"
[[ $fail -eq 0 ]]
