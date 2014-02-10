package RDF::TrineX::Merge::Bnodes;
#ABSTRACT: Merge blank nodes that obviously refer to the same resource
#VERSION

use strict;
use parent 'Exporter';
our @EXPORT = qw(merge_bnodes);

use Digest;
use RDF::Trine::Model;

sub merge_bnodes {
    my ($iterator, %options) = @_;

    # configuration

    $iterator = $iterator->as_stream if $iterator->isa('RDF::Trine::Model');

    my $digest = $options{digest} || 'MD5'; 
    $digest = Digest->new($digest) unless ref $digest;

    my $model  = $options{model}  || RDF::Trine::Model->new;


    # iterate and buffer triples with a single blank node

    my %buffer;
    while (my $triple = $iterator->next) {
        my $id   = undef;
        my $subj = $triple->subject;
        my $obj  = $triple->object;

        if ( $subj->isa('RDF::Trine::Node::Blank') ) {
            if ( $obj->isa('RDF::Trine::Node::Blank') ) {
                # both blank => flush buffer
                my @ids = map { $_->blank_identifier } $subj, $obj;
                foreach (@ids) {
                    foreach (@{ $buffer{$_} || [] }) {
                        $model->add_statement($_);
                    }
                    $buffer{$_} = undef;
                }
            } else {
                $id = $subj->blank_identifier;
            }
        } elsif ( $obj->isa('RDF::Trine::Node::Blank') ) {
            $id = $obj->blank_identifier;
        }

        if ( defined $id and  ($buffer{$id} or !exists $buffer{$id}) ) {
            push @{ $buffer{$id} }, $triple;
            next;
        }

        $model->add_statement( $triple );
    }

    my %id2digest;
    my %digest2id;

    while (my ($id, $triples) = each %buffer) {
        next if !defined $triples;

        # calculate digest for the set of triples connected to bnode $id
        my @canonical;
        foreach (@$triples) {
            my ($subj, $obj) = map {
                $_->isa('RDF::Trine::Node::Blank') ? '~' : $_->as_ntriples
            } $_->subject, $_->object;
            push @canonical, join ' ', $subj, $_->predicate->as_ntriples, $obj;
        }
        # print "$_\n" for sort @canonical;

        $digest->reset;
        $digest->add($_) for sort @canonical;
        my $base64 = $digest->b64digest;

        $id2digest{$id} = $base64;
        push @{$digest2id{$base64}}, $id;
    }

    # use Data::Dumper; print Dumper(\%digest2id)."\n";

    # keep only of of each bnode that obviously refer to the same resource

    foreach my $base64 ( keys %digest2id ) {
        # sort only required for stable bnode ids (FIXME?)
        my @ids = sort @{$digest2id{$base64}}; 

        shift @ids; # keep the first
        foreach (@ids) {
            $buffer{$_} = undef;
        }
    }
    

    # add remaining triples with bnodes
    
    foreach (grep { defined $_ } values %buffer) {
        foreach ( @$_ ) {
            $model->add_statement( $_ );
        }
    }

    return $model;
}

=head1 SYNOPSIS

    use RDF::TrineX::Merge::Bnodes;

    $model = merge_bnodes($model_or_iterator);

To give an example, applying C<merge_bnodes> on this graph:

    @prefix foaf: <http://xmlns.com/foaf/0.1/> .
    @base   <http://example.org/> .

    <Alice> foaf:knows [ a foaf:Person ; foaf:name "Bob" ] .
    <Alice> foaf:knows [ a foaf:Person ; foaf:name "Bob" ] . # obviously the same

will remove the second Bob.

=head1 DESCRIPTION

This module exports the function B<merge_bnodes> to merge blank nodes that
obviously refer to the same resource in an RDF graph.  In other words the
function can be used to get rid of obviously duplicated statements.
Obviously duplicated statements are defined as statements that

=over

=item

include either a blank node subject or a blank node object,

=item

only differ by their blank node identifier,

=item

and connect to the same statements by their blank node.

=back

=head1 LIMITATIONS

Statements that involve multiple blank nodes or blank nodes that are connected
to another blank node are never removed.

The method does not check whether triples are RDF-compatible: predicates must
not be blank.

No entailment.

If the passed iterator emits identical statementes, these statements are not
filtered out.

Don't expect any algorithm to understand what you mean by some RDF data.

=head1 TODO

Skolemize blank nodes (with IRIs containing C<.well-known/genid/$base64>).

=encoding utf8

=cut
