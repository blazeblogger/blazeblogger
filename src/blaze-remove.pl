#!/usr/bin/env perl

# blaze-remove, remove a post/page from the BlazeBlogger repository
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
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.9.1';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $verbose = 1;                                   # Verbosity level.
our $prompt  = 0;                                   # Ask for confirmation?

# Command-line options:
my  $type    = 'post';                              # Type: post or page.
my  $removed = '';                                  # List of removed IDs.

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An unspecified error has occurred.';
  my $return_value = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $return_value;
}

# Display given warning message:
sub display_warning {
  my $message = shift || 'An unspecified warning was requested.';

  print STDERR "$message\n";
  return 1;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message to the STDOUT:
  print << "END_HELP";
Usage: $NAME [-fipqPV] [-b directory] id...
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -p, --page                  remove pages instead of blog posts
  -P, --post                  remove blogs posts; the default option
  -i, --interactive           prompt before removal
  -f, --force                 do not prompt; the default option
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

# Add given string to the log file
sub add_to_log {
  my $text = shift || 'Something miraculous has just happened!';

  # Prepare the log file name:
  my $file = catfile($blogdir, '.blaze', 'log');

  # Open the log file for appending:
  open(LOG, ">>$file") or return 0;

  # Write to the log file:
  print LOG localtime(time) . " - $text\n";

  # Close the file:
  close(LOG);

  # Return success:
  return 1;
}

# Read data from the INI file:
sub read_ini {
  my $file    = shift || die 'Missing argument';

  # Initialize required variables:
  my $hash    = {};
  my $section = 'default';

  # Open the file for reading:
  open(INI, "$file") or return 0;

  # Process each line:
  while (my $line = <INI>) {
    # Parse line:
    if ($line =~ /^\s*\[([^\]]+)\]\s*$/) {
      # Change the section:
      $section = $1;
    }
    elsif ($line =~ /^\s*(\S+)\s*=\s*(\S.*)$/) {
      # Add option to the hash:
      $hash->{$section}->{$1} = $2;
    }
  }

  # Close the file:
  close(INI);

  # Return the result:
  return $hash;
}

# Remove given records from the repository:
sub remove_records {
  my $type = shift || 'post';
  my $ids  = shift || die 'Missing argument';

  # Initialize required variables:
  my @list = ();

  # Process each record:
  foreach my $id (@$ids) {
    # Prepare the file names:
    my $head = catfile($blogdir, '.blaze', "${type}s", 'head', $id);
    my $body = catfile($blogdir, '.blaze', "${type}s", 'body', $id);
    my $raw  = catfile($blogdir, '.blaze', "${type}s", 'raw', $id);

    # Enter the interactive mode if requested:
    if ($prompt) {
      # Parse header data:
      my $data = read_ini($head);

      # Check whether the ID exists:
      unless ($data) {
        # Display appropriate warning:
        display_warning("Unable to read the $type with ID $id.");

        # Move on to the next ID:
        next;
      }

      # Display prompt:
      print "Remove $type with ID $id titled `" .
            ($data->{header}->{title} || '') . "'? ";

      # Skip removal unless confirmed:
      next unless (readline(*STDIN) =~ /^(y|yes)$/i);
    }

    # Try to remove the record header:
    if (unlink $head) {
      # Remove the remaining record data:
      unlink($body, $raw);

      # Add record to the list of successfully removed IDs:
      push(@list, $id);
    }
    else {
      # Report failure:
      display_warning("Unable to remove the $type with ID $id.");
    }
  }

  # Return the list of removed IDs:
  return @list;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'page|pages|p'  => sub { $type    = 'page'; },
  'post|posts|P'  => sub { $type    = 'post'; },
  'force|f'       => sub { $prompt  = 0;      },
  'interactive|i' => sub { $prompt  = 1;      },
  'quiet|q'       => sub { $verbose = 0;      },
  'verbose|V'     => sub { $verbose = 1;      },
  'blogdir|b=s'   => sub { $blogdir = $_[1];  },
);

# Check missing options:
exit_with_error("Wrong number of options.", 22) if (scalar(@ARGV) < 1);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Remove given records from the repository:
my @list = remove_records($type, \@ARGV);

# End here unless at least one record was actually removed:
unless (@list) {
  # Report abortion:
  print "Aborted.\n" if $verbose;

  # Return failure/success:
  exit (($prompt) ? 0 : 13);
}

# Prepare the list of successfully removed IDs:
$removed =  join(', ', sort(@list));
$removed =~ s/, ([^,]+)$/ and $1/;

# Log the event:
add_to_log("Removed the $type with ID $removed.")
  or display_warning("Unable to log the event.");

# Report success:
print "Successfully removed the $type with ID $removed.\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-remove - remove a post/page from the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-remove> [B<-fipqPV>] [B<-b> I<directory>] I<id>...

B<blaze-remove> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-remove> deletes the blog posts or pages with given I<id>s from the
BlazeBlogger repository.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-p>, B<--page>, B<--pages>

Remove pages instead of blog posts.

=item B<-P>, B<--post>, B<--posts>

Remove blog posts; this is the default option.

=item B<-i>, B<--interactive>

Prompt before post/page removal.

=item B<-f>, B<--force>

Do not prompt before post/page removal; this is the default option.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages. This is the default option.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 SEE ALSO

B<perl>(1).

=head1 BUGS

To report bug or even send patch, either add new issue to the project
bugtracker at <http://code.google.com/p/blazeblogger/issues/>, or visit
the discussion group at <http://groups.google.com/group/blazeblogger/>. You
can also contact the author directly via e-mail.

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
