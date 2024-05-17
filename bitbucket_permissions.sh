#!/usr/bin/env bash

# Creates a dump with select data from Bitbucket.
#
# Set the _BITBUCKETTOKEN_ environment variable to contain your personal Bitbucket access token.
# export _BITBUCKETTOKEN_=...
#
# API documentation
# https://docs.atlassian.com/bitbucket-server/rest/6.2.0/bitbucket-rest.html
#

levels=("groups" "users")

for project in $( curl \
                    --silent \
                    --insecure \
                    --request GET \
                    --url 'https://buildtools.bisnode.net/stash/rest/api/latest/projects?start=0&limit=200' \
                    --header "Authorization: Bearer $_BITBUCKETTOKEN_"  \
                    --header 'Accept: application/json' \
                  | jq '.values | .[] | .key' \
                  | perl -nle 's/^"|"$//g; print'
                ); do

  echo ":Project:" $project "{"
  for level in ${levels[@]}; do
    export _LEVEL_=$level && \
    curl \
      --silent \
      --insecure \
      --request GET \
      --url "https://buildtools.bisnode.net/stash/rest/api/latest/projects/${project}/permissions/${level}" \
      --header "Authorization: Bearer $_BITBUCKETTOKEN_"  \
      --header 'Accept:application/json ' \
    | perl -nle '
        use JSON::PP;
        $json = decode_json($_);
        if ($json->{size} > 0) {
          $pretty_json = JSON::PP->new->utf8->pretty->encode($json->{values});
          $pretty_json =~ s/^\[/:: PROJECT PERMISSIONS ($ENV{_LEVEL_}) :: {[/;
          $pretty_json =~ s/\]$/]}/s;
          $pretty_json =~ s/([^\n]+)/\t$1/smg;
          print $pretty_json;
        }
      '
  done

  for repo in $( curl \
                    --silent \
                    --insecure \
                    --request GET \
                    --url "https://buildtools.bisnode.net/stash/rest/api/latest/projects/$project/repos?start=0&limit=1000" \
                    --header "Authorization: Bearer $_BITBUCKETTOKEN_"  \
                    --header 'Accept: application/json' \
                  | jq '.values | .[] | .slug' \
                  | perl -nle 's/^"|"$//g; print'
              ); do

    echo -e "\t::Repo::" $repo "{"
    for level in ${levels[@]}; do
      export _LEVEL_=$level && \
      curl \
        --silent \
        --insecure \
        --request GET \
        --url "https://buildtools.bisnode.net/stash/rest/api/latest/projects/${project}/repos/${repo}/permissions/${level}" \
        --header "Authorization: Bearer $_BITBUCKETTOKEN_"  \
        --header 'Accept:application/json ' \
      | perl -nle '
          use JSON::PP;
          $json = decode_json($_);
          if ($json->{size} > 0) {
            $pretty_json = JSON::PP->new->utf8->pretty->encode($json->{values});
            $pretty_json =~ s/^\[/::: REPO PERMISSIONS ($ENV{_LEVEL_}) ::: {[/;
            $pretty_json =~ s/\]$/]}/s;
            $pretty_json =~ s/([^\n]+)/\t\t$1/smg;
            print $pretty_json;
          }
        '
    done
    curl \
      --silent \
      --insecure \
      --request GET \
      --url "https://buildtools.bisnode.net/stash/rest/api/latest/projects/${project}/repos/${repo}/branches" \
      --header "Authorization: Bearer $_BITBUCKETTOKEN_"  \
      --header 'Accept:application/json ' \
    | perl -nle '
        use JSON::PP;
        $json = decode_json($_);
        if ($json->{size} > 0) {
          $pretty_json = JSON::PP->new->utf8->pretty->encode($json->{values});
          $pretty_json =~ s/([^\n]+)/\t\t\t$1/smg;
          print "\t\t:::BRANCHES::: {";
          print $pretty_json;
          print "\t\t}";
        }
      '
    # No documentation for 6.2.0
    # Old call works, https://docs.atlassian.com/bitbucket-server/rest/5.10.1/bitbucket-ref-restriction-rest.html
    curl \
      --silent \
      --insecure \
      --request GET \
      --url "https://buildtools.bisnode.com/stash/rest/branch-permissions/2.0/projects/${project}/repos/${repo}/restrictions" \
      --header "Authorization: Bearer $_BITBUCKETTOKEN_"  \
      --header 'Accept:application/json ' \
    | perl -nle '
        use JSON::PP;
        $json = decode_json($_);
        if ($json->{size} > 0) {
          $pretty_json = JSON::PP->new->utf8->pretty->encode($json->{values});
          $pretty_json =~ s/([^\n]+)/\t\t\t$1/smg;
          print "\t\t:::BRANCH PERMISSIONS::: {";
          print $pretty_json;
          print "\t\t}";
        }
      '
    echo -e "\t}"
  done
  echo "}"

done
