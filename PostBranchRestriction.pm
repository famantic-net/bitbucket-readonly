package PostBranchRestriction;

use strict;
use feature 'unicode_strings';
use JSON::PP;

our $postdata = qq(
  {
    "type" : "_=BRANCH_RESTRICTION=_",
    "scope" : {
        "type" : "PROJECT"
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
my $printed =1;

sub curlpost { #
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $project = shift;
    my $branch_permissions = shift;
    my $commit = shift;
    print "\t== Setting new project branch permissions ==\n";
    #for my $key (sort keys %$perm_settings) {
    #    my $perm_data = $perm_settings->{$key};
    #    print "\t\t$key: $perm_data" if $perm_data;
    #}
    #print "\n";
    for my $restriction (@restriction_set) {
        local $postdata = $postdata;
        $postdata =~ s/_=BRANCH_RESTRICTION=_/$restriction/sm;
        $postdata = JSON::PP->new->utf8->encode(decode_json($postdata));
        my $curl = qq(
          curl \\
            --silent \\
            --insecure \\
            --request POST \\
            --data '@{[ sprintf("%s", $postdata) ]}' \\
            --url 'https://buildtools.bisnode.com/stash/rest/branch-permissions/2.0/projects/@{[ sprintf("%s", $project) ]}/restrictions' \\
            --header "Authorization: Bearer $ENV{_BITBUCKETTOKEN_}" \\
            --header "Content-Type: application/json"
        );
        #print "*** $restriction ***\n";
        if ($commit) {
            my $received = qx($curl);
            print "Setting on project '$project':\n" if not $printed;
            $printed = 1;
            print JSON::PP->new->utf8->pretty->encode(decode_json($received));
        }
        else {
            #print "$curl";
        }
    }
}

1;