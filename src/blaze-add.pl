#!/usr/bin/env perl

# blaze-add, add a blog post or a page to the BlazeBlogger repository
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
use Text::Wrap;
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
Usage: $NAME [-pqPV] [-b directory] [file...]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -p, --page                  add the static page instead of the post
  -P, --post                  add the blog post; the default option
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

# Write string to the given file:
sub write_to_file {
  my $file = shift || die 'Missing argument';
  my $text = shift || '';

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write given string to the file::
  print FILE $text;

  # Close the file:
  close(FILE);

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
    print STDERR "Missing title in the $type with ID $id.\n"
      if $verbose;
  }

  # Check whether the author is specified:
  if (my $author = $data->{header}->{author}) {
    # Check whether it contains forbidden characters:
    if ($author =~ /:/) {
      # Display the appropriate warning:
      print STDERR "Invalid author in the $type with ID $id.\n"
        if $verbose;
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR "Missing author in the $type with ID $id.\n"
      if $verbose;
  }

  # Check whether the date is specified:
  if (my $date = $data->{header}->{date}) {
    # Check whether the format is valid:
    if ($date !~ /\d{4}-[01]\d-[0-3]\d/) {
      # Display the appropriate warning:
      print STDERR "Invalid date in the $type with ID $id.\n"
        if $verbose;
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR "Missing date in the $type with ID $id.\n"
      if $verbose;
  }

  # Check whether the tags are specified:
  if (my $tags = $data->{header}->{tags}) {
    # Check whether they contain forbidden characters:
    if ($tags =~ /:/) {
      # Display the appropriate warning:
      print STDERR "Invalid tags in the $type with ID $id.\n"
        if $verbose;
    }
  }

  # Check whether the URL is specified:
  if (my $url = $data->{header}->{url}) {
    # Check whether it contains forbidden characters:
    if ($url =~ /[^\w\-]/) {
      # Display the appropriate warning:
      print STDERR "Invalid URL in the $type with ID $id.\n"
        if $verbose;
    }
  }

  # Return success:
  return 1;
}

# Create a record from the single file:
sub save_record {
  my $file = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my $type = shift || 'post';
  my $data = {};
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

# Add given string to the log file
sub add_to_log {
  my $text = shift || 'Something miraculous has just happened!';
  my $file = catfile($blogdir, '.blaze', 'log');

  # Open the log file for appending:
  open(LOG, ">>$file") or return 0;

  # Write to the log file: 
  print LOG "Date: " . localtime(time) . "\n\n";
  print LOG wrap('    ', '    ', $text);
  print LOG "\n\n";

  # Close the file:
  close(LOG);

  # Return success:
  return 1;
}

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
}

# Return the first unused ID:
sub choose_id {
  my $type   = shift || 'post';
  my $head   = catdir($blogdir, '.blaze', "${type}s", 'head');
  my $chosen = 1;

  # Open the headers directory:
  opendir(HEADS, $head) or return 0;

  # Build a list of used IDs:
  my @used = grep {! /^\.\.?$/ } readdir(HEADS);

  # Find the first unused ID:
  foreach my $id (sort {$a <=> $b} @used) {
    $chosen++ if ($chosen == $id);
  }

  # Close the directory:
  closedir(HEADS);

  # Return the result:
  return $chosen;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'page|p'        => sub { $type    = 'page'; },
  'post|P'        => sub { $type    = 'post'; },
  'quiet|q'       => sub { $verbose = 0;      },
  'verbose|V'     => sub { $verbose = 1;      },
  'blogdir|b=s'   => sub { $blogdir = $_[1];  },
);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Check whether the file is supplied:
if (scalar(@ARGV) == 0) {
  my $file = catfile($blogdir, '.blaze', 'temp');

  # Read the configuration file:
  my $temp = catfile($blogdir, '.blaze', 'config');
  my $conf = ReadINI($temp)
             or exit_with_error("Unable to read `$temp'.", 13);

  # Prepare the data for the temporary file header:
  my $name = $conf->{user}->{name} || 'admin';
  my $date = date_to_string(time);

  # Decide which editor to use:
  my $edit = $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Write the temporary file:
  write_to_file($file, << "END_TEMP");
# This and following lines beginning with  `#' are the $type header.  Please
# take your time and replace these options with desired values. Just remem-
# ber that the date has to be in an  YYYY-MM-DD  form,  the tags is a comma
# separated list of categories the post (pages ignore these) belong and the
# URL, if provided, should consist of alphaanumeric characters, hyphens and
# underscores only.
#
#   title:
#   author: $name
#   date:   $date
#   tags:
#   url:
#
# The header ends here. The rest is the content of your $type.

END_TEMP

  # Open the temporary file in the external editor:
  system($edit, $file) == 0 or exit_with_error("Unable to run `$edit'.",1);

  # Get the first unused ID:
  my $id = choose_id($type);

  # Save the record:
  save_record($file, $id, $type)
    or exit_with_error("Unable to write the record.", 13);

  # Log the record addition:
  add_to_log("Added the $type with ID $id.")
    or exit_with_error("Unable to log the event.");

  # Report success:
  print "The $type has been successfully added with ID $id.\n" if $verbose;
}
else {
  my @added = ();

  # Process each file:
  foreach my $file (@ARGV) {
    # Get the first unused ID:
    my $id = choose_id($type);

    # Save the record:
    save_record($file, $id, $type)
      and push(@added, $id)
      or print STDERR "Unable to add $file.\n" if $verbose;
  }

  # Prepare the list of successfully added IDs:
  my $list = join(', ', sort(@added));

  # Log the record addition:
  add_to_log("Added the $type with ID $list.")
    or exit_with_error("Unable to log the event.") if $list;

  # Report success:
  print "Successfully added the $type with ID $list.\n"
    if ($verbose && $list);
}

# Return success:
exit 0;

__END__

=head1 NAME

blaze-add - add a blog post or a page to the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-add> [B<-pqPV>] [B<-b> I<directory>] [I<file>...]

B<blaze-add> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-add> adds new blog posts or static pages to the BlazeBlogger
repository. If supplied, it tries to read data from the existing I<file>s,
otherwise an external editor is opened to let you create a new content.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-p>, B<--page>

Add the static page instead of the blog post.

=item B<-P>, B<--post>

Add the blog post; this is the default option.

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