#!/usr/bin/env perl

#
# Reads 'bisnodeapps.txt' (created by `bisnodeapps.sh`) to group
# all applications with their development team, contact iformation and composing services
# 

{
  local undef $/;
  open my $fh, '<', "bisnodeapps.txt";
  $bisnodeapps = <$fh>;
  close $fh;
  open my $fh, '<', "bisnode-prod-deployed-services.txt";
  $bisnodeservices = <$fh>;
  close $fh;
}

while ($bisnodeservices =~ m/^([^\s]+)/smg) {
  $services_in_prod{$1} = 1; 
}
@services_in_prod = sort keys %services_in_prod;
# print "< $#services_in_prod >\n";

while ($bisnodeapps =~ m/(:Project:.+?^})/smg) {
  $project = $1;
  while ($project =~ m/(::Repo::.+?})/smg) {
    $repo = $1;
    my $application, $service, $team, $contact;
    ($application) = $repo =~ m/\tApplication:\t([^\n]*?)\n/;
    ($service) = $repo =~ m/\tService:\t([^\n]*?)\n/;
    ($team) = $repo =~ m/\tTeam:\t([^\n]*?)\n/;
    ($contact) = $repo =~ m/\tContact:\t([^\n]*?)\n/;
#     push @bisconf,$service;
    if (grep /$service/,@services_in_prod) {
      push @{$app{$application}{services}},$service;
      push @{$app{$application}{teams}},$team;
      push @{$app{$application}{contacts}},$contact;
    }
  }
}
for my $key (sort { "\L$a" cmp "\L$b" } keys %app) {
  my %seen1 = ();
  my @uniqu_services = grep { ! $seen1{$_} ++ } @{$app{$key}{services}};
  my %seen2 = ();
  my @uniqu_teams = grep { ! $seen2{$_} ++ } @{$app{$key}{teams}};
  my %seen3 = ();
  my @uniqu_contacts = grep { ! $seen3{$_} ++ } @{$app{$key}{contacts}};
  print "$key -> \n";
  for my $elem (@uniqu_teams) {print qq(\t<<$elem>>\n)}; 
  for my $elem (@uniqu_contacts) {print qq(\t[[$elem]]\n)}; 
  for my $elem (@uniqu_services) {print qq(\t$elem\n)}; 
}

# %seen = ();
# @uniqu_bisconf = grep { ! $seen{$_} ++ } @bisconf;
# print "< $#uniqu_bisconf >\n";
