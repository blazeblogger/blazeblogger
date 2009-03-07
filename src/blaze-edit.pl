#!/usr/bin/env perl

# blaze-edit, edit a blog post or a page in the BlazeBlogger repository
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
use Digest::MD5;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.7.1';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $verbose = 1;                                   # Verbosity level.

# Command-line options:
my  $type = 'post';                                 # Type: post or page.

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

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Print the message to the STDOUT:
  print << "END_HELP";
Usage: $NAME [-pqPV] [-b directory] id
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -p, --page                  edit the static page instead of the post
  -P, --post                  edit the blog post; the default option
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

# Check the header for the erroneous or missing data:
sub check_header {
  my $data = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my $type = shift || die 'Missing argument';

  # Check whether the title is specified:
  unless ($data->{header}->{title}) {
    # Display the appropriate warning:
    print STDERR "Missing title in the $type with ID $id.\n";
  }

  # Check whether the author is specified:
  if (my $author = $data->{header}->{author}) {
    # Check whether it contains forbidden characters:
    if ($author =~ /:/) {
      # Display the appropriate warning:
      print STDERR "Invalid author in the $type with ID $id.\n";
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR "Missing author in the $type with ID $id.\n";
  }

  # Check whether the date is specified:
  if (my $date = $data->{header}->{date}) {
    # Check whether the format is valid:
    if ($date !~ /\d{4}-[01]\d-[0-3]\d/) {
      # Display the appropriate warning:
      print STDERR "Invalid date in the $type with ID $id.\n";
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR "Missing date in the $type with ID $id.\n";
  }

  # Check whether the tags are specified:
  if (my $tags = $data->{header}->{tags}) {
    # Check whether they contain forbidden characters:
    if ($tags =~ /:/) {
      # Display the appropriate warning:
      print STDERR "Invalid tags in the $type with ID $id.\n";
    }
  }

  # Check whether the URL is specified:
  if (my $url = $data->{header}->{url}) {
    # Check whether it contains forbidden characters:
    if ($url =~ /[^\w\-]/) {
      # Display the appropriate warning:
      print STDERR "Invalid URL in the $type with ID $id.\n";
    }
  }

  # Return success:
  return 1;
}

# Create a single file from the record:
sub read_record {
  my $file = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my $type = shift || 'post';

  # Prepare the record file names:
  my $head = catfile($blogdir, '.blaze', "${type}s", 'head', $id);
  my $body = catfile($blogdir, '.blaze', "${type}s", 'body', $id);

  # Parse the record header data:
  my $data = ReadINI($head) or return 0;

  # Collect the data for the file header:
  my $author = $data->{header}->{author} || '';
  my $title  = $data->{header}->{title}  || '';
  my $date   = $data->{header}->{date}   || '';
  my $tags   = $data->{header}->{tags}   || '';
  my $url    = $data->{header}->{url}    || '';

  # Open the file for writing:
  open(FILE, ">$file")
    or exit_with_error("Unable to write the temporary file.");

  # Write the header:
  print FILE << "END_HEADER";
# This and following lines beginning with  `#' are the $type header.  Please
# take your time and replace these options with desired values. Just remem-
# ber that the date has to be in an  YYYY-MM-DD  form,  the tags is a comma
# separated list of categories the post (pages ignore these) belong and the
# url, if provided, should consist of alphanumeric characters,  hyphens and
# underscores only. Specifying your own URL  is especially recommended when
# you use non-ASCII characters in your $type title.
#
#   title:  $title
#   author: $author
#   date:   $date
#   tags:   $tags
#   url:    $url
#
# The header ends here.  The rest is the content of your $type.  You can use
# <!-- break --> to mark the end of the part to be displayed on index page.
END_HEADER

  # Open the record body for the reading:
  open(BODY, "$body") or return 0;

  # Add content of the record body to the file:
  while (my $line = <BODY>) {
    print FILE $line;
  }

  # Close previously opened files:
  close(BODY);
  close(FILE);

  # Return success:
  return 1;
}

# Create a record from the single file:
sub save_record {
  my $file = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my $type = shift || 'post';
  my $data = shift || {};
  my $line = '';

  # Prepare the record file names:
  my $head = catfile($blogdir, '.blaze', "${type}s", 'head', $id);
  my $body = catfile($blogdir, '.blaze', "${type}s", 'body', $id);

  # Open the file for reading:
  open(FILE, "$file") or return 0;

  # Parse the file header:
  while ($line = <FILE>) {
    # Header ends with the first line not beginning with `#':
    last unless $line =~ /^#/;

    # Collect the data for the record header:
    if ($line =~ /(title|author|date|tags|url):\s*(\S.*)$/) {
      $data->{header}->{$1} = $2;
    }
  }

  # Check the header for the erroneous or missing data:
  check_header($data, $id, $type);

  # Write the record header:
  WriteINI($head, $data) or return 0;

  # Open the record body for writing:
  open(BODY, ">$body") or return 0;

  # Write the last read line to the body record:
  print BODY $line if $line;

  # Add the rest of the file content to the body record:
  while ($line = <FILE>) {
    print BODY $line;
  }

  # Close previously opened files:
  close(BODY);
  close(FILE);

  # Return success:
  return 1;
}

# Edit record in the repository:
sub edit_record {
  my $id   = shift || die 'Missing argument';
  my $type = shift || 'post';
  my ($before, $after);

  # Prepare the temporary file name:
  my $temp = catfile($blogdir, '.blaze', 'temp');

  # Read the configuration file:
  my $file = catfile($blogdir, '.blaze', 'config');
  my $conf = ReadINI($file)
             or print STDERR "Unable to read configuration.\n";

  # Decide which editor to use:
  my $edit = $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Create the temporary file:
  read_record($temp, $id, $type)
    or exit_with_error("Unable to read record with ID $id.", 13);

  # Open the file for reading:
  if (open(FILE, "$temp")) {
    # Set the IO handler to binmode:
    binmode(FILE);

    # Count checksum:
    $before = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);
  }

  # Open the temporary file in the external editor:
  system($edit, $temp) == 0 or exit_with_error("Unable to run `$edit'.",1);

  # Open the file for reading:
  if (open(FILE, "$temp")) {
    # Set the IO handler to binmode:
    binmode(FILE);

    # Count checksum:
    $after = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);

    # Compare the checksums:
    if ($before eq $after) {
      # Report failure:
      print STDERR "File have not been changed: aborting.\n";

      # Return failure:
      return 0;
    }
  }

  # Save the record:
  save_record($temp, $id, $type)
    or exit_with_error("Unable to write the record with ID $id.", 13);

  # Return success:
  return 1;
}

# Add given string to the log file
sub add_to_log {
  my $text = shift || 'Something miraculous has just happened!';
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

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'page|pages|p'  => sub { $type    = 'page'; },
  'post|posts|P'  => sub { $type    = 'post'; },
  'quiet|q'       => sub { $verbose = 0;      },
  'verbose|V'     => sub { $verbose = 1;      },
  'blogdir|b=s'   => sub { $blogdir = $_[1];  },
);

# Check superfluous options:
exit_with_error("Wrong number of options.", 22) if (scalar(@ARGV) != 1);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Edit given record:
edit_record($ARGV[0], $type) or exit 1;

# Log the event:
add_to_log("Edited the $type with ID $ARGV[0].")
  or print STDERR "Unable to log the event.\n";

# Report success:
print "Your changes have been successfully saved.\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-edit - edit a blog post or a page in the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-edit> [B<-pqPV>] [B<-b> I<directory>] I<id>

B<blaze-edit> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-edit> enables you to edit the blog post or the static page in your
favourite text editor.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-p>, B<--page>

Edit the static page instead of the blog post.

=item B<-P>, B<--post>

Edit the blog post; this is the default option.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages. This is the default option.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 ENVIRONMENT

=over

=item B<EDITOR>

Unless the BlazeBlogger specific option I<core.editor> is set, blaze-edit
tries to use system wide settings to decide which editor to run. If neither
of these options are supplied, the B<vi> is used instead as a considerably
reasonable choice.

=back

=head1 FILES

=over

=item I<.blaze/config>

BlazeBlogger configuration file.

=back

=head1 SEE ALSO

B<blaze-config>(1), B<perl>(1).

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

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
