#!/usr/bin/env perl

# blaze-config, display or set the BlazeBlogger repository options
# Copyright (C) 2008, 2009 Jaromir Hradilek

# This program is  free software:  you can redistribute it and/or modify it
# under  the terms  of the  GNU General Public License  as published by the
# Free Software Foundation, version 3 of the License.
# 
# This program  is  distributed  in the hope  that it will  be useful,  but
# WITHOUT  ANY WARRANTY;  without  even the implied  warranty of MERCHANTA-
# BILITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
# License for more details.
# 
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use File::Basename;
use File::Spec::Functions;
use Config::IniHash;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.0.1';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $verbose = 1;                                   # Verbosity level.

# List of valid options:
our %options = (
  # Blog related settings:
  'blog.title'     => "Blog title.",
  'blog.subtitle'  => "Blog subtitle.",
  'blog.theme'     => "Blog theme; the .html suffix can be omitted.",
  'blog.style'     => "Blog stylesheet; the .css suffix can be omitted.",

  # Core settings:
  'core.editor'    => "Text editor to be used for editing purposes.",
  'core.encoding'  => "File encoding in a form recognized by HTML 4.01.",
  'core.extension' => "File extension for the generated pages.",

  # User related settings:
  'user.name'      => "User's name to be used as a default posts' author.",
  'user.email'     => "User's e-mail; not to be used anywhere so far.",
);

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An unspecified error has occured.';
  my $return_value = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $return_value;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message to the STDOUT:
  print << "END_HELP";
Usage: $NAME [-qV] [-b directory] name [value...]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -q, --quiet                 avoid displaying unnecessary messages
  -V, --verbose               display all messages; the default option
  -h, --help                  display this help and exit
  -v, --version               display version information and exit
END_HELP

  # Return success:
  return 1;
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Print the message to the STDOUT:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008, 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'quiet|q'       => sub { $verbose = 0;     },
  'verbose|V'     => sub { $verbose = 1;     },
  'blogdir|b=s'   => sub { $blogdir = $_[1]; },
);

# Check missing options::
exit_with_error("Missing option.", 22) if (scalar(@ARGV) == 0);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.", 1)
  unless (-d catdir($blogdir, '.blaze'));

# Read the configuration file:
my $filename = catfile($blogdir, '.blaze', 'config');
my $config   = ReadINI($filename)
               or exit_with_error("Unable to read `$filename'.", 13);

# Check whether the option is valid:
if (exists $options{$ARGV[0]}) {
  # Get option key pair:
  my ($section, $key) = split(/\./, shift(@ARGV));

  # Decide whether to get or set the value:
  if (scalar(@ARGV) != 0) {
    # Use the rest of the arguments as a value:
    $config->{$section}->{$key} = join(' ', @ARGV);

    # Save the configuration file:
    WriteINI($filename, $config)
      or exit_with_error("Unable to write to `$filename'.", 13);

    # Report success: 
    print "The option has been successfully saved.\n" if $verbose;
  }
  else {
    # Check whether the option is set:
    if (my $value = $config->{$section}->{$key}) {
      # Display the value:
      print "$value\n";
    }
    else {
      # Return failure:
      exit 1;
    }
  }
}
else {
  # Report failure:
  exit_with_error("Invalid option `$ARGV[0]'.", 22);
}

# Return success:
exit 0;

__END__

=head1 NAME

blaze-config - display or set the BlazeBlogger repository options

=head1 SYNOPSIS

B<blaze-config> [B<-qV>] [B<-b> I<directory>] I<name> [I<value...>]

B<blaze-config> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-config> is a simple configuration tool for the BlazeBlogger.
Depending on the number of given command-line arguments, it either displays
the current value of the specified option, or sets/replaces it with the new
one.

The accepted option I<name> is in the form of dot separated section and key
(e.g. user.name). For the complete list of available options along with the
explanation of their meaning, see the appropriate section below.

=head1 OPTIONS

=head2 Command-line options

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages. This is the default option.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head2 Available option names

=over

=item B<blog.title>

Blog title.

=item B<blog.subtitle>

Blog subtitle, supposedly a brief, single-line description of what should
an occasional visitor expect to find.

=item B<blog.theme>

Blog theme; the value should point to an existing file in the .blaze/theme
directory, although the .html extension can be safely omitted.

=item B<blog.style>

Blog stylesheet; the value should point to an existing file in the
.blaze/style directory, although the .css extension can be safely omitted.

=item B<core.editor>

Text editor to be used for editing purposes.

=item B<core.encoding>

Records encoding in the form recognised by the W3C HTML 4.01 standard (e.g.
the default UTF-8).

=item B<core.extension>

File extension for the generated pages. By default, the `html' is used as a
reasonable choice.

=item B<user.name>

User's name to be used as a default posts' author and in the copyright
notice.

=item B<user.email>

User's e-mail; so far, this option is not actually used anywhere.

=back

=head1 FILES

=over

=item I<.blaze/config>

BlazeBlogger configuration file.

=back

=head1 SEE ALSO

B<perl>(1).

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the BlazeBlogger source package.

=head1 COPYRIGHT

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
