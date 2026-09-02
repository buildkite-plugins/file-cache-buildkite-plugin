#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="~/.npm"
  export BUILDKITE_COMMIT="0123456789abcdef"
  export TMPDIR="$BATS_TEST_TMPDIR"
}

@test "restores the generated cache definition" {
  stub buildkite-agent \
    "cache restore --name file_cache --cache-config-file \\* : cp \$6 '$BATS_TEST_TMPDIR/rendered.yml'; echo restored"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial "Restoring file cache"
  assert_output --partial "restored"
  [[ -f "$BATS_TEST_TMPDIR/rendered.yml" ]]

  run cat "$BATS_TEST_TMPDIR/rendered.yml"
  assert_line '      - env: BUILDKITE_PLUGIN_FILE_CACHE_GENERATION'
  assert_line "      - '~/.npm'"

  unstub buildkite-agent
}

@test "fails when restore fails and removes the temporary definition" {
  stub buildkite-agent \
    "cache restore --name file_cache --cache-config-file \\* : echo \$6 > '$BATS_TEST_TMPDIR/config-path'; exit 42"

  run "$PWD/hooks/pre-command"

  assert_failure 42
  [[ -f "$BATS_TEST_TMPDIR/config-path" ]]
  CONFIG_PATH="$(cat "$BATS_TEST_TMPDIR/config-path")"
  [[ ! -e "$CONFIG_PATH" ]]

  unstub buildkite-agent
}
