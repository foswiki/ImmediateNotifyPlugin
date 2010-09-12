package Foswiki::Plugins::ImmediateNotifyPlugin::SMTP;

use strict;
use Foswiki::Net;

use vars
  qw($user $pass $server $wikiuser $web $topic $debug $warning $sendEmail);

# ========================
# initMethed - initializes a single notification method
sub initMethod {

    $server = $Foswiki::cfg{SMTP}{MAILHOST}
      || Foswiki::Func::getPreferencesValue("SMTPMAILHOST");
    $debug   = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;
    return defined($server);
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $userHash, $web, $topic, $wikiuser
#    $userHash is a hash reference of the form username->user topic text
#    $web is the web in which the topic is stored
#    $topic is the current topic
#    $wikiuser is the logged-in user who saved the topic
sub handleNotify {
    my $userHash = shift;
    my $web      = shift;
    my $topic    = shift;
    my $wikiuser = shift;
    my ($skin)   = Foswiki::Func::getPreferencesValue("SKIN");
    my ($template) = Foswiki::Func::readTemplate( 'smtp', 'immediatenotify' );

    # &$debug("- SMTP:  template read $template");
    my ($from) = Foswiki::Func::getPreferencesValue("WIKIWEBMASTER");

    $template =~ s/%EMAILFROM%/$from/go;
    $template =~ s/%WEB%/$web/go;
    $template =~ s/%TOPICNAME%/$topic/go;
    $template =~ s/%USER%/$wikiuser/go;

    $template = Foswiki::Func::expandCommonVariables( $template, $topic, $web );

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

            my $error = &Foswiki::Func::sendEmail( $msg );

            &$debug("- SMTP: Error ($error)") if ($error);
        }

    }
}

1;
