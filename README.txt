
Based off scripts in jobs/APM directory

All repo permissions token for uid: foreman

 export _BITBUCKETTOKEN_=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx (see Keepassxc db)

Actual uid login with full SYSADMIN permissions necessary to manage 'all-users' list for
whitelist _ALL_' keyword.

 export _BITBUCKETUSER_=foreman
 export _BITBUCKETPWD_=<pwd>

  ==========
 Strategy
==========

Allow only the generic read-only access that is provided by belonging to group 'stash-users'

- Create READ-ONLY branch permission on every repository with wildcard pattern

- Remove all user/groupo exceptions on branch permissions

- Remove all user/group specific permissions on both project and repo level

- Except for definition in whitelist. Add those as exemptions


Files that are part of the tool
===============================

- bitbucket_permissions.sh

Fetches existing permissions settings from all projects and repos in Bitbucket.
With option `-p <project name>` fetch is only from that given project

- repo_permission_groups.txt

Contents of all existing permission settinsg fetched with `bitbucket_permissions.sh`

- bitbucket_permissions.pl
  - DeletePerm.pm
  - PostBranchRestriction.pm
  - WhiteList.pm
  - whitelist.yaml

Reads the contents from 'repo_permission_groups.txt' and prints the API `curl` commads that will
be executed to remove existing permission settinsg and create restrict branch restrictions
everywhere, except in locations defined in `whitelist.yaml`.


Examples
========

Fetch all existing permissions in project 'QA'
./bitbucket_permissions.sh -p QA > repo_permission_groups.test-QA.txt

Check what will be applied
./bitbucket_permissions.pl | less

Commit the changes and see the responses
/bitbucket_permissions.pl -c | less

Test whitelist
./tryit_whitelist.pl
