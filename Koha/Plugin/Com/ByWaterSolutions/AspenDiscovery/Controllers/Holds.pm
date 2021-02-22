package Koha::Plugin::Com::ByWaterSolutions::AspenDiscovery::Controllers::Holds;

# This file is part of koha-plugin-aspen-discovery.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Biblio;
use C4::Reserves;

use Koha::Items;
use Koha::Patrons;
use Koha::Holds;
use Koha::DateUtils;

use Try::Tiny;

=head1 API

=head2 Methods

=head3 add

Method that handles adding a new Koha::Hold object

=cut

sub add {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $body = $c->validation->param('body');

        my $biblio;
        my $item;

        my $biblio_id         = $body->{biblio_id};
        my $pickup_library_id = $body->{pickup_library_id};
        my $item_id           = $body->{item_id};
        my $patron_id         = $body->{patron_id};
        my $item_type         = $body->{item_type};
        my $expiration_date   = $body->{expiration_date};
        my $notes             = $body->{notes};
        my $hold_date         = $body->{hold_date};

        if ( !C4::Context->preference('AllowHoldDateInFuture') && $hold_date ) {
            return $c->render(
                status  => 400,
                openapi => { error => "Hold date in future not allowed" }
            );
        }

        if ( $item_id and $biblio_id ) {

            # check they are consistent
            unless ( Koha::Items->search( { itemnumber => $item_id, biblionumber => $biblio_id } )
                ->count > 0 )
            {
                return $c->render(
                    status  => 400,
                    openapi => { error => "Item $item_id doesn't belong to biblio $biblio_id" }
                );
            }
            else {
                $biblio = Koha::Biblios->find($biblio_id);
            }
        }
        elsif ($item_id) {
            $item = Koha::Items->find($item_id);

            unless ($item) {
                return $c->render(
                    status  => 404,
                    openapi => { error => "item_id not found." }
                );
            }
            else {
                $biblio = $item->biblio;
            }
        }
        elsif ($biblio_id) {
            $biblio = Koha::Biblios->find($biblio_id);
        }
        else {
            return $c->render(
                status  => 400,
                openapi => { error => "At least one of biblio_id, item_id should be given" }
            );
        }

        unless ($biblio) {
            return $c->render(
                status  => 404,
                openapi => "Biblio not found."
            );
        }

        my $patron = Koha::Patrons->find( $patron_id );
        unless ($patron) {
            return $c->render(
                status  => 400,
                openapi => { error => 'patron_id not found' }
            );
        }

        # Validate pickup location
        my $valid_pickup_location;
        if ($item) {    # item-level hold
            $valid_pickup_location =
              any { $_->branchcode eq $pickup_library_id }
            $item->pickup_locations(
                { patron => $patron } );
        }
        else {
            $valid_pickup_location =
              any { $_->branchcode eq $pickup_library_id }
            $biblio->pickup_locations(
                { patron => $patron } );
        }

        return $c->render(
            status  => 400,
            openapi => {
                error => 'The supplied pickup location is not valid'
            }
        ) unless $valid_pickup_location;

        my $can_place_hold
            = $item_id
            ? C4::Reserves::CanItemBeReserved( $patron_id, $item_id )
            : C4::Reserves::CanBookBeReserved( $patron_id, $biblio_id );

        if ( $patron->holds->count + 1 > C4::Context->preference('maxreserves') ) {
            $can_place_hold->{status} = 'tooManyReserves';
        }

        unless ( $can_place_hold->{status} eq 'OK' ) {
            return $c->render(
                status => 403,
                openapi =>
                    { error => "Hold cannot be placed. Reason: " . $can_place_hold->{status} }
            );
        }

        my $priority = C4::Reserves::CalculatePriority($biblio_id);

        # AddReserve expects date to be in syspref format
        if ($expiration_date) {
            $expiration_date = output_pref( dt_from_string( $expiration_date, 'rfc3339' ) );
        }

        my $hold_id = C4::Reserves::AddReserve(
            {
                branchcode       => $pickup_library_id,
                borrowernumber   => $patron_id,
                biblionumber     => $biblio_id,
                priority         => $priority,
                reservation_date => $hold_date,
                expiration_date  => $expiration_date,
                notes            => $notes,
                title            => $biblio->title,
                itemnumber       => $item_id,
                found            => undef,                # TODO: Why not?
                itemtype         => $item_type,
            }
        );

        unless ($hold_id) {
            return $c->render(
                status  => 500,
                openapi => 'Error placing the hold. See Koha logs for details.'
            );
        }

        my $hold = Koha::Holds->find($hold_id);

        return $c->render(
            status  => 201,
            openapi => $hold->to_api
        );
    }
    catch {
        if ( blessed $_ and $_->isa('Koha::Exceptions') ) {
            if ( $_->isa('Koha::Exceptions::Object::FKConstraint') ) {
                my $broken_fk = $_->broken_fk;

                if ( grep { $_ eq $broken_fk } keys %{Koha::Holds->new->to_api_mapping} ) {
                    $c->render(
                        status  => 404,
                        openapi => Koha::Holds->new->to_api_mapping->{$broken_fk} . ' not found.'
                    );
                }
            }
        }

        $c->unhandled_exception($_);
    };
}

1;
