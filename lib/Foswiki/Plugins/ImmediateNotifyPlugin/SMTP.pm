package Foswiki::Plugins::ImmediateNotifyPlugin::SMTP;

use strict;
use Foswiki::Net;

my $debug;
my $warning;

sub new {
    my ($class) = @_;

    my $this = bless( {}, $class );

    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;

    &$debug("- SMTP init ");

    return $this;
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $userHash, $info
#    $userHash is a hash reference of the form username->user topic text
#    $info is an extended topicRevisionInfo hash for the saved topic
sub notify {
    my $this     = shift;
    my $userHash = shift;
    my $info     = shift;

    my ($skin) = Foswiki::Func::getPreferencesValue("SKIN");
    my ($template) = Foswiki::Func::readTemplate( 'smtp', 'immediatenotify' );

    # &$debug("- SMTP:  template read $template");
    my ($from) = Foswiki::Func::getPreferencesValue("WIKIWEBMASTER");

    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%WEB%/$info->{web}/go;
    $template =~ s/%TOPICNAME%/$info->{topic}/go;
    $template =~ s/%USER%/$info->{user}/go;
    $template =~ s/%REV%/$info->{version}/go;

    $template =
      Foswiki::Func::expandCommonVariables( $template, $info->{topic},
        $info->{web} );

    foreach my $userName ( keys %$userHash ) {

        my ($to);
        &$debug("- SMTP: userName $userName");
        my @emails = Foswiki::Func::wikinameToEmails($userName);
        foreach my $email (@emails) {
            $to .= $email . ",";
        }
        if ($to) {
            my $msg = $template;
            $msg =~ s/%EMAILTO%/$to/go;
            &$debug("- SMTP: Sending mail to $to ($userName)");
            &$debug("- SMTP: MESSAGE ($msg)");

            my $error = &Foswiki::Func::sendEmail($msg);

            &$debug("- SMTP: Error ($error)") if ($error);
        }

    }
}

sub connect {
    return 1;
}

sub disconnect {
    return 1;
}

1;
