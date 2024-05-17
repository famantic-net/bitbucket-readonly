#!/usr/bin/env perl

use JSON::PP;
binmode(STDOUT, ":encoding(UTF-8)");

{
  local undef $/;
  open my $fh, '<', "repo_permission_groups.txt";
  our $permgroups = <$fh>;
  close $fh;
}

our @levels = qw(groups users);
our %projects;

while ($permgroups =~ m/(:Project:\s.+?^})/smg) {
  my $project = $1;
  ($project_name) = $project =~ m/:Project:\s+([^{]+)\s+{/;
  #print "$project_name\n";
  $projects{$project_name} = $project;
  #print "$project_name\n";
  for my $level (@levels) {
    while ($project =~ m/\t:: PROJECT PERMISSIONS \($level\) ::\s+(.+?^\t\]})/smg) {
      my $permissions = $1;
      # Adding initial hash key to the array of branches
      $permissions =~ s/^{/{ "permissions": /;
      my $json = decode_json($permissions);
      my $pretty_json = JSON::PP->new->utf8->pretty->encode($json);
      #print $pretty_json;
      my $printed;
      for my $permission (@{$json->{permissions}}) {
        my %perm_settings;
        if ($level eq "groups") {
          #print "== Project group permissions ==\n" if not $printed;
          #print "\tpermission: " . $permission->{permission} . "\t";
          #print "group.name: " . $permission->{group}{name} . "\n";
          $perm_settings{group_name} = $permission->{group}{name};
          $perm_settings{group_permission} = $permission->{permission};
          $printed = 1;
        }
        else {
          #print "== Project user permissions ==\n" if not $printed;
          #print "\tpermission: " . $permission->{permission} . "\t";
          #print "user.displayName: " . $permission->{user}{displayName} . "\t";
          #print "user.name: " . $permission->{user}{name} . "\t";
          #print "user.slug: " . $permission->{user}{slug} . "\t";
          #print "user.emailAddress: " . $permission->{user}{emailAddress} . "\n";
          $perm_settings{user_permission} = $permission->{permission};
          $perm_settings{user_displayName} = $permission->{user}{displayName};
          $perm_settings{user_name} = $permission->{user}{name};
          $perm_settings{user_slug} = $permission->{user}{slug};
          $perm_settings{user_emailAddress} = $permission->{user}{emailAddress};
          $printed = 1;
        }
        push @{$project_permissions{$project_name}}, \%perm_settings;
      }
      #print "\n";
    }
  }
  while ($project =~ m/(\t::Repo::\s.+?^\t})/smg) {
    my $repo = $1;
    ($repo_name) = $repo =~ m/::Repo::\s+([^{]+)\s+{/;
    #print "\t$repo_name\n";
    $repo_per_project{$project_name}{$repo_name} = $repo;
    for my $level (@levels) {
      while ($repo =~ m/\t\t::: REPO PERMISSIONS \($level\) :::\s+(.+?^\t\t\]})/smg) {
        my $permissions = $1;
        # Adding initial hash key to the array of branches
        $permissions =~ s/^{/{ "permissions": /;
        my $json = decode_json($permissions);
        my $pretty_json = JSON::PP->new->utf8->pretty->encode($json);
        #print $pretty_json;
        my $printed;
        for my $permission (@{$json->{permissions}}) {
          my %perm_settings;
          if ($level eq "groups") {
            #print "== Repo group permissions ==\n" if not $printed;
            #print "\tpermission: " . $permission->{permission} . "\t";
            #print "group.name: " . $permission->{group}{name} . "\n";
            $perm_settings{group_name} = $permission->{group}{name};
            $perm_settings{group_permission} = $permission->{permission};
            $printed = 1;
          }
          else {
            #print "== Repo user permissions ==\n" if not $printed;
            #print "\tpermission: " . $permission->{permission} . "\t";
            #print "user.displayName: " . $permission->{user}{displayName} . "\t";
            #print "user.name: " . $permission->{user}{name} . "\t";
            #print "user.slug: " . $permission->{user}{slug} . "\t";
            #print "user.emailAddress: " . $permission->{user}{emailAddress} . "\n";
            $perm_settings{user_permission} = $permission->{permission};
            $perm_settings{user_displayName} = $permission->{user}{displayName};
            $perm_settings{user_name} = $permission->{user}{name};
            $perm_settings{user_slug} = $permission->{user}{slug};
            $perm_settings{user_emailAddress} = $permission->{user}{emailAddress};
            $printed = 1;
          }
          push @{$repo_per_project_permissions{$project_name}{$repo_name}}, \%perm_settings;
        }
        #print "\n";
      }
    }
    while ($repo =~ m/\t\t:::BRANCHES:::\s+(.+?^\t\t})/smg) {
      my $branches = $1;
      # Adding initial hash key to the array of branches
      $branches =~ s/^{/{ "branches": /;
      my $json = decode_json($branches);
      my $pretty_json = JSON::PP->new->utf8->pretty->encode($json);
      #print $pretty_json;
      for my $branch (@{$json->{branches}}) {
        #print "\t\t" . $branch->{displayId} . "\n";
        push @{$branches_per_repo_per_project{$project_name}{$repo_name}}, $branch->{displayId};
      }
    }
    while ($repo =~ m/\t\t:::BRANCH PERMISSIONS:::\s+(.+?^\t\t})/smg) {
      my $permissions = $1;
      # Adding initial hash key to the array of branches
      $permissions =~ s/^{/{ "permissions": /;
      my $json = decode_json($permissions);
      my $pretty_json = JSON::PP->new->utf8->pretty->encode($json);
      #print $pretty_json;
      for my $permission (@{$json->{permissions}}) {
        #print "scope.type: " . $permission->{scope}{type} . "\t";
        #print "type: " . $permission->{type} . "\t";
        #print "matcher.id: " . $permission->{matcher}{id} . "\t";
        #print "displayId: " . $permission->{matcher}{displayId} . "\n";
        my %perm_settings;
        $perm_settings{scope_type} = $permission->{scope}{type};
        $perm_settings{type} = $permission->{type};
        $perm_settings{matcher_id} = $permission->{matcher}{id};
        $perm_settings{displayId} = $permission->{matcher}{displayId};
        push @{$branch_permissions_per_repo_per_project{$project_name}{$repo_name}}, \%perm_settings;
      }
    }
  }
}

for my $proj (sort keys %projects) {
  print "$proj ->\n";
  my $printed;
  for my $perm_settings (@{$project_permissions{$proj}}) {
    print "\t== Project permissions ==\n" if not $printed;
    for my $key (sort keys %{$perm_settings}) {
      my $perm_data = ${$perm_settings}{$key};
      print "\t$key: $perm_data" if $perm_data;
    }
    print "\n";
    $printed = 1;
  }
  my $printed;
  for my $repo (sort keys %{$repo_per_project{$proj}}) {
    print "\t= Repo =\n" if not $printed;
    $printed = 1;
    print "\t$repo\n";
    {
      my $printed;
      for my $perm_settings (@{$repo_per_project_permissions{$proj}{$repo}}) {
        print "\t\t== Repo permissions ==\n" if not $printed;
        for my $key (sort keys %{$perm_settings}) {
          my $perm_data = ${$perm_settings}{$key};
          print "\t\t$key: $perm_data" if $perm_data;
        }
        print "\n";
        $printed = 1;
      }
    }
    {
      my $printed;
      for my $perm_settings (@{$branch_permissions_per_repo_per_project{$proj}{$repo}}) {
        print "\t\t== Branch permissions ==\n" if not $printed;
        for my $key (sort keys %{$perm_settings}) {
          print "\t\t$key: ${$perm_settings}{$key}"
        }
        print "\n";
        $printed = 1;
      }
    }
    {
      my $printed;
      for my $branch (@{$branches_per_repo_per_project{$proj}{$repo}}) {
        print "\t\t== Branches ==\n" if not $printed;
        print "\t\t$branch\n";
        $printed = 1;
      }
    }
  }
}
