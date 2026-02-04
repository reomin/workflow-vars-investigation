#!/usr/bin/env bash
set -euo pipefail


pull_request_title="${1-}"
merge_sha="${2-}"

printf 'wait-archive-creation.sh received args:\n'
printf '  pull_request_title: %s\n' "$pull_request_title"
printf '  merge_sha: %s\n' "$merge_sha"
