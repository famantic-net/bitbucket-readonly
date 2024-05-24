#!/usr/bin/env perl

use strict;
use warnings;
use JSON::PP;
use autodie;

use Getopt::Std;
my %opts;
getopts("cp", \%opts);

use lib '.';
use PostBranchRestriction;

binmode(STDOUT, ":encoding(UTF-8)");

my $permgroups;
{
    local $/;
    open my $fh, '<', "repo_permission_groups.txt";
    $permgroups = <$fh>;
    close $fh;
}

my $commit = 1 if $opts{c};
my $display_permissions = 1 if $opts{p};
my @levels = qw(groups users);
my %projects;
my %project_permissions;
my %repo_per_project;
my %repo_per_project_permissions;
my %branch_permissions_per_project;
my %branch_permissions_per_repo_per_project;
my %branches_per_repo_per_project;

# Parse project blocks
while ($permgroups =~ m/(:Project:\s.+?^})/smg) {
    my $project = $1;
    my ($project_name) = $project =~ m/:Project:\s+([^{]+)\s+{/;
    $projects{$project_name} = $project;

    # Parse permissions for each level
    for my $level (@levels) {
        while ($project =~ m/\t:: PROJECT PERMISSIONS \($level\) ::\s+(.+?^\t\]})/smg) {
            my $permissions = $1;
            $permissions =~ s/^{/{ "permissions": /;
            my $json = decode_json($permissions);
            for my $permission (@{$json->{permissions}}) {
                my %perm_settings = parse_permission($level, $permission);
                push @{$project_permissions{$project_name}}, \%perm_settings;
            }
        }
    }
    while ($project =~ m/\t:: PROJECT BRANCH PERMISSIONS ::\s+(.+?^\t})/smg) {
        my $permissions = $1;
        $permissions =~ s/^{/{ "permissions": /;
        my $json = decode_json($permissions);
        for my $permission (@{$json->{permissions}}) {
            my %perm_settings = parse_branch_permission($permission);
            push @{$branch_permissions_per_project{$project_name}}, \%perm_settings;
        }
    }

    # Parse repository blocks
    while ($project =~ m/(\t::Repo::\s.+?^\t})/smg) {
        my $repo = $1;
        my ($repo_name) = $repo =~ m/::Repo::\s+([^{]+)\s+{/;
        $repo_per_project{$project_name}{$repo_name} = $repo;

        # Parse repo permissions for each level
        for my $level (@levels) {
            while ($repo =~ m/\t\t::: REPO PERMISSIONS \($level\) :::\s+(.+?^\t\t\]})/smg) {
                my $permissions = $1;
                $permissions =~ s/^{/{ "permissions": /;
                my $json = decode_json($permissions);
                for my $permission (@{$json->{permissions}}) {
                    my %perm_settings = parse_permission($level, $permission);
                    push @{$repo_per_project_permissions{$project_name}{$repo_name}}, \%perm_settings;
                }
            }
        }

        # Parse branch blocks
        while ($repo =~ m/\t\t:::BRANCHES:::\s+(.+?^\t\t})/smg) {
            my $branches = $1;
            $branches =~ s/^{/{ "branches": /;
            my $json = decode_json($branches);
            for my $branch (@{$json->{branches}}) {
                push @{$branches_per_repo_per_project{$project_name}{$repo_name}}, $branch->{displayId};
            }
        }

        # Parse branch permissions
        while ($repo =~ m/\t\t:::REPO BRANCH PERMISSIONS:::\s+(.+?^\t\t})/smg) {
            my $permissions = $1;
            $permissions =~ s/^{/{ "permissions": /;
            my $json = decode_json($permissions);
            for my $permission (@{$json->{permissions}}) {
                my %perm_settings = parse_branch_permission($permission);
                push @{$branch_permissions_per_repo_per_project{$project_name}{$repo_name}}, \%perm_settings;
            }
        }
    }
}

# Print the results
for my $proj (sort keys %projects) {
    print "$proj ->\n";
    if ($display_permissions) {
        print_permissions($project_permissions{$proj}, "\t== Project permissions ==\n");
        print_permissions($branch_permissions_per_project{$proj}, "\t== Project branch permissions (current) ==\n");
    }
    PostBranchRestriction->curlpost($proj, $branch_permissions_per_project{$proj}, $commit);

    my $printed;
    for my $repo (sort keys %{$repo_per_project{$proj}}) {
        print "\t= Repo =\n" if not $printed;
        $printed = 1;
        print "\t$repo\n";
        if ($display_permissions) {
            print_permissions($repo_per_project_permissions{$proj}{$repo}, "\t\t== Repo permissions ==\n");
            print_permissions($branch_permissions_per_repo_per_project{$proj}{$repo}, "\t\t== Branch permissions ==\n");
            print_branches($branches_per_repo_per_project{$proj}{$repo});
        }
    }
}

sub parse_permission {
    my ($level, $permission) = @_;
    if ($level eq 'groups') {
        return (
            group_name       => $permission->{group}{name},
            group_permission => $permission->{permission},
        );
    } else {
        return (
            user_permission   => $permission->{permission},
            user_displayName  => $permission->{user}{displayName},
            user_name         => $permission->{user}{name},
            user_slug         => $permission->{user}{slug},
            user_emailAddress => $permission->{user}{emailAddress},
        );
    }
}

sub parse_branch_permission {
    my ($permission) = @_;
    return (
        scope_type          => $permission->{scope}{type},
        type                => $permission->{type},
        matcher_id          => $permission->{matcher}{id},
        matcher_displayId   => $permission->{matcher}{displayId},
        matcher_type_id     => $permission->{matcher}{type}{id},
        matcher_type_name   => $permission->{matcher}{type}{name},
        users               => $permission->{users},
        groups              => $permission->{groups},
    );
}

sub print_permissions {
    my ($permissions, $header) = @_;
    my $printed;
    for my $perm_settings (@$permissions) {
        print $header if not $printed;
        for my $key (sort keys %$perm_settings) {
            my $perm_data = $perm_settings->{$key};
            unless (grep(/$key/, qw(users groups))) {
                print "\t\t$key: $perm_data" if $perm_data;
            }
        }
        for my $key (sort keys %$perm_settings) {
            my $perm_data = $perm_settings->{$key};
            if (grep(/$key/, qw(users groups))) {
                for my $cred (@{$perm_data}) {
                    print "\n";
                    if ($key eq "users") {
                        for my $cred_key (sort keys %{$cred}) {
                            print "\t\t\t$key:$cred_key: $cred->{$cred_key}";
                        }
                    }
                    else {
                        print "\t\t\t$key: $cred";
                    }
                }
            }
        }
        print "\n";
        $printed = 1;
    }
}

sub print_branches {
    my ($branches) = @_;
    my $printed;
    for my $branch (@$branches) {
        print "\t\t== Branches ==\n" if not $printed;
        print "\t\t$branch\n";
        $printed = 1;
    }
}
