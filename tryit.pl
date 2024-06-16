#!/usr/bin/env perl

use strict;
use warnings;
use lib '.';
use PostBranchRepoRestriction;

my $project_key = 'QA';
my $repository_slug = 'testing-permission-settings';
my $json_file = 'repo_permission_groups.test-QA.trimmed.txt';

my $pbr = PostBranchRepoRestriction->new(
    project_key     => $project_key,
    repository_slug => $repository_slug,
    json_file       => $json_file,
);

$pbr->run();
