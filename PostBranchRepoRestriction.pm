package PostBranchRepoRestriction;

use strict;
use warnings;
use LWP::UserAgent;
use JSON;

sub new {
    my ($class, %args) = @_;
    my $self = {
        project_key     => $args{project_key},
        repository_slug => $args{repository_slug},
        json_file       => $args{json_file},
        api_url         => 'https://buildtools.bisnode.com/stash/rest/branch-permissions/latest/projects',
    };
    bless $self, $class;
    return $self;
}

sub read_file {
    my ($self) = @_;
    open my $fh, '<', $self->{json_file} or die "Cannot open file: $!";
    local $/ = undef;
    my $file_content = <$fh>;
    close $fh;
    return $file_content;
}

sub extract_branch_permissions {
    my ($self, $content) = @_;
    my @permissions;

    if ($content =~ /:: PROJECT BRANCH PERMISSIONS ::\s*\{(.*?)\}\s*::Repo::/s) {
        my $permissions_block = $1;

        while ($permissions_block =~ /\{\s*("type"\s*:\s*".+?")\s*,\s*("id"\s*:\s*\d+)\s*,\s*("groups"\s*:\s*\[.*?\])\s*,\s*("users"\s*:\s*\[.*?\])\s*,\s*("matcher"\s*:\s*\{.*?\})\s*\}/gs) {
            my $perm_json = "{ $1, $2, $3, $4, $5 }";
            eval {
                my $perm = decode_json($perm_json);
                push @permissions, $perm;
            };
            if ($@) {
                warn "Failed to parse permission JSON: $@";
            }
        }
    }

    return \@permissions;
}

sub create_post_data {
    my ($self, $permissions) = @_;
    my @post_data;
    foreach my $perm (@$permissions) {
        my $post_item = {
            type    => $perm->{type},
            matcher => {
                id        => $perm->{matcher}->{id},
                displayId => $perm->{matcher}->{displayId},
                type      => {
                    id   => $perm->{matcher}->{type}->{id},
                    name => $perm->{matcher}->{type}->{name},
                },
                active => $perm->{matcher}->{active},
            },
            users  => $perm->{users},
            groups => $perm->{groups},
        };
        push @post_data, $post_item;
    }
    return \@post_data;
}

sub post_permissions {
    my ($self, $post_data) = @_;
    my $ua = LWP::UserAgent->new;
    my $url = "$self->{api_url}/$self->{project_key}/repos/$self->{repository_slug}/restrictions";
    print encode_json($post_data);
#     my $response = $ua->post(
#         $url,
#         'Content-Type' => 'application/json',
#         Content        => encode_json($post_data),
#     );
#     if ($response->is_success) {
#         print "Permissions posted successfully.\n";
#     } else {
#         die "Failed to post permissions: " . $response->status_line;
#     }
}

sub run {
    my ($self) = @_;
    my $content = $self->read_file();
    my $permissions = $self->extract_branch_permissions($content);
    my $post_data = $self->create_post_data($permissions);
    $self->post_permissions($post_data);
}

1;
