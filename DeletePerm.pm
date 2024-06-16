package DeletePerm;

use strict;
use feature 'unicode_strings';
use JSON::PP;

our $proj_urlsnip = "{projectKey}/restrictions/{Id}";
our $repo_urlsnip = "{projectKey}/repos/{repositorySlug}/restrictions/{Id}";

my $printed;

sub new {
    my ($class, %args) = @_;
    my $self = {
        project          => $args{project},
        repo             => $args{repo},
        perm_id          => $args{perm_id},
        scope_type       => $args{scope_type},
        is_branch_perm   => $args{is_branch_perm},
        quiet            => $args{quiet},
        commit           => $args{commit},
    };
    bless $self, $class;
    return $self;
}

sub curlput {
    my ($self) = @_;
    #my $invocant = shift;
    #my $class = ref($invocant) || $invocant;

    my $get_urlsnip = sub {
        local $proj_urlsnip = $proj_urlsnip;
        local $repo_urlsnip = $repo_urlsnip;
        unless ($self->{repo}) { # Project level;
            $proj_urlsnip =~ s/{projectKey}/$self->{project}/;
            $proj_urlsnip =~ s/{Id}/$self->{perm_id}/;
            return $proj_urlsnip;
        }
        else { # Repo level
            $repo_urlsnip =~ s/{projectKey}/$self->{project}/;
            $repo_urlsnip =~ s/{repositorySlug}/$self->{repo}/;
            $repo_urlsnip =~ s/{Id}/$self->{perm_id}/;
            return $repo_urlsnip;
        }
    };

    my $curl = qq(
      curl \\
        --silent \\
        --insecure \\
        --request DELETE \\
        --url 'https://buildtools.bisnode.com/stash/rest/branch-permissions/2.0/projects/@{[ $get_urlsnip->() ]}' \\
        --header "Authorization: Bearer $ENV{_BITBUCKETTOKEN_}"
    );
    if ($self->{is_branch_perm}) {
        if ((($self->{scope_type} eq "PROJECT") and not defined $self->{repo})
            or
            (($self->{scope_type} ne "PROJECT") and $self->{repo})
        ) {
            unless ($self->{repo}) { # For better readibility in print
                $curl =~ s/^/\t\t/smg
            }
            else {
                $curl =~ s/^/\t\t\t/smg
            }
            unless ($self->{commit}) {
                print "$curl" unless $self->{quiet};
            }
            else {
                print "\n>>> Sending: <<<\n$curl\n---\n";
                my $received = qx($curl);
                print "<<< Response: >>>\n---\n";
                print qq($received\n---\n);
            }
        }
    }
}


1;