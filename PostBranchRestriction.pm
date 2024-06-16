package PostBranchRestriction;

use strict;
use feature 'unicode_strings';
use JSON::PP;
use WhiteList;

our $postdata = qq(
  {
    "type" : "_=BRANCH_RESTRICTION=_",
    "scope" : {
        "type" : "_=LEVEL=_"
    },
    "matcher" : {
        "displayId" : "*",
        "id" : "*",
        "active" : true,
        "type" : {
          "id" : "PATTERN",
          "name" : "Pattern"
        }
    },
    "accessKeys" : [],
    "users" : [],
    "groups" : []
  }
);

my @restriction_set = qw(read-only no-deletes pull-request-only fast-forward-only);
my $printed;

sub curlpost {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $project = shift;
    my $repo = shift;
    my $teams = shift;
    my $users = shift;
    my $quiet = shift;
    my $commit = shift;
    my $url;
    local $postdata = $postdata;

    if ($repo) {
        $postdata =~ s/_=LEVEL=_/REPOSITORY/s;
        $url = "https://buildtools.bisnode.com/stash/rest/branch-permissions/2.0/projects/$project/repos/$repo/restrictions"
    }
    else {
        $postdata =~ s/_=LEVEL=_/PROJECT/s;
        $url = "https://buildtools.bisnode.com/stash/rest/branch-permissions/2.0/projects/$project/restrictions"
    }

    if (@{$teams}) {
        my $team_list = qq([\n);
        for my $team (@{$teams}) {
            $team_list .= qq(\t\t"$team",\n);
        }
        $team_list =~ s/,\n$/\n/sm;
        $team_list .= qq(\t]);
        $postdata =~ s/"groups" : \[\]/"groups" : $team_list/sm;
        #print $postdata;
    }
    if (@{$users}) {
        my $user_list = qq([\n);
        for my $user (@{$users}) {
            $user_list .= qq(\t\t"$user",\n);
        }
        $user_list =~ s/,\n$/\n/sm;
        $user_list .= qq(\t]);
        $postdata =~ s/"users" : \[\]/"users" : $user_list/sm;
        #print $postdata;
    }

    if ($commit) {
        print "\t== Setting new branch permissions ==\n";
    }
    else {
        unless ($quiet) {
            #print "\t<< $project >>\n";
            #print "\t\t<<< $repo >>>\n" if $repo;
        }
    }

    for my $restriction (@restriction_set) {
        local $postdata = $postdata;
        $postdata =~ s/_=BRANCH_RESTRICTION=_/$restriction/sm;
        $postdata = JSON::PP->new->utf8->encode(decode_json($postdata)); # Serialize
        my $curl = qq(
            curl \\
                --silent \\
                --insecure \\
                --request POST \\
                --data '@{[ sprintf("%s", $postdata) ]}' \\
                --url '$url' \\
                --header "Authorization: Bearer $ENV{_BITBUCKETTOKEN_}" \\
                --header "Content-Type: application/json"
        );
        $curl =~ s/[\t ]+$//s; # Removing that last empty indentation for better trace readibility
        print "\t\t>>> Setting on: project '$project', repo '$repo' <<<\n" if not $printed;
        #$printed = 1;
        if (@{$users} or @{$teams}) {
            print "\t\t>>> Adding excemptions for teams (@{$teams}) and users (@{$users}) <<<";
        }
        unless ($commit) {
            $curl =~ s/^/\t/smg if $repo; # For better readibility in print
            print "$curl" unless $quiet;
        }
        else {
            print "\n>>> Sending: <<<\n$curl\n---\n";
            my $received = qx($curl);
            print "<<< Response: >>>\n---\n";
            print JSON::PP->new->utf8->pretty->encode(decode_json($received));
        }
    }
}
1;