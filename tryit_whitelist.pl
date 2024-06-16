#!/usr/bin/env perl

use lib '.';
use WhiteList;

my $wl = WhiteList->instance(
    file => 'whitelist.yaml',
    bitbucket_user => $ENV{_BITBUCKETUSER_},
    bitbucket_pass => $ENV{_BITBUCKETPWD_}
);

if ($wl->set_excemptions('QA', 'kubernetes-env-config')) {
    print "Project or repository is in the whitelist\n";
} elsif ($wl->set_excemptions('QA', undef)) {
    print "Project is in the whitelist\n";
} else {
    print "Not in the whitelist\n";
}

# my @repos = $wl->get_repos('QA');
# print "Whitelisted repositories: @repos\n";
#
# my @teams = $wl->get_teams('QA', 'kubernetes-env-config');
# print "Whitelisted teams: @teams\n";
#
# my @users = $wl->get_users('QA', 'kubernetes-env-config');
# print "Whitelisted users: @users\n";

my @universal_exemptions = $wl->universal_exempt('QA', 'kubernetes-env-config');
print "Universal exemptions: @universal_exemptions\n";

my @universal_exemptions = $wl->universal_exempt('QA', 'testing-permission-settings');
print "Universal exemptions: @universal_exemptions\n";


