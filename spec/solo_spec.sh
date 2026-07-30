# shellcheck shell=bash

setup_stub_env() {
  export PATH="$SHELLSPEC_PROJECT_ROOT/spec/support/bin:$PATH"
  export PROJECTS_JSON="$SHELLSPEC_TMPBASE/projects.json"
  export OPEN_LOG="$SHELLSPEC_TMPBASE/open.log"
  export CLI_LOG="$SHELLSPEC_TMPBASE/cli.log"
  workspace="$(mktemp -d "$SHELLSPEC_TMPBASE/workspace.XXXXXX")"
  workspace="$(realpath "$workspace")"
  mkdir -p "$workspace/vine" "$workspace/vine/sub" "$workspace/vine-two" \
    "$workspace/unregistered" "$workspace/parent/child/grand"
  ln -s "$workspace/vine" "$workspace/vine-link"
  cat >"$PROJECTS_JSON" <<EOF
{"ok":true,"command":"projects list","data":{"hasMore":false,"projects":[
  {"id":6,"name":"vine","displayName":null,"path":"$workspace/vine"},
  {"id":9,"name":"slo","displayName":null,"path":"$workspace/slo"},
  {"id":20,"name":"parent","displayName":null,"path":"$workspace/parent"},
  {"id":21,"name":"child","displayName":null,"path":"$workspace/parent/child"},
  {"id":7,"name":"~","displayName":null,"path":"$HOME"}
]}}
EOF
}

reset_logs() { : >"$OPEN_LOG" && : >"$CLI_LOG" && rm -f "$SHELLSPEC_TMPBASE/launched"; }

Describe 'argument validation'
  It 'prints usage and fails on bare invocation'
    When run script ./solopen
    The status should equal 1
    The stderr should include 'Usage:'
  End

  It 'prints usage and fails on -h'
    When run script ./solopen -h
    The status should equal 1
    The stderr should include 'Usage:'
  End

  It 'prints usage and fails on --help'
    When run script ./solopen --help
    The status should equal 1
    The stderr should include 'Usage:'
  End

  It 'rejects a nonexistent path'
    When run script ./solopen /path/that/does/not/exist
    The status should equal 1
    The stderr should include 'no such directory: /path/that/does/not/exist'
    The stderr should include 'Usage:'
  End

  Describe 'with an existing file'
    setup() { afile="$SHELLSPEC_TMPBASE/afile" && touch "$afile"; }
    BeforeAll 'setup'

    It 'rejects a file argument'
      When run script ./solopen "$afile"
      The status should equal 1
      The stderr should include "not a directory: $afile"
      The stderr should include 'Usage:'
    End
  End

  It 'rejects an unknown option'
    When run script ./solopen --bogus
    The status should equal 1
    The stderr should include 'unknown option: --bogus'
  End

  It 'rejects extra directory arguments'
    When run script ./solopen /tmp /tmp
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
    "$SHELLSPEC_PROJECT_ROOT/solopen" "$@"
  }

  It 'opens a project whose path matches exactly'
    When run script ./solopen "$workspace/vine"
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
    When run script ./solopen "$workspace/vine-link"
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

  It 'resolves relative paths before matching'
    When run run_solo_from "$workspace/unregistered" ../vine
    The status should equal 0
    The output should equal 'opened vine (id 6)'
  End

  It 'opens exactly one project when registered paths duplicate'
    printf '{"ok":true,"data":{"hasMore":false,"projects":[{"id":6,"name":"vine","path":"%s"},{"id":66,"name":"vine-checkout","path":"%s"}]}}\n' \
      "$workspace/vine" "$workspace/vine" >"$SHELLSPEC_TMPBASE/dup.json"
    export PROJECTS_JSON="$SHELLSPEC_TMPBASE/dup.json"
    When run script ./solopen "$workspace/vine"
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

End

Describe 'deepest-ancestor resolution'
  BeforeAll 'setup_stub_env'
  BeforeEach 'reset_logs'

  It 'opens the ancestor project of an unregistered subdirectory'
    When run script ./solopen "$workspace/vine/sub"
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

  It 'prefers the deepest ancestor when projects nest'
    When run script ./solopen "$workspace/parent/child/grand"
    The status should equal 0
    The output should equal 'opened child (id 21)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/21'
  End

  It 'prefers an exact match over a shallower ancestor'
    When run script ./solopen "$workspace/parent/child"
    The status should equal 0
    The output should equal 'opened child (id 21)'
  End

  It 'never ancestor-matches the ignored home project, creating instead'
    When run script ./solopen "$HOME/Projects"
    The status should equal 0
    The line 1 of output should equal "created Projects (id 13) at $HOME/Projects"
    The contents of file "$OPEN_LOG" should equal 'solo://proj/13'
  End

  It 'still opens the home project via exact match'
    When run script ./solopen "$HOME"
    The status should equal 0
    The output should equal 'opened ~ (id 7)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/7'
  End

  It 'does not treat a sibling with a shared prefix as an ancestor, creating instead'
    When run script ./solopen "$workspace/vine-two"
    The status should equal 0
    The line 1 of output should equal "created vine-two (id 13) at $workspace/vine-two"
    The contents of file "$OPEN_LOG" should equal 'solo://proj/13'
  End
End

Describe 'create-on-miss'
  BeforeAll 'setup_stub_env'
  BeforeEach 'reset_logs'

  It 'creates and opens a project for an unregistered directory'
    When run script ./solopen "$workspace/unregistered"
    The status should equal 0
    The line 1 of output should equal "created unregistered (id 13) at $workspace/unregistered"
    The line 2 of output should equal 'opened unregistered (id 13)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/13'
    The contents of file "$CLI_LOG" should include "projects create unregistered $workspace/unregistered --json"
  End

  It 'uses the literal directory, not the enclosing git root'
    mkdir -p "$workspace/unregistered/.git" "$workspace/unregistered/subdir"
    When run script ./solopen "$workspace/unregistered/subdir"
    The status should equal 0
    The line 1 of output should equal "created subdir (id 13) at $workspace/unregistered/subdir"
    The contents of file "$CLI_LOG" should include "projects create subdir $workspace/unregistered/subdir --json"
  End

  It 'refuses to create over registered descendants and lists them'
    When run script ./solopen "$workspace"
    The status should equal 1
    The stderr should include 'registered projects exist beneath'
    The stderr should include "vine (id 6) at $workspace/vine"
    The stderr should include "child (id 21) at $workspace/parent/child"
    The stderr should include '--force'
    The contents of file "$OPEN_LOG" should equal ''
    The contents of file "$CLI_LOG" should not include 'projects create'
  End

  It 'creates despite descendants with --force after the path'
    When run script ./solopen "$workspace" --force
    The status should equal 0
    The line 1 of output should equal "created $(basename "$workspace") (id 13) at $workspace"
    The contents of file "$OPEN_LOG" should equal 'solo://proj/13'
  End

  It 'creates despite descendants with --force before the path'
    When run script ./solopen --force "$workspace"
    The status should equal 0
    The line 1 of output should equal "created $(basename "$workspace") (id 13) at $workspace"
  End
End

Describe 'app lifecycle'
  BeforeAll 'setup_stub_env'
  BeforeEach 'reset_logs'

  It 'does not launch the app when the API is already reachable'
    When run script ./solopen "$workspace/vine"
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

  It 'launches the app and waits when nothing is running'
    export STATUS_MODE=after-launch PS_SOLO_RUNNING=0
    export LAUNCH_MARKER="$SHELLSPEC_TMPBASE/launched"
    When run script ./solopen "$workspace/vine"
    The status should equal 0
    The output should equal 'opened vine (id 6)'
    The line 1 of contents of file "$OPEN_LOG" should equal '-a Solo'
    The line 2 of contents of file "$OPEN_LOG" should equal 'solo://proj/6'
  End

  It 'explains how to enable CLI access when the app runs but the API is unreachable'
    export STATUS_MODE=down PS_SOLO_RUNNING=1
    When run script ./solopen "$workspace/vine"
    The status should equal 1
    The stderr should include 'local CLI access'
    The contents of file "$OPEN_LOG" should equal ''
  End

  It 'gives up with a clear error when the launched app never answers'
    export STATUS_MODE=down PS_SOLO_RUNNING=0 SOLO_LAUNCH_TIMEOUT=1
    When run script ./solopen "$workspace/vine"
    The status should equal 1
    The stderr should include 'timed out'
    The contents of file "$OPEN_LOG" should equal '-a Solo'
  End
End
