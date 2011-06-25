# ---+ Extensions
# ---++ ImmediateNotifyPlugin
# **BOOLEAN**
# Enable SMTP for mailing messages. Note:  This plugin uses Foswiki core email support for sending
# notifications.  See the "Mail and Proxies" tab for the configuration.
$Foswiki::cfg{ImmediateNotifyPlugin}{SMTP}{Enabled} = $FALSE;

# **REGEX**
# Define the regular expression that an email address entered in WebNotify
# must match to be identified as a legal email by the notifier. You can use
# this expression to - for example - filter email addresses on your company
# domain.<br />
# If this is not defined, then the default setting of
# <code>[A-Za-z0-9.+-_]+\@[A-Za-z0-9.-]+</code> is used.
$Foswiki::cfg{ImmediateNotifyPlugin}{SMTP}{EmailFilterIn} = '';

# **BOOLEAN**
# Enable XMPP (Jabber) for notifications.
$Foswiki::cfg{ImmediateNotifyPlugin}{Jabber}{Enabled} = $FALSE;

# **STRING 30**
# Hostname of the XMPP / Jabber server
$Foswiki::cfg{ImmediateNotifyPlugin}{Jabber}{Server} = '';

# **STRING 30**
# Username for the Jabber account used by the ImmediateNotifyPlugin.  If configured here, the
# topic based setting will be ignored.
$Foswiki::cfg{ImmediateNotifyPlugin}{Jabber}{Username} = '';

# **PASSWORD 30**
# Password for the Jabber account used by the ImmediateNotifyPlugin.  If configured here, the
# topic based setting will be ignored.
$Foswiki::cfg{ImmediateNotifyPlugin}{Jabber}{Password} = '';

