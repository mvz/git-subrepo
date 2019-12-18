#!/usr/bin/env bash

set -e

source test/setup

use Test::More

unset GIT_{AUTHOR,COMMITTER}_{EMAIL,NAME}

clone-foo-and-bar

# Make various changes to the repos for testing subrepo push:
(
  # In the main repo:
  cd $OWNER/foo

  # Clone the subrepo into a subdir
  git subrepo clone ../../../$UPSTREAM/bar

  # Make a series of commits:
  git branch flub
  git branch flab
  git co flub
  add-new-files bar/FooBar
  modify-files bar/FooBar
  git co flab
  add-new-files ./FooBar
  modify-files ./FooBar
  git checkout master
  git merge flab --no-ff -m "Merge branch without subrepo changes"
  git merge flub --no-ff -m "Merge branch with subrepo changes"
  modify-files ./FooBar bar/FooBar
) &> /dev/null || die

(
  cd $OWNER/bar
  add-new-files bargy
  git push
) &> /dev/null || die

# Do the subrepo push and test the output:
{
  message="$(
    cd $OWNER/foo
    git config user.name 'PushUser'
    git config user.email 'push@push'
    git subrepo pull --quiet bar
    git subrepo push bar
  )"

  # Test the output:
  is "$message" \
    "Subrepo 'bar' pushed to '../../../tmp/upstream/bar' (master)." \
    'push message is correct'
}

(
  cd $OWNER/bar
  git pull
) &> /dev/null || die

{
  pullCommit="$(
    cd $OWNER/bar
    git log HEAD -1 --pretty='format:%an %ae %cn %ce'
  )"

  is "$pullCommit" \
    "PushUser push@push PushUser push@push" \
    "Pull commit has PushUser as both author and committer"
}

{
  subrepoCommit="$(
    cd $OWNER/bar
    git log HEAD^ -1 --pretty='format:%an %ae %cn %ce'
  )"

  is "$subrepoCommit" \
    "FooUser foo@foo PushUser push@push" \
    "Subrepo commits has FooUser as author but PushUser as committer"
}

# Check that all commits arrived in subrepo
test-commit-count "$OWNER/bar" HEAD 7

done_testing

teardown
