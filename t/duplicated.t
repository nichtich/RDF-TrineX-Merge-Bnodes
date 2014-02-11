use strict;
use Test::More;
use RDF::TrineX::Merge::Bnodes;
use RDF::Trine qw(iri statement blank);
use RDF::Trine::Iterator;

sub triple {
    statement( map {
        $_ =~ /^\?(.+)$/ ? blank("b$1") : iri("x:$_")
    } split " ", $_[0] )
}

sub count {
    merge_bnodes( 
        RDF::Trine::Iterator->new( [ map { triple($_) } @_ ], 'graph')
    )->size
}

is count("s p ?1", "s p ?2"), 1;
is count("s p ?1", "s p ?1"), 1;

# both blank but detected later
is count("?1 p o", "?1 p ?2"), 2;
is count("?1 p o", "?1 p ?1"), 2;
is count("s p ?2", "?1 p ?2"), 2;

done_testing;
