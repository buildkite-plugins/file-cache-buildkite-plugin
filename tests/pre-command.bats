#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="cache/npm"
}

@test "restores the configured path" {
  stub buildkite-agent \
    "cache restore --path cache/npm : echo restored"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial "Restoring file cache"
  assert_output --partial "restored"

  unstub buildkite-agent
}

@test "fails when restore fails" {
  stub buildkite-agent \
    "cache restore --path cache/npm : exit 42"

  run "$PWD/hooks/pre-command"

  assert_failure 42

  unstub buildkite-agent
}
