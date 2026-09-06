#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  export BUILDKITE_COMMAND_EXIT_STATUS="0"
  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="$BATS_TEST_TMPDIR/cache"
}

@test "saves the configured path after a successful command" {
  mkdir -p "$BUILDKITE_PLUGIN_FILE_CACHE_PATH"
  stub buildkite-agent \
    "cache save --path $BUILDKITE_PLUGIN_FILE_CACHE_PATH : echo saved"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Saving file cache"
  assert_output --partial "saved"

  unstub buildkite-agent
}

@test "skips saving after a failed command" {
  export BUILDKITE_COMMAND_EXIT_STATUS="7"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "command exited with status 7"
}

@test "skips saving when the configured path does not exist" {
  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "path does not exist; skipping save"
}

@test "warns but succeeds when save fails" {
  mkdir -p "$BUILDKITE_PLUGIN_FILE_CACHE_PATH"
  stub buildkite-agent \
    "cache save --path $BUILDKITE_PLUGIN_FILE_CACHE_PATH : exit 42"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Failed to save the file cache"

  unstub buildkite-agent
}
