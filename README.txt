
Based off scripts in jobs/APM directory

all permissions token for uid: foreman
 export _BITBUCKETTOKEN_=MTE0NzYyNDIwMzEyOrzD51y6xhSzM7VSn9X6xz/Xy6tG

==========
 Strategy
==========

Allow only the generic read-only access that is provided by belonging to group 'stash-users'

- Except for repos in whitelist

- Create READ-ONLY branch permission on every repository with wildcard pattern
{
  "groups" : [],
  "accessKeys" : [],
  "matcher" : {
      "active" : true,
      "type" : {
        "name" : "Pattern",
        "id" : "PATTERN"
      },
      "id" : "*",
      "displayId" : "*"
  },
  "id" : 3308,
  "type" : "read-only",
  "scope" : {
      "resourceId" : 4238,
      "type" : "REPOSITORY"
  },
  "users" : []
}
]

- Remove all user/groupo exceptions on branch permissions

- Remove all user/group specific permissions on both project and repo level


