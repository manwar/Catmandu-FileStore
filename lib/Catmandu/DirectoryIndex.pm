package Catmandu::DirectoryIndex;

use Catmandu::Sane;

our $VERSION = '1.15';

use Moo::Role;
use Cwd;
use Catmandu::Util qw(check_string is_string);
use namespace::clean;

with "Catmandu::Iterable";

has base_dir => (
    is       => "ro",
    isa      => sub {check_string($_[0]);},
    required => 1,
    coerce   => sub {
        is_string($_[0]) ? Cwd::abs_path($_[0]) : $_[0];
    }
);

requires "get";
requires "add";
requires "delete";
requires "delete_all";

1;

__END__

=pod

=head1 NAME

Catmandu::DirectoryIndex - A base role to store relations between id's and directories

=head1 SYNOPSIS

    package MyDirectory;

    use Moo;
    use File::Spec;
    use File:Basename;
    use Path::Tiny qw(path);

    with "Catmandu::DirectoryIndex";

    # translate id to directory
    sub _to_path {
        my ( $self, $id ) = @_;
        File::Spec->catdir( $self->base_dir(), $id );
    }

    sub get {
        my ( $self, $id ) = @_;
        my $path = $self->_to_path( $id );

        is_string( $path ) && -d $path ? { _id => $id, _path => $path } : undef;
    }

    sub add {
        my ( $self, $id ) = @_;
        my $path = $self->_to_path( $id );

        path( $path )->mkpath unless -d $path;

        { _id => $id, _path => $path };
    }

    sub delete {
        my ( $self, $id ) = @_;
        my $path = $self->_to_path( $id );

        if ( is_string( $path ) && -d $path ) {
            path( $path )->remove_tree();
        }
    }

    sub delete_all {
        path( $_[0]->base_dir )->remove_tree({ keep_root => 1 });
    }

    # return a generator that returns list of records, that maps _id and _path
    sub generator {
        my $self = $_[0];
        return sub {
            state $records;

            if ( !defined( $records ) ) {
                $records = [];

                opendir my $dh, $self->base_dir() or die($!);
                while( my $entry = readdir( $dh ) ){
                    if ( -d $entry ) {
                        push @$records, {
                            _id => $entry,
                            _path => File::Spec->catfile( $self->base_dir, $entry )
                        };
                    }
                }
                closedir $dh;
            }

            shift( @$records );
        };
    }

    package main;

    my $p = MyDirectory->new( base_dir => "/tmp" );

    Catmandu->store->bag->each(sub {
        my $r = $_[0];
        my $mapping = $p->get( $r->{_id} ) || $p->add( $r->{_id} );
        say $id . " => " . $mapping->{path};
    });

=head1 CLASS METHODS AVAILABLE

=head2 new( base_dir => $base_dir )

=over

=item base_dir

The base directory where the files are stored. Required

=back

=head1 METHODS AVAILABLE

=over

=item base_dir

=back

=head1 METHODS TO IMPLEMENT

Implementors must implement these methods

=over

=item add( $id ) : $mapping

* Accepts $id as string

* Translates $id to directory path

* Creates directory if necessary

* Returns HASH with keys C<_id> and C<_path>

This method should throw an L<Catmandu::Error> when it detects an invalid id.

It should either return the mapping or throw an error.

=item get( $id ) : $mapping

* Accepts $id as string

* Translates $id to directory path

* Returns HASH with keys C<_id> and C<_path>, if a path exists for $id

This method should throw an L<Catmandu::Error> when it detects an invalid id.

Difference with method "add":

* no directory created

* no mapping returned if no existing directory could be found

=item delete ( $id )

* Accepts id as string

* Translates id to directory

* Removes directory if it exists

* Do other internal cleanup actions if any required

This method should throw an L<Catmandu::Error> when at failure.

=item delete_all()

* Deletes files/directories in base_dir. Please keep the base_dir.

* Do other internal cleanup actions if any required

This method should throw an L<Catmandu::Error> when at failure.

=item generator()

Inherited requirement from L<Catmandu::Iterable>:

* return function reference

* every call to this function must return the next directory entry in the index
as a HASH with keys C<_id> and C<path>

=back

=head1 INHERITED METHODS

This Catmandu::DirectoryIndex inherits:

=over 3

=item L<Catmandu::Iterable>

So all functions from L<Catmandu::Iterable> are available to these objects.

=back

=head1 SEE ALSO

L<Catmandu::Store::File::Simple> ,
L<Catmandu::DirectoryIndex::UUID> ,
L<Catmandu::DirectoryIndex::Number> ,
L<Catmandu::DirectoryIndex::Map>

=cut
