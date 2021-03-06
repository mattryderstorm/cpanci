package CPANci::WebApp::Main { 
    use feature ':5.10';
    no warnings 'experimental';

    use version;

    use Mojo::Base 'Mojolicious::Controller';
    use MongoDB;
    use List::Util 'first';

    sub hello { 
        my $self = shift;

        my @dists = $self->db->get_collection( 'dists' )->find( { }, { fetched => 1 } )->sort( { fetched => -1 } )->limit( 100 )->all; 
  
        $self->stash( dists => \@dists );
        return $self->render;
    }

    sub dist { 
        my $self = shift;
        my $universe = $self->stash( 'universe' );
        my $dist = $self->stash( 'dist' );

        my @perls = $self->_get_perls;

        my %deps  = map { $_->{perl} => $_ } $self->db->get_collection( 'deps' )->find( { dist => "$universe/$dist" } )->all;
        my %tests = map { $_->{perl} => $_ } $self->db->get_collection( 'tests' )->find( { dist => "$universe/$dist" } )->all;

        my %deps_tab = map { $_->{version} => $deps{$_->{version}}{deps}{deps} } @perls;

        $self->stash( deps => \%deps, tests => \%tests, perls => \@perls, deps_tab => \%deps_tab );
        return $self->render;
    }

    sub deps { 
        my $self = shift;

        my $universe = $self->stash( 'universe' );
        my $dist = $self->stash( 'dist' );

        my @perls = $self->_get_perls;
        my %deps  = map { $_->{perl} => $_ } $self->db->get_collection( 'deps' )->find( { dist => "$universe/$dist" } )->all;

        $self->stash( deps => \%deps, perls => \@perls );
        return $self->render;
    }

    sub deps_log { 
        my $self = shift;
 
        my $universe = $self->stash( 'universe' );
        my $dist = $self->stash( 'dist' );
        my $perl = $self->stash( 'perl' );

        my $log = $self->db->get_collection( 'deps' )->find_one( { dist => "$universe/$dist", perl => $perl }, { 'deps.log' => 1 } );
        $self->stash( log => $log );

        return $self->render;
    }

    sub tests { 
        my $self = shift;

        my $universe = $self->stash( 'universe' );
        my $dist = $self->stash( 'dist' );
        my $perl = $self->stash( 'perl' );

        my $tests = $self->db->get_collection( 'tests' )->find_one( { dist => "$universe/$dist", perl => $perl } );

        $self->stash( tests => $tests );

        return $self->render;
    }

    sub rawtap { 
        my $self = shift;

        my $universe = $self->stash( 'universe' );
        my $dist = $self->stash( 'dist' );
        my $perl = $self->stash( 'perl' );
        my $test = $self->stash( 'test' );

        my $tests = $self->db->get_collection( 'tests' )->find_one( { dist => "$universe/$dist", perl => $perl } );
        my $tap = first { $_->{name} eq $test } @{ $tests->{tests} };

        return $self->render( text => $tap->{raw_tap}, format => 'txt' );
    }

    sub stderr { 
        my $self = shift;

        my $universe = $self->stash( 'universe' );
        my $dist = $self->stash( 'dist' );
        my $perl = $self->stash( 'perl' );
        my $test = $self->stash( 'test' );

        my $tests = $self->db->get_collection( 'tests' )->find_one( { dist => "$universe/$dist", perl => $perl } );
        my $tap = first { $_->{name} eq $test } @{ $tests->{tests} };

        return $self->render( text => $tap->{raw_err}, format => 'txt' );
    }

    sub _get_perls { 
        my $self = shift;

        # schwartzify
        my @perls = sort {
            version->parse( $a->{version} =~ s/perl-//r ) <=> version->parse( $b->{version} =~ s/perl-//r )
        } $self->db->get_collection( 'perls' )->find->all;

        return @perls;
    }

    # abstract this somewhere
    sub db { 
        my $self = shift;
        return MongoDB::MongoClient->new->get_database( 'cpanci' );
    }
}

1;
