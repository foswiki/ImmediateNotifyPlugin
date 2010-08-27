# Immediate Notify Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2003 Walter Mundt, emage@spamcop.net
# Copyright (C) 2003 Akkaya Consulting GmbH, jpabel@akkaya.de
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This plugin supports immediate notification of topic saves.
#
# =========================
package Foswiki::Plugins::ImmediateNotifyPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb
  $debug );

use Data::Dumper;

our $VERSION           = '$Rev$';
our $RELEASE           = 'v0.4 (testing)';
our $NO_PREFS_IN_TOPIC = 1;

my %methodHandlers;

sub debug { Foswiki::Func::writeDebug(@_) if $debug; }

sub warning {
    Foswiki::Func::writeWarning(@_);
    debug( "WARNING" . $_[0], @_[ 1 .. $#_ ] );
}

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.011 ) {
        warning(
            "Version mismatch between ImmediateNotifyPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesFlag("DEBUG") || 0;

    _loadHandlers();

    unless (%methodHandlers) {
        warning(
"- ImmediateNotifyPlugin: No methods available, initialization failed"
        );
        return 0;
    }

    # Plugin correctly initialized
    debug(
"- Foswiki::Plugins::ImmediateNotifyPlugin::initPlugin( $web.$topic ) is OK"
    );
    return 1;
}

sub _loadHandlers {

    my $methods = Foswiki::Func::getPluginPreferencesValue("METHODS");
    if ( !defined($methods) ) {
        warning(
"- ImmediateNotifyPlugin: No METHODS defined in site preferences topic, defaulting to SMTP"
        );
        $methods = "SMTP";
    }

    %methodHandlers = ();
    foreach $method ( split ' ', $methods ) {
        debug("- ImmediateNotifyPlugin: Loading method $method...");
        $modulePresent =
          eval { require "Foswiki/Plugins/ImmediateNotifyPlugin/$method.pm"; 1 };
        unless ( defined($modulePresent) ) {
            warning("- ImmediateNotifyPlugin::$method failed to load: $@");
            debug("- ImmediateNotifyPlugin::$method failed to load: $@");
            next;
        }

        my $module = "Foswiki::Plugins::ImmediateNotifyPlugin::${method}::";
        if ( eval $module . 'initMethod($topic, $web, $user)' ) {
            $methodHandlers{$method} = eval '\&' . $module . 'handleNotify';
        }
        else {
            debug("- ImmediateNotifyPlugin: initMethod failed");
        }

        if ( defined( $methodHandlers{$method} ) ) {
            debug("- ImmediateNotifyPlugin::$method OK");
        }
        else {
            warning("- ImmediateNotifyPlugin::$method failed to load");
        }
    }
}

sub processName {
    my ( $name, $users, $groups ) = @_;
    debug("- ImmediateNotifyPlugin: Processing name $name");
    return if ( length($name) == 0 );

    # SMELL:  We can't use Preferences API to retrieve user topic information.
    # API requires that topic be readable by current user,  but we can't
    # be sure of that - and user topics are often protected.

    if ( Foswiki::Func::isGroup($name) ) {
        return if exists $groups->{$name};    # don't reprocess groups

        $groups->{$name} = $name;

        my $it = Foswiki::Func::eachGroupMember($name);
        while ( $it->hasNext() ) {
            my $user = $it->next();
            processName( $user, $users, $groups );
        }
    }
    else {
        my ( $meta, $text ) =
          Foswiki::Func::readTopic( "$Foswiki::cfg{UsersWebName}", "$name" );
        $users->{$name}{TEXT} = $text;
    }
}

# =========================
sub afterSaveHandler {
    my ( $text, $topic, $web, $error ) = @_;

# This handler is called by Foswiki::Store::saveTopic just after the save action.

    debug("- ImmediateNotifyPlugin::afterSaveHandler( $_[2].$_[1] )");

    if ($error) {
        debug("- ImmediateNotifyPlugin: Unsuccessful save, not notifying...");
        return;
    }

# SMELL:  We should not have to parse out topic text.  But the old preferences
# cache is still loaded in the afterSaveHandler.   So we would miss changes made
# to the IMMEDIATENOTIFY setting in this save.
#my $nameString = Foswiki::Func::getPreferencesValue('IMMEDIATENOTIFY') || '';

    my @names;
    $IMREGEX =
qr/$Foswiki::regex{setRegex}(?:IMMEDIATENOTIFYPLUGIN_)?IMMEDIATENOTIFY\s*=\s*(.*?)$/sm;

    if ( $text =~ /$IMREGEX/ ) {
        debug("- ImmediateNotifyPlugin: Found ($2) ");
        my $nameString = $2;
        chomp $nameString;
        @names = split /[\s,]+/, $nameString;
        foreach $n (@names) {
            debug(
"- ImmediateNotifyPlugin: ($n) found in IMMEDIATENOTIFY in topic text"
            );
        }
    }

    my $notifyTopic =
      Foswiki::Func::readTopicText( $web, "WebImmediateNotify" );
    debug("- ImmediateNotifyPlugin: no WebImmediateNotify topic found in $web")
      unless ($notifyTopic);

    while ( $notifyTopic =~
/(\t+|(   )+)\* (?:\%MAINWEB\%|$Foswiki::cfg{UsersWebName})\.([^\r\n]+)/go
      )
    {
        push @names, $3 if $3;
        debug("- ImmediateNotifyPlugin: Adding $3") if ($3);
    }

    unless ( scalar @names ) {
        debug("- ImmediateNotifyPlugin: No names registered for notification.");
        return;
    }

    my ( %users, %groups );
    foreach my $name (@names) {
        processName( $name, \%users, \%groups );
    }

    my ( %userTopics, %userMethods );
    foreach my $user ( keys %users ) {
        debug("- ImmediateNotifyPlugin processing Users: $user");
        unless ( defined( $users{$user} ) && length( $users{$user} ) > 0 ) {
            warning(
"- ImmediateNotifyPlugin: User topic \"$Foswiki::cfg{UsersWebName}.$user\" not found!"
            );
            next;
        }

        my @methodList = {};
        if ( $users{$user}{TEXT} =~
            /(\t+|(   )+)\* Set IMMEDIATENOTIFYMETHOD = ([^\r\n]+)/ )
        {
            @methodList = split / *[, ] */, $3;
        }
        else {
            @methodList = ("SMTP");
        }
        if ( scalar @methodList ) {
            debug("- ImmediateNotifyPlugin: User $user: @methodList");
        }

        #elsif ( !exists( $group{$member} ) ) {
        else {
            debug(
"- ImmediateNotifyPlugin: User $user chosen no methods, defaulting to SMTP."
            );
            @methodList = ("SMTP");
        }
        foreach my $method (@methodList) {
            $userMethods{$user}{$method} = 1;
            debug("- ImmediateNotifyPlugin: Set method to $method for $user ");
        }
    }

    foreach my $method ( keys %methodHandlers ) {
        debug("- Processing methods $method");
        my %methodUsers =
          map { $userMethods{$_}{$method} ? ( $_, \$users{$_} ) : () }
          keys %users;
        my @userList =
          keys %methodUsers;  # save current key list, so we can modify the hash

        debug( "- ImmediateNotifyPlugin: $method userlist "
              . join( " ", keys %methodUsers ) );
        if (%methodUsers) {
            &{ $methodHandlers{$method} }( \%methodUsers );
        }
    }
}

1;
