package BBS::Perm::Term;

use warnings;
use strict;
use Carp;
use Glib qw/TRUE FALSE/;
use Gnome2::Vte;
use version; our $VERSION = qv('0.0.1');

sub new {
    my ( $class, %opt ) = @_;
    my $self = {%opt};
    $self->{widget} = Gtk2::HBox->new unless $self->{widget};
    $self->{terms}  = [];
    $self->{titles} = [];
    bless $self, ref $class || $class;
}

sub init {    # initiate a new term
    my ( $self, $conf ) = @_;
    my $term = Gnome2::Vte::Terminal->new;

    if ( $conf->{encoding} ) {
        $term->set_encoding( $conf->{encoding} );
    }

    if ( $conf->{font} && $conf->{font}{family} && $conf->{font}{size} ) {
        my $font = Gtk2::Pango::FontDescription->new;
        $font->set_family( $conf->{font}{family} );
        $font->set_size( $conf->{font}{size} * 1000 );
        $term->set_font_full( $font,
            $conf->{font}{anti_alias} || 'force_disable' );
    }
#    it doesn't work, I think it's the problem of Gnome2::Vte or vtelib.
#    if ( $conf->{color} ) {
#        my @elements = qw/foreground background dim bold cursor highlight/;
#        for (@elements) {
#            if ( $conf->{color}{$_} ) {
#                no strict 'refs';
#                "Gnome2::Vte::Terminal::set_color_$_"->(
#                    $term, Gtk2::Gdk::Color->parse($conf->{color}{$_})
#                );
#            }
#        }
#    }

    if ( $conf->{background_file} && -e $conf->{background_file} ) {
        $term->set_background_image_file( $conf->{background_file} );
    }

    if ( $conf->{background_transparent} ) {
        $term->set_background_transparent(1);
    }

    if ( defined $conf->{mouse_autohide} ) {
        $term->set_mouse_autohide($conf->{mouse_autohide});
    }

    my $timeout = $conf->{timeout} || 60;
    $term->{timer} = Glib::Timeout->add( 1000 * $timeout,
        sub { $term->feed_child( chr 0 ); return TRUE; }, $term );
    push @{ $self->{terms} },  $term;
    push @{ $self->{titles} }, $conf->{title}
        || $conf->{username} . '@' . $conf->{site};

    if ( defined $self->{current} ) {    # has term already?
        $self->term->hide;
    }

    $self->{current} = $#{ $self->{terms} };
    $self->widget->pack_start( $self->term, TRUE, TRUE, 0 );
    $self->term->show;
    $self->term->grab_focus;
}

sub clean {                              # called when child exited
    my $self = shift;
    my ( $current, $new_pos );
    $new_pos = $current = $self->{current};
    if ( @{ $self->{terms} } > 1 ) {
        if ( $current == @{ $self->{terms} } - 1 ) {
            $new_pos = 0;
        }
        else {
            $new_pos++;
        }
        $self->term->hide;
        $self->{terms}->[$new_pos]->show;
        $self->{terms}->[$new_pos]->grab_focus;
    }
    else {
        undef $new_pos;
    }
    $self->widget->remove( $self->term );
    $self->term->destroy;
    splice @{ $self->{terms} }, $current, 1;
    $self->{current} = $new_pos == 0 ? 0 : $new_pos - 1
        if defined $new_pos;
}

sub term {    # get current terminal
    my $self = shift;
    return $self->{terms}->[ $self->{current} ]
        if defined $self->{current};
}

sub switch {    # switch terms, -1 for left, 1 for right
    my ( $self, $offset ) = @_;
    return unless $offset;
    return unless @{ $self->{terms} } > 1;

    my ( $current, $new_pos );
    $new_pos = $current = $self->{current};

    if ( $offset == 1 ) {
        if ( $current >= @{ $self->{terms} } - 1 ) {
            $new_pos = 0;
        }
        else {
            $new_pos++;
        }
    }
    elsif ( $offset == -1 ) {
        if ( $current == 0 ) {
            $new_pos = @{ $self->{terms} } - 1;
        }
        else {
            $new_pos--;
        }
    }
    $self->term->hide if defined $self->term;
    $self->{current} = $new_pos;
    if ( $self->term ) {
        $self->term->show;
        $self->term->grab_focus;
    }
}

sub connect {
    my ( $self, $conf, $file, $site ) = @_;
    if ( $conf->{agent} ) {
        $self->term->fork_command( $conf->{agent},
            [ $conf->{agent}, $file, $site ],
            undef, q{}, FALSE, FALSE, FALSE );
    }
    else {
        croak 'seems something wrong with your agent script';
    }
}

sub title {
    my $self = shift;
    return $self->{titles}[ $self->{current} ];
}

sub text {    # get current terminal's text
              # list context is needed.
    my $self = shift;
    if ( $self->term ) {
        my ($text) = $self->term->get_text( sub { return TRUE } );
        return $text;
    }
}

sub widget {
    return shift->{widget};
}

# add methord for all the keys of %$self

1;

__END__

=head1 NAME

BBS::Perm::Term - a multi terminals component based on Vte


=head1 VERSION

This document describes BBS::Perm::Term version 0.0.1


=head1 SYNOPSIS

    use BBS::Perm::Term;
    my $term = BBS::Perm::Term->new( widget => Gtk2::HBox->new );

=head1 DESCRIPTION
    
L<BBS::Perm::Term> is a Gnome's Vte based terminal, mainly for BBS::Perm.
In fact, it's a transperant wrapper to Gnome2::Vte.

=head1 INTERFACE

=over 4

=item new( %option )

create a new BBS::Perm::Term object.
%option could have these keys:

=over 4

=item widget => $container_widget

$container_widget is a Gtk2::HBox or Gtk2::VBox object, which will be the
container of our terminals.

=item agent => $agent_command

designate where is your agent script, default is 'bbs-perm-agent'. 

$agent_command will be called as "$agent_command $file $sitename",
where $file and $sitename have the same meanings as BBS::Perm::Config's,
so your script can get enough information given these two arguments.

=back

=item term

return the current terminal, which is a Gnome2::Vte::Terminal object, so you can
do anything a Gnome2::Vte::Terminal object can do, ;-)

=item init( $conf )

initiate the terminal to be our `current' terminal. 
$conf is the same as the return value of BBS::Perm::Config object's
setting method.

=item connect

let the current terminal connect to the BBS server.

=item switch( $direction )

our object could have many Gnome2::Vte::Terminal objects, this method help us
switch among them, choosing some as the current terminal.
-1 for left, 1 for right.

=item title

get current terminal's title.

=item text

get current terminal's text. ( just plain text, not a colorful one, ;-)

=item clean

when an agent script exited, this method will be call, for cleaning, of cause.

=back

=head1 DEPENDENCIES

L<Gnome2::Vte>, L<Gtk2>, L<version> 

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

You can't set colors for Gnome2::Vte::Terminal object right now, at least this
doesn't work to me.
Anyway, hey, the default color scheme is pretty enough, isn't?

=head1 AUTHOR

sunnavy  C<< <sunnavy@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, sunnavy C<< <sunnavy@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

