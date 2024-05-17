#!/usr/bin/env bash

# Creates a dump with select data from Bitbucket.
#
# Set the _BITBUCKETTOKEN_ environment variable to contain your personal Bitbucket access token.
# export _BITBUCKETTOKEN_=...
#
# Create a file `bisnodeapps.txt`:
# $ ./bisnodeapps.sh 2>/dev/null | tee bisnodeapps.txt
#
# That file is the input to the next script, `bisnodeapps.pl`, that groups
# all applications with their development team, contact iformation and composing services
#

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
    curl \
      --silent \
      --insecure \
      --request GET \
      --url "https://buildtools.bisnode.net/stash/rest/api/latest/projects/${project}/repos/${repo}/browse/bisconf.yaml?start=0&limit=1000" \
      --header "Authorization: Bearer $_BITBUCKETTOKEN_"  \
      --header 'Accept:application/json ' \
    | jq '.lines | .[].text' \
    | perl -nle '
        use YAML::Tiny;
        s/^"|"$//g;
        $bisconf = $bisconf . "$_\n";
        END {
          $yaml = YAML::Tiny->read_string( $bisconf );
          $application = $yaml->[0]->{service}->{groupName};
          $service = $yaml->[0]->{service}->{name};
          $team = $yaml->[0]->{service}->{maintainer}->{name};
          $team_email = $yaml->[0]->{service}->{maintainer}->{email};
          print "\t\tApplication:\t$application\n\t\tService:\t$service\n\t\tTeam:\t$team\n\t\tContact:\t$team_email"
        }
      '
    echo -e "\t}"

  done
  echo "}"

done
