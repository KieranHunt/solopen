# shellcheck shell=bash

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
