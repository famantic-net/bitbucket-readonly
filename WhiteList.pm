package WhiteList;
# Written by ChatGPT/4o (after many iterations and some directed changes)

use strict;
use warnings;
use YAML::XS 'LoadFile';
use LWP::UserAgent;
use JSON::PP;
use MIME::Base64;

my $instance;

sub instance {
    my ($class, %args) = @_;
    return $instance if defined $instance;

    my $self = {
        whitelist       => _build_whitelist($args{file}),
        bitbucket_user  => $args{bitbucket_user},
        bitbucket_pass  => $args{bitbucket_pass},
        all_users       => _fetch_all_users($args{bitbucket_user}, $args{bitbucket_pass}),
        all_teams       => _fetch_all_teams($args{bitbucket_user}, $args{bitbucket_pass}),
    };

    bless $self, $class;
    $instance = $self;

    # Update the 'all-users' group in Bitbucket
    $self->_update_all_users_group();

    return $self;
}

sub _build_whitelist {
    my $file = shift;
    my $data = LoadFile($file);
    return $data->{whitelist};
}

sub _fetch_all_users {
    my ($user, $pass) = @_;
    my $url = 'https://buildtools.bisnode.com/stash/rest/api/latest/admin/users?limit=1000';
    return _fetch_bitbucket_data($url, $user, $pass);
}

sub _fetch_all_teams {
    my ($user, $pass) = @_;
    my $url = 'https://buildtools.bisnode.com/stash/rest/api/latest/admin/groups?limit=1000';
    return _fetch_bitbucket_data($url, $user, $pass);
}

sub _fetch_bitbucket_data {
    my ($url, $user, $pass) = @_;
    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(GET => $url);
    my $credentials = encode_base64("$user:$pass", '');
    $req->header('Authorization' => 'Basic ' . $credentials);

    my $res = $ua->request($req);
    if ($res->is_success) {
        my $json = JSON::PP->new->utf8->decode($res->decoded_content);
        return [map { $_->{name} } @{$json->{values}}];
    } else {
        warn "Failed to fetch data from Bitbucket: " . $res->status_line;
        return [];
    }
}

sub _update_all_users_group {
    my $self = shift;
    my $url = 'https://buildtools.bisnode.com/stash/rest/api/latest/admin/groups/add-users';

    my $ua = LWP::UserAgent->new;
    my $req = HTTP::Request->new(POST => $url);
    my $credentials = encode_base64($self->{bitbucket_user} . ':' . $self->{bitbucket_pass}, '');
    $req->header('Authorization' => 'Basic ' . $credentials);
    $req->header('Content-Type' => 'application/json');
    $req->content(JSON::PP->new->utf8->encode({
        group => 'all-users',
        users => $self->{all_users}
    }));

    my $res = $ua->request($req);
    unless ($res->is_success) {
        warn "Failed to add users to 'all-users' group: " . $res->status_line;
    }
}

sub set_excemptions {
    my ($self, $project, $repo) = @_;

    # Check for project-level _ALL_
    if (exists $self->{whitelist}->{_ALL_}) {
        # Check for _ALL_ in repo
        if (defined $repo and (exists $self->{whitelist}->{_ALL_}->{$repo} or exists $self->{whitelist}->{_ALL_}->{_ALL_})) {
            return 1;
        }
        # Check for _ALL_ at project level
        if (!defined $repo and exists $self->{whitelist}->{_ALL_}->{_ALL_}) {
            return 1;
        }
    }

    # Check specific project
    if (exists $self->{whitelist}->{$project}) {
        # Check for repo-specific or project-level _ALL_
        if (defined $repo and (exists $self->{whitelist}->{$project}->{$repo} or exists $self->{whitelist}->{$project}->{_ALL_})) {
            return 1;
        }
        # Check for project-level _ALL_
        if (!defined $repo and exists $self->{whitelist}->{$project}->{_ALL_}) {
            return 1;
        }
    }

    return 0;
}

sub get_repos {
    my ($self, $project) = @_;
    my @repos;

    if (exists $self->{whitelist}->{_ALL_}) {
        push @repos, keys %{ $self->{whitelist}->{_ALL_} };
    }

    if (exists $self->{whitelist}->{$project}) {
        push @repos, keys %{ $self->{whitelist}->{$project} };
    }

    # Remove duplicates
    my %seen;
    @repos = grep { !$seen{$_}++ } @repos;

    return @repos;
}

sub get_teams {
    my ($self, $project, $repo) = @_;
    my @teams;

    if (exists $self->{whitelist}->{_ALL_}) {
        if (defined $repo and exists $self->{whitelist}->{_ALL_}->{$repo}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{_ALL_}->{$repo}->{teams}}) {
                push @teams, @{$self->{all_teams}};
            } else {
                push @teams, @{$self->{whitelist}->{_ALL_}->{$repo}->{teams}};
            }
        }
        if (exists $self->{whitelist}->{_ALL_}->{_ALL_}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{_ALL_}->{_ALL_}->{teams}}) {
                push @teams, @{$self->{all_teams}};
            } else {
                push @teams, @{$self->{whitelist}->{_ALL_}->{_ALL_}->{teams}};
            }
        }
    }

    if (exists $self->{whitelist}->{$project}) {
        if (defined $repo and exists $self->{whitelist}->{$project}->{$repo}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{$project}->{$repo}->{teams}}) {
                push @teams, @{$self->{all_teams}};
            } else {
                push @teams, @{$self->{whitelist}->{$project}->{$repo}->{teams}};
            }
        }
        if (exists $self->{whitelist}->{$project}->{_ALL_}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{$project}->{_ALL_}->{teams}}) {
                push @teams, @{$self->{all_teams}};
            } else {
                push @teams, @{$self->{whitelist}->{$project}->{_ALL_}->{teams}};
            }
        }
    }

    # Remove duplicates
    my %seen;
    @teams = grep { !$seen{$_}++ } @teams;

    return @teams;
}

sub get_users {
    my ($self, $project, $repo) = @_;
    my @users;

    if (exists $self->{whitelist}->{_ALL_}) {
        if (defined $repo and exists $self->{whitelist}->{_ALL_}->{$repo}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{_ALL_}->{$repo}->{users}}) {
                push @users, @{$self->{all_users}};
            } else {
                push @users, @{$self->{whitelist}->{_ALL_}->{$repo}->{users}};
            }
        }
        if (exists $self->{whitelist}->{_ALL_}->{_ALL_}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{_ALL_}->{_ALL_}->{users}}) {
                push @users, @{$self->{all_users}};
            } else {
                push @users, @{$self->{whitelist}->{_ALL_}->{_ALL_}->{users}};
            }
        }
    }

    if (exists $self->{whitelist}->{$project}) {
        if (defined $repo and exists $self->{whitelist}->{$project}->{$repo}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{$project}->{$repo}->{users}}) {
                push @users, @{$self->{all_users}};
            } else {
                push @users, @{$self->{whitelist}->{$project}->{$repo}->{users}};
            }
        }
        if (exists $self->{whitelist}->{$project}->{_ALL_}) {
            if (grep { $_ eq '_ALL_' } @{$self->{whitelist}->{$project}->{_ALL_}->{users}}) {
                push @users, @{$self->{all_users}};
            } else {
                push @users, @{$self->{whitelist}->{$project}->{_ALL_}->{users}};
            }
        }
    }

    # Remove duplicates
    my %seen;
    @users = grep { !$seen{$_}++ } @users;

    return @users;
}

sub universal_exempt {
    my ($self, $project, $repo) = @_;
    my $whitelist = $self->{whitelist};

    # Check for project-level or global _ALL_ exemptions
    if (exists $whitelist->{_ALL_}) {
        if (defined $repo) {
            if (exists $whitelist->{_ALL_}->{$repo}) {
                if (grep { $_ eq '_ALL_' } @{$whitelist->{_ALL_}->{$repo}->{users}} or
                    grep { $_ eq '_ALL_' } @{$whitelist->{_ALL_}->{$repo}->{teams}}) {
                    return ('all-users');
                }
            }
            if (exists $whitelist->{_ALL_}->{_ALL_}) {
                if (grep { $_ eq '_ALL_' } @{$whitelist->{_ALL_}->{_ALL_}->{users}} or
                    grep { $_ eq '_ALL_' } @{$whitelist->{_ALL_}->{_ALL_}->{teams}}) {
                    return ('all-users');
                }
            }
        } else {
            if (exists $whitelist->{_ALL_}->{_ALL_}) {
                if (grep { $_ eq '_ALL_' } @{$whitelist->{_ALL_}->{_ALL_}->{users}} or
                    grep { $_ eq '_ALL_' } @{$whitelist->{_ALL_}->{_ALL_}->{teams}}) {
                    return ('all-users');
                }
            }
        }
    }

    # Check for specific project _ALL_ exemptions
    if (exists $whitelist->{$project}) {
        if (defined $repo) {
            if (exists $whitelist->{$project}->{$repo}) {
                if (grep { $_ eq '_ALL_' } @{$whitelist->{$project}->{$repo}->{users}} or
                    grep { $_ eq '_ALL_' } @{$whitelist->{$project}->{$repo}->{teams}}) {
                    return ('all-users');
                }
            }
            if (exists $whitelist->{$project}->{_ALL_}) {
                if (grep { $_ eq '_ALL_' } @{$whitelist->{$project}->{_ALL_}->{users}} or
                    grep { $_ eq '_ALL_' } @{$whitelist->{$project}->{_ALL_}->{teams}}) {
                    return ('all-users');
                }
            }
        } else {
            if (exists $whitelist->{$project}->{_ALL_}) {
                if (grep { $_ eq '_ALL_' } @{$whitelist->{$project}->{_ALL_}->{users}} or
                    grep { $_ eq '_ALL_' } @{$whitelist->{$project}->{_ALL_}->{teams}}) {
                    return ('all-users');
                }
            }
        }
    }

    return ();
}

1;

__END__

=head1 NAME

WhiteList - Singleton module to manage project and repository whitelist

=head1 SYNOPSIS

  use WhiteList;

  my $wl = WhiteList->instance(
      file => '/mnt/data/whitelist.yaml',
      bitbucket_user => 'YOUR_BITBUCKET_USERNAME',
      bitbucket_pass => 'YOUR_BITBUCKET_PASSWORD'
  );

  if ($wl->set_excemptions('QA', 'kubernetes-env-config')) {
      print "Project or repository is in the whitelist\n";
  } elsif ($wl->set_excemptions('QA', undef)) {
      print "Project is in the whitelist\n";
  } else {
      print "Not in the whitelist\n";
  }

  my @repos = $wl->get_repos('QA');
  print "Whitelisted repositories: @repos\n";

  my @teams = $wl->get_teams('QA', 'kubernetes-env-config');
  print "Whitelisted teams: @teams\n";

  my @users = $wl->get_users('QA', 'kubernetes-env-config');
  print "Whitelisted users: @users\n";

  my @universal_exemptions = $wl->universal_exempt('QA', 'kubernetes-env-config');
  print "Universal exemptions: @universal_exemptions\n";

=head1 DESCRIPTION

This module reads a YAML whitelist and provides methods to check if a project or repository is in the whitelist, and to retrieve whitelisted repositories, teams, and users. It also fetches full lists of teams and users from Bitbucket when the keyword '_ALL_' is used and manages the Bitbucket group 'all-users'.

=head1 METHODS

=head2 instance(%args)

Creates or returns the singleton instance of the WhiteList module. Arguments are:

=over 4

=item * C<file> - Path to the whitelist YAML file.

=item * C<bitbucket_user> - The Bitbucket username used for API authentication.

=item * C<bitbucket_pass> - The Bitbucket password used for API authentication.

=back

=head2 set_excemptions($project, $repo)

Checks if the given project or repository is in the whitelist. Returns true if found, false otherwise. The C<$repo> parameter can be C<undef>.

=head2 get_repos($project)

Returns a list of whitelisted repositories for the given project.

=head2 get_teams($project, $repo)

Returns a list of whitelisted teams for the given project and repository. The C<$repo> parameter can be C<undef>.

=head2 get_users($project, $repo)

Returns a list of whitelisted users for the given project and repository. The C<$repo> parameter can be C<undef>.

=head2 universal_exempt($project, $repo)

Checks if the whitelist for the given project and repository contains the keyword '_ALL_' for either teams or users. If so, returns the Bitbucket group 'all-users' as a single element in an array. Otherwise, returns an empty array.

=cut
