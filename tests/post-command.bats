#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  export BUILDKITE_COMMAND_EXIT_STATUS="0"
  export BUILDKITE_COMMIT="0123456789abcdef"
  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="$BATS_TEST_TMPDIR/cache"
  export TMPDIR="$BATS_TEST_TMPDIR"
}

@test "saves the generated cache definition after a successful command" {
  mkdir -p "$BUILDKITE_PLUGIN_FILE_CACHE_PATH"
  stub buildkite-agent \
    "cache save --name file_cache --cache-config-file \\* : cp \$6 '$BATS_TEST_TMPDIR/rendered.yml'; echo saved"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Saving file cache"
  assert_output --partial "saved"
  [[ -f "$BATS_TEST_TMPDIR/rendered.yml" ]]

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
    "cache save --name file_cache --cache-config-file \\* : exit 42"

  run "$PWD/hooks/post-command"

  assert_success
  assert_output --partial "Failed to save the file cache"

  unstub buildkite-agent
}

@test "removes the temporary definition after saving" {
  mkdir -p "$BUILDKITE_PLUGIN_FILE_CACHE_PATH"
  stub buildkite-agent \
    "cache save --name file_cache --cache-config-file \\* : echo \$6 > '$BATS_TEST_TMPDIR/config-path'"

  run "$PWD/hooks/post-command"

  assert_success
  CONFIG_PATH="$(cat "$BATS_TEST_TMPDIR/config-path")"
  [[ ! -e "$CONFIG_PATH" ]]

  unstub buildkite-agent
}
