package Koha::Plugin::Com::ByWaterSolutions::AspenDiscovery::ApiController;

# This file is part of Koha.
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

use Koha::Items;
use Koha::DateUtils;

use Try::Tiny;

sub list_item_messages {
    require Koha::Item::Message;
    require Koha::Item::Messages;

    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->validation->param('item_id');

    if ( !Koha::Items->search({ itemnumber => $itemnumber })->count > 0 ) {
        return $c->render(
            status => 400,
            openapi => { error => 'Item not found' }
        );
    }

    return try {
        my $item_messages = Koha::Item::Messages->search({ itemnumber => $itemnumber });
        return $c->render( status => 200, openapi => $item_messages );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render(
                status => 500,
                openapi => { error => $_->{msg} }
            );
        }
        else {
            return $c->render(
                status => 500,
                openapi => { error => "Something went wrong, check the logs." }
            );
        }
    };
}

sub get_item_message {
    require Koha::Item::Message;
    require Koha::Item::Messages;

    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->validation->param('item_id');
    my $item_message_id = $c->validation->param('item_message_id');

    if ( !Koha::Items->search( { itemnumber => $itemnumber } )->count > 0 ) {
        return $c->render(
            status => 400,
            openapi => { error => "Item not found" }
        );
    }

    return try {
        my $item_message
            = Koha::Item::Messages->search(
            { itemnumber => $itemnumber, item_message_id => $item_message_id } )
            ->next;
        if ($item_message) {
            return $c->render( status => 200, openapi => $item_message );
        }
        else {
            return $c->render( status => 400, openapi => { error => 'Item message not found' } );
        }
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render( status => 500, openapi => { error => $_->{msg} } );
        }
        else {
            return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
        }
    };
}

sub add_item_message {
    require Koha::Item::Message;
    require Koha::Item::Messages;

    my $c = shift->openapi->valid_input or return;

    my $itemnumber = $c->validation->param('item_id');
    my $body       = $c->validation->param('body');

    my $item_message = Koha::Item::Message->new( $body );
    $item_message->itemnumber( $itemnumber );

    return try {
        $item_message->store();
        $item_message = Koha::Item::Messages->find( $item_message->id );
        return $c->render( status => 200, openapi => $item_message );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render( status => 500, openapi => { error => $_->{msg} } );
        }
        else {
            return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
        }
    };
}

sub update_item_message {
    my $c = shift->openapi->valid_input or return;

    my $itemnumber      = $c->validation->param('item_id');
    my $item_message_id = $c->validation->param('item_message_id');
    my $body            = $c->validation->param('body');

    my $item_message;

    return try {
        $item_message
            = Koha::Item::Messages->search(
            { itemnumber => $itemnumber, item_message_id => $item_message_id } )
            ->next;
        $item_message->set( $body );
        $item_message->store();
        return $c->render( status => 200, openapi => $item_message );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render( status => 500, openapi => { error => $_->{msg} } );
        }
        else {
            return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
        }
    };

}

sub delete_item_message {
    require Koha::Item::Message;
    require Koha::Item::Messages;

    my $c = shift->openapi->valid_input or return;

    my $itemnumber      = $c->validation->param('item_id');
    my $item_message_id = $c->validation->param('item_message_id');

    my $item_message;

    return try {
        $item_message = Koha::Item::Messages->search(
            { itemnumber => $itemnumber, item_message_id => $item_message_id } );
        $item_message->delete;
        return $c->render( status => 200, openapi => $item_message );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render( status => 500, openapi => { error => $_->{msg} } );
        }
        else {
            return $c->render( status => 500, openapi => { error => "Something went wrong, check the logs." } );
        }
    };
}

sub get_item_message_types {
    my $c = shift->openapi->valid_input or return;

    my $authorised_values = Koha::AuthorisedValues->search({ category => 'ITEM_MESSAGE_TYPE' })->unblessed;

    return $c->render( status => 200, openapi => $authorised_values );
}

1;
