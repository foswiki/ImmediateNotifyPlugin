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
use strict;
use warnings;

use Data::Dumper;

our $VERSION           = '$Rev$';
our $RELEASE           = 'v1.0RC';
our $NO_PREFS_IN_TOPIC = 1;

our $debug;

my %methodHandlers;    # Loaded handlers
my %methodAllowed;     # Methods permitted by config.

# Regular expressions used in topic processing

my $NOTIFYREGEX =
qr/$Foswiki::regex{setRegex}(?:IMMEDIATENOTIFYPLUGIN_)?IMMEDIATENOTIFY\s*=\s*(.*?)$/sm;

my $METHODREGEX =
qr/$Foswiki::regex{setRegex}(?:IMMEDIATENOTIFYPLUGIN_)?IMMEDIATENOTIFYMETHOD\s*=\s*(.*?)(?:\((.*?)\))?\s*$/sm;

sub debug { Foswiki::Func::writeDebug(@_) if $debug; }

sub warning {
    Foswiki::Func::writeWarning(@_);
    debug( "WARNING" . $_[0], @_[ 1 .. $#_ ] );
}

# =========================
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;
    my $methodCount = 0;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.011 ) {
        warning(
            "Version mismatch between ImmediateNotifyPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPluginPreferencesFlag("DEBUG") || 0;

    # Find any configured methods and make available.
    foreach my $method ( keys %{$Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}} ) {
        next if ($method eq "Module" );
        next if ($method eq "Enabled" );
        if ( $Foswiki::cfg{Plugins}{ImmediateNotifyPlugin}{$method}{Enabled} ) {
            debug("Allowing method $method");
            $methodAllowed{$method} = 1;
            $methodCount++;
        }
    }

    # Plugin correctly initialized
    if ($methodCount) {
        debug(
"- Foswiki::Plugins::ImmediateNotifyPlugin::initPlugin( $web.$topic ) is OK"
        );
        return 1;
    }
    else {
        warning("ImmediateNotifyPlugin - no methods enabled");
        return 0;
    }
}

sub finishPlugin {

    debug("finishPlugin entered");
    foreach my $handler (%methodHandlers) {
        next unless $handler;
        $methodHandlers{$handler}->disconnect();
        $methodHandlers{$handler} = '';
    }
}

sub _loadHandler {
    my $method = shift;
    return 1 if $methodHandlers{$method};    # Already loaded

    my $handler;

    if ( $methodAllowed{$method} ) {
        debug("- ImmediateNotifyPlugin: Loading method $method...");

        my $module = 'Foswiki::Plugins::ImmediateNotifyPlugin::' . $method;
        eval {
            ( my $file = $module ) =~ s|::|/|g;
            require $file . '.pm';
            $handler = $module->new();
            1;
          }
          or do {
            print STDERR "FAILED TO LOAD  $@";
            warning("- ImmediateNotifyPlugin::$method failed to load $@ $!");
            return 0;
          };

        if ( $handler->connect() ) {
            $methodHandlers{$method} = $handler;
            debug("- ImmediateNotifyPlugin::$method OK");
            return 1;
        }
        else {
            warning("- ImmediateNotifyPlugin::$method failed to load $@ $!");
            return 0;
        }
    }
    else {
        warning(
            "- ImmediateNotifyPlugin::$method not permitted by configuration!");
        return 0;
    }
}

sub processName {
    my ( $name, $users, $groups ) = @_;

    debug("- ImmediateNotifyPlugin: Processing name $name");
    return if exists $users->{$name};    # Already saw this name - skip it.

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

      # SMELL:  We can't use Preferences API to retrieve user topic information.
      # API requires that topic be readable by current user,  but we can't
      # be sure of that - and user topics are often protected.

        my ( $meta, $text ) =
          Foswiki::Func::readTopic( "$Foswiki::cfg{UsersWebName}", "$name" );
        if ($text) {
            $users->{$name}{TEXT} = $text;

            if ( $text =~ /$METHODREGEX/ ) {
                my $parms = $3 || '';
                debug(
"- ImmediateNotifyPlugin: processName: User $name found method ($2) parms ($parms) "
                );
                $users->{$name}{METHOD} = $2;
                $users->{$name}{PARMS}  = $parms;
            }
            else {
                $users->{$name}{METHOD} = 'SMTP';
                debug(
"- ImmediateNotifyPlugin: processName: User $name chosen no methods, defaulting to SMTP."
                );
            }
        }
        else {
            warning(
"- ImmediateNotifyPlugin: $name not found as a user or group, ignored"
            );
        }
    }
}

# =========================
sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $topicObject ) = @_;
    my $user = Foswiki::Func::getWikiName();

    my $topicInfo = $topicObject->getRevisionInfo();
    $topicInfo->{topic} = $topic;
    $topicInfo->{web}   = $web;
    $topicInfo->{user}  = $user;

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

# Check if the topic contains an IMMEDIATENOTIFY setting and extract names if present
    if ( $text =~ /$NOTIFYREGEX/ ) {
        debug("- ImmediateNotifyPlugin: Found ($2) ");
        my $nameString = $2;
        chomp $nameString;
        @names = split /[\s,]+/, $nameString;
        foreach my $n (@names) {
            debug(
"- ImmediateNotifyPlugin: ($n) found in IMMEDIATENOTIFY in topic text"
            );
        }
    }

    # Retrieve the WebImmediateNotify topic and extract names
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

    # Recursively expand all users / groups into a list of names to notify
    my ( %users, %groups );
    foreach my $name (@names) {
        processName( $name, \%users, \%groups );
    }

    # Extract required methods from the users list and lazy load them
    my %userMethods;
    foreach my $user ( keys %users ) {
        debug("- ImmediateNotifyPlugin processing Users: $user");

        my @methodList = {};
        @methodList = ( $users{$user}{METHOD} );

        foreach my $method (@methodList) {
            if ( _loadHandler($method) ) {
                $userMethods{$user}{$method} = 1;
                debug(
"- ImmediateNotifyPlugin: Handler loaded - Set method to $method for $user "
                );
            }
        }
    }

    foreach my $method ( keys %methodHandlers ) {
        debug("- Processing methods $method");

        #my %methodUsers =
        #  map { $userMethods{$_}{$method} ? ( $_, \$users{$_} ) : () }
        #  keys %users;

        my %methodUsers;
        foreach my $k ( keys %users ) {
            if ( $userMethods{$k}{$method} ) {
                $methodUsers{$k} = $users{$k};
            }
        }

        debug( "- ImmediateNotifyPlugin: $method userlist "
              . join( " ", keys %methodUsers ) );
        if (%methodUsers) {
            $methodHandlers{$method}->notify( \%methodUsers, $topicInfo );
        }
    }
}

1;
