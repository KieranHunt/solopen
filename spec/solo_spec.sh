# shellcheck shell=bash

solo_root() { cd "$SHELLSPEC_PROJECT_ROOT" || return 1; "$@"; }

setup_stub_env() {
  export PATH="$SHELLSPEC_PROJECT_ROOT/spec/support/bin:$PATH"
  export PROJECTS_JSON="$SHELLSPEC_TMPBASE/projects.json"
  export OPEN_LOG="$SHELLSPEC_TMPBASE/open.log"
  export CLI_LOG="$SHELLSPEC_TMPBASE/cli.log"
  workspace="$(mktemp -d "$SHELLSPEC_TMPBASE/workspace.XXXXXX")"
  workspace="$(realpath "$workspace")"
  mkdir -p "$workspace/vine" "$workspace/vine/sub" "$workspace/unregistered"
  ln -s "$workspace/vine" "$workspace/vine-link"
  cat >"$PROJECTS_JSON" <<EOF
{"ok":true,"command":"projects list","projects":[
  {"id":6,"name":"vine","path":"$workspace/vine","isLinkedCheckout":false,"primaryProjectId":null},
  {"id":9,"name":"slo","path":"$workspace/slo","isLinkedCheckout":false,"primaryProjectId":null}
]}
EOF
}

reset_logs() { : >"$OPEN_LOG" && : >"$CLI_LOG"; }

Describe 'argument validation'
  It 'prints usage and fails on bare invocation'
    When run command ./solo
    The status should equal 1
    The stderr should include 'Usage:'
  End

  It 'prints usage and fails on -h'
    When run command ./solo -h
    The status should equal 1
    The stderr should include 'Usage:'
  End

  It 'prints usage and fails on --help'
    When run command ./solo --help
    The status should equal 1
    The stderr should include 'Usage:'
  End

  It 'rejects a nonexistent path'
    When run command ./solo /path/that/does/not/exist
    The status should equal 1
    The stderr should include 'no such directory: /path/that/does/not/exist'
    The stderr should include 'Usage:'
  End

  Describe 'with an existing file'
    setup() { afile="$SHELLSPEC_TMPBASE/afile" && touch "$afile"; }
    BeforeAll 'setup'

    It 'rejects a file argument'
      When run command ./solo "$afile"
      The status should equal 1
      The stderr should include "not a directory: $afile"
      The stderr should include 'Usage:'
    End
  End

  It 'rejects an unknown option'
    When run command ./solo --bogus
    The status should equal 1
    The stderr should include 'unknown option: --bogus'
  End

  It 'rejects extra directory arguments'
    When run command ./solo /tmp /tmp
    The status should equal 1
    The stderr should include 'extra argument'
  End
End

Describe 'exact-match open'
  BeforeAll 'setup_stub_env'
  BeforeEach 'reset_logs'

  run_solo_from() {
    cd "$1" || return 1
    shift
    "$SHELLSPEC_PROJECT_ROOT/solo" "$@"
  }

  It 'opens a project whose path matches exactly'
    When run command ./solo "$workspace/vine"
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

  It 'opens the project for . from inside the directory'
    When run run_solo_from "$workspace/vine" .
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

  It 'resolves symlinks before matching'
    When run command ./solo "$workspace/vine-link"
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

  It 'reports when no project matches'
    When run command ./solo "$workspace/unregistered"
    The status should equal 1
    The stderr should include "no Solo project found for $workspace/unregistered"
    The contents of file "$OPEN_LOG" should equal ''
  End
End
