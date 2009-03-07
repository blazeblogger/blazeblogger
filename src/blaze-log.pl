#!/usr/bin/env perl

# blaze-log, show the repository log
# Copyright (C) 2009 Jaromir Hradilek

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
use Text::Wrap;
use File::Basename;
use File::Spec::Functions;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.7.1';                    # Script version.

# General script settings:
our $blogdir    = '.';                              # Repository location.
our $verbose    = 1;                                # Verbosity level.

# Command-line options:
my  $type       = 0;                                # Log display type.

# Set up the __WARN__ signal handler:
$SIG{__WARN__}  = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An unspecified error has occurred.';
  my $return_value = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $return_value;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message to the STDOUT:
  print << "END_HELP";
Usage: $NAME [-qsV] [-b directory]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -s, --short                 display each log record on a single line
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

Copyright (C) 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Display log records:
sub display_log {
  my $type = shift || 0;
  my $file = catfile($blogdir, '.blaze', 'log');

  # Open the log file for reading:
  open(LOG, "$file") or return 0;

  # Process each record:
  while (my $record = <LOG>) {
    # Decide which type of display to use:
    unless ($type) {
      # Decompose the record:
      my ($date, $message) = split(/\s+-\s+/, $record, 2);

      # Display the full record:
      print "Date: $date\n\n";
      print wrap('    ', '    ', $message);
      print "\n";
    }
    else {
      # Display the short record:
      print $record;
    }
  }

  # Close the file:
  close(LOG);

  # Return success:
  return 1;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'short|s'       => sub { $type    = 1;      },
  'quiet|q'       => sub { $verbose = 0;      },
  'verbose|V'     => sub { $verbose = 1;      },
  'blogdir|b=s'   => sub { $blogdir = $_[1];  },
);

# Detect superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Display log records:
display_log($type) or exit_with_error("Unable to read log file.", 13);

# Return success:
exit 0;

__END__

=head1 NAME

blaze-log - show the repository log

=head1 SYNOPSIS

B<blaze-log> [B<-qsV>] [B<-b> I<directory>]

B<blaze-log> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-log> displays the content of the BlazeBlogger repository log.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-s>, B<--short>

Display each log record on a single line.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages. This is the default option.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 FILES

=over

=item I<.blaze/log>

BlazeBlogger repository log file.

=back

=head1 SEE ALSO

B<perl>(1).

=head1 BUGS

To report bugs please visit the appropriate section on the project
homepage: <http://code.google.com/p/blazeblogger/issues/>.

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the BlazeBlogger source package.

=head1 COPYRIGHT

Copyright (C) 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
