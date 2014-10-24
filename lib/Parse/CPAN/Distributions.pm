package Parse::CPAN::Distributions;

use strict;
use vars qw($VERSION);

$VERSION = '0.03';

#----------------------------------------------------------------------------

=head1 NAME

Parse::CPAN::Distributions - Provides an index for current CPAN distributions

=head1 SYNOPSIS

  my $oncpan = Parse::CPAN::Distributions->new(database => $db);
  my $found  = $oncpan->listed($distribution,$version);
  my $any    = $oncpan->listed($distribution);
  my @dists  = $oncpan->distributions_by($author);

=head1 DESCRIPTION

This distribution provides the ability to index the distributions that are
currently listed on CPAN. This is done by parsing the index file find-ls.

=cut

#----------------------------------------------------------------------------
# Library Modules

use CPAN::DistnameInfo;
use File::Basename;
use File::Path;
use File::Slurp;
use File::Temp  qw(tempfile);
use IO::File;
use IO::Zlib;
use LWP::UserAgent;
use version;

#----------------------------------------------------------------------------
# Variables

my (%distros,%authors);
my $archive = qr{\.(?:tar\.(?:bz2|gz|Z)|t(?:gz|bz)|zip)$}i;

# -------------------------------------
# Routines

=head1 INTERFACE

=head2 The Constructor

=over

=item new

Parses find-ls, extracting the list of all the module distributions.

Takes one optional hash key/pair, 'file', which can be used to specify the
path an existing compressed or uncompressed 'find-ls' file. By default a copy
will be downloaded and automatically loaded into memory.

=back

=cut

sub new {
    my ($class,%hash) = @_;
    my $self = { file => $hash{file} };
    bless $self, $class;

    $self->parse;
    return $self;
}

=head2 Methods

=over

=item listed

Given a distribution and version, returns 1 if on CPAN, otherwise 0. Note that
if version is not provides it will assume you are looking for any version.

=cut

sub listed {
    my ($self,$distribution,$version) = @_;

    return 0    unless(defined $distribution);
    return 0    unless(defined $distros{$distribution});
    return 1    unless(defined $version);
    return 1    if($distros{$distribution}->{$version});
    return 0;
}

=item distributions_by

Given an author ID, returns a sorted list of the versioned distributions
currently available on CPAN.

=cut

sub distributions_by {
    my ($self,$author) = @_;

    return ()   unless(defined $author);
    return ()   unless(defined $authors{$author});
    return sort keys %{$authors{$author}};
}

=item latest_version

Given a distribution, returns the latest known version on CPAN. If given a
distribution and author, will return the latest version for that author.

Note that a return value of 0, implies unknown.

=cut

sub latest_version {
    my ($self,$distribution,$author) = @_;

    return 0    unless(defined $distribution);
    return 0    unless(defined $distros{$distribution});

    my @versions =
        map {$_->{external}}
        sort {$b->{internal} <=> $a->{internal}}
        map {my $v; eval {$v = version->new($_)}; {internal => $@ ? $_ : $v->numify, external => $_}} keys %{$distros{$distribution}};

    if($author) {
        for my $version (@versions) {
            return $version if($distros{$distribution}{$version} eq $author);
        }
        return 0;
    }

    return shift @versions;
}

=item versions

Given a distribution will return all the versions available on CPAN. Given a
dsitribution and author, will return all the versions attributed to that
author.

=cut

sub versions {
    my ($self,$distribution,$author) = @_;
    my (%versions,@versions);

    return ()   unless(defined $distribution);
    return ()   if(defined $author && !defined $authors{$author});

    if($author) {
        %versions = map {$_ => 1} @{$authors{$author}{$distribution}};
        @versions =
            map {$_->{external}}
            sort {$a->{internal} <=> $b->{internal}}
            map {my $v; eval {$v = version->new($_)}; {internal => $@ ? $_ : $v->numify, external => $_}} keys %versions;
        return @versions;
    }

    return ()   unless(defined $distros{$distribution});

    %versions = map {$_ => 1} keys %{$distros{$distribution}};
    @versions =
        map {$_->{external}}
        sort {$a->{internal} <=> $b->{internal}}
        map {my $v; eval {$v = version->new($_)}; {internal => $@ ? $_ : $v->numify, external => $_}} keys %versions;
    return @versions;
}

=item parse

Parse find-ls, extracting the list of all the module distributions.

=cut

sub parse {
    my $self = shift;
    my $temp = 0;

    #print STDERR "#file=$self->{file}\n";

    unless($self->{file} && -f $self->{file}) {
        my $url = 'http://www.cpan.org/indices/find-ls.gz';
        my $ua  = LWP::UserAgent->new;
        $ua->timeout(180);

        my ($fh, $filename) = tempfile( 'find-ls-XXXX', SUFFIX => '.gz', UNLINK => 0);

        my $response = $ua->mirror($url,$filename);
        if (!$response->is_success) {
            die "Error fetching $url";
        }
        $self->{file} = $filename;
        $temp = 1;
    }

    if($self->{file} && -f $self->{file}) {
        my $fh;
        if ( $self->{file} =~ /\.gz/ ) {
            $fh = IO::Zlib->new( $self->{file}, "rb" )
                || die "Failed to read archive [$self->{file}]: $!";
            return join '', <$fh>;
        } else {
            $fh = IO::File->new( $self->{file}, 'r' )
                || die "Failed to read file [$self->{file}]: $!";
        }

        while(<$fh>) {
            next    if(/(readme|meta)$/);
            next    unless(m!\s(authors/id/[A-Z]/../[^/]+/.*$archive)!);
            my $dist = CPAN::DistnameInfo->new($1);
            next    unless($dist && $dist->dist && $dist->version);

            #print STDERR "# line   =[$line]\n";
            #print STDERR "# dist   =[".($dist->dist)."]\n";
            #print STDERR "# version=[".($dist->version)."]\n";
            #print STDERR "# author =[".($dist->cpanid)."]\n";

            $distros{ $dist->dist }->{ $dist->version } = $dist->cpanid;
            push @{$authors{ $dist->cpanid }{ $dist->dist }}, $dist->version;
        }

        unlink($self->{file})   if($temp);
    } else {
        die "Error locating file [$self->{file}]";
    }
}

q("Everybody loves QA Automation!");

__END__

=back

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties, that is not explained within the POD
documentation, please send bug reports and patches to the RT Queue (see below).

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

RT: http://rt.cpan.org/Public/Dist/Display.html?Name=Parse-CPAN-Distributions

=head1 SEE ALSO

L<Parse-CPAN-Authors>,
L<Parse-CPAN-Packages>

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  for Miss Barbell Productions <http://www.missbarbell.co.uk>.

=head1 COPYRIGHT AND LICENSE

  Copyright (C) 2008 Barbie for Miss Barbell Productions.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.

=cut

