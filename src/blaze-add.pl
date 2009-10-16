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
use Digest::MD5;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec::Functions;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '1.0.0';                    # Script version.

# General script settings:
our $blogdir  = '.';                                # Repository location.
our $process  = 1;                                  # Use processor?
our $verbose  = 1;                                  # Verbosity level.

# Global variables:
our $chosen   = 1;                                  # Available ID guess.
our $reserved = undef;                              # Reserved IDs list.
our $conf     = {};                                 # Configuration.

# Command-line options:
my  $type     = 'post';                             # Type: post or page.
my  $added    = '';                                 # List of added IDs.
my  $data     = {};                                 # Post/page metadata.

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
Usage: $NAME [-pqCPV] [-b directory] [-a author] [-d date] [-t title]
                 [-T tags] [-u url] [file...]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -t, --title title           use given title
  -a, --author author         use given author
  -d, --date date             use given date; has to be in YYYY-MM-DD form
  -T, --tags tags             tag the blog post; pages ignore these
  -u, --url url               use given url; based on the title by default
  -p, --page                  add page instead of blog post
  -P, --post                  add blog post; the default option
  -C, --no-processor          disable the use of external processor
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

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
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

# Write data to the INI file:
sub write_ini {
  my $file = shift || 'Missing argument';
  my $hash = shift || 'Missing argument';

  # Open the file for writing:
  open(INI, ">$file") or return 0;

  # Process each section:
  foreach my $section (sort(keys(%$hash))) {
    # Write the section header:
    print INI "[$section]\n";

    # Process each option in the section:
    foreach my $option (sort(keys(%{$hash->{$section}}))) {
      # Write the option and its value:
      print INI "  $option = $hash->{$section}->{$option}\n";
    }
  }

  # Close the file:
  close(INI);

  # Return success:
  return 1;
}

# Read the configuration file:
sub read_conf {
  # Prepare the file name:
  my $file = catfile($blogdir, '.blaze', 'config');

  # Parse the file:
  if (my $conf = read_ini($file)) {
    # Return the result:
    return $conf;
  }
  else {
    # Report failure:
    display_warning("Unable to read configuration.");

    # Return empty configuration:
    return {};
  }
}

# Make proper URL from given string, stripping all forbidden characters:
sub make_url {
  my $url = shift || return '';

  # Strip forbidden characters:
  $url =~ s/[^\w\s\-]//g;

  # Strip trailing spaces:
  $url =~ s/\s+$//;

  # Substitute spaces:
  $url =~ s/\s+/-/g;

  # Return the result:
  return $url;
}

# Fix the erroneous or missing header data:
sub fix_header {
  my $data = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my $type = shift || die 'Missing argument';

  # Check whether the title is specified:
  if ($data->{header}->{title}) {
    # Strip trailing spaces:
    $data->{header}->{title} =~ s/\s+$//;
  }
  else {
    # Assign the default value:
    my $title = $data->{header}->{title} = 'Untitled';

    # Display the appropriate warning:
    display_warning("Missing title in the $type with ID $id. " .
                    "Using `$title' instead.");
  }

  # Check whether the author is specified:
  unless ($data->{header}->{author}) {
    # Assign the default value:
    my $author = $data->{header}->{author}
               = $conf->{user}->{name} || 'admin';

    # Report missing author:
    display_warning("Missing author in the $type with ID $id. " .
                    "Using `$author' instead.");
  }

  # Check whether the date is specified:
  if (my $date = $data->{header}->{date}) {
    # Check whether the format is valid:
    unless ($date =~ /\d{4}-[01]\d-[0-3]\d/) {
      # Use current date instead:
      $date = $data->{header}->{date} = date_to_string(time);

      # Report invalid date:
      display_warning("Invalid date in the $type with ID $id. " .
                      "Using `$date' instead.");
    }
  }
  else {
    # Use current date instead:
    my $date = $data->{header}->{date} = date_to_string(time);

    # Report missing date:
    display_warning("Missing date in the $type with ID $id. " .
                    "Using `$date' instead.");
  }

  # Check whether the tags are specified:
  if (my $tags = $data->{header}->{tags}) {
    # Make all tags lower case:
    $tags = lc($tags);

    # Strip superfluous spaces:
    $tags =~ s/\s{2,}/ /g;
    $tags =~ s/\s+$//;

    # Strip trailing commas:
    $tags =~ s/^,+|,+$//g;

    # Remove duplicates:
    my %temp = map { $_, 1 } split(/,+\s*/, $tags);
    $data->{header}->{tags} = join(', ', sort(keys %temp));

    # Make sure non of the tags will have empty URL:
    foreach my $tag (keys %temp) {
      # Derive URL from tag name:
      my $tag_url = make_url($tag);

      # Make sure the result is not empty:
      unless ($tag_url) {
        # Report missing tag URL:
        display_warning("Unable to derive URL from tag `$tag'. " .
                        "You might want to use ASCII only.");
      }
    }
  }

  # Check whether the URL is specified:
  if (my $url = $data->{header}->{url}) {
    # Check whether it contains forbidden characters:
    if ($url =~ /[^\w\-]/) {
      # Strip forbidden characters:
      $data->{header}->{url} = $url = make_url($url);

      # Report invalid URL:
      display_warning("Invalid URL in the $type with ID $id. " .
                      ($url ? "Stripping to `$url'."
                            : "It will be derived from title."));
    }
  }

  # Make sure the URL can be derived from title if necessary:
  unless ($data->{header}->{url}) {
    # Derive URL from the post/page title:
    my $url = make_url(lc($data->{header}->{title}));

    # Check whether the URL is not empty:
    unless ($url) {
      # Report missing URL:
      display_warning("Unable to derive URL in the $type with ID $id. " .
                      "You might want to specify it yourself.");
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
  my $data = shift || {};

  # Initialize required variables:
  my $line = '';

  # Prepare the record directory names:
  my $head_dir  = catdir($blogdir, '.blaze', "${type}s", 'head');
  my $body_dir  = catdir($blogdir, '.blaze', "${type}s", 'body');
  my $raw_dir   = catdir($blogdir, '.blaze', "${type}s", 'raw');

  # Prepare the record file names:
  my $head      = catfile($head_dir, $id);
  my $body      = catfile($body_dir, $id);
  my $raw       = catfile($raw_dir,  $id);

  # Prepare the temporary file names:
  my $temp_head = catfile($blogdir, '.blaze', 'temp.head');
  my $temp_body = catfile($blogdir, '.blaze', 'temp.body');
  my $temp_raw  = catfile($blogdir, '.blaze', 'temp.raw');

  # Read required data from the configuration:
  my $processor = $conf->{core}->{processor};

  # Check whether the processor is enabled:
  if ($process) {
    # Substitute the placeholders with actual file names:
    $processor  =~ s/%in%/$temp_raw/ig;
    $processor  =~ s/%out%/$temp_body/ig;
  }

  # Open the input file for reading:
  open(FIN, "$file") or return 0;

  # Parse the file header:
  while ($line = <FIN>) {
    # Header ends with the first line not beginning with `#':
    last unless $line =~ /^#/;

    # Collect the data for the record header:
    if ($line =~ /(title|author|date|tags|url):\s*(\S.*)$/) {
      $data->{header}->{$1} = $2;
    }
  }

  # Fix erroneous or missing header data:
  fix_header($data, $id, $type);

  # Write the record header to the temporary file:
  write_ini($temp_head, $data) or return 0;

  # Open the proper output file:
  open(FOUT, '>' . ($process ? $temp_raw : $temp_body)) or return 0;

  # Write the last read line to the output file:
  print FOUT $line if $line;

  # Add the rest of the file content to the output file:
  while ($line = <FIN>) {
    print FOUT $line;
  }

  # Close all opened files:
  close(FIN);
  close(FOUT);

  # Check whether the processor is enabled:
  if ($process) {
    # Process the raw input file:
    unless (system("$processor") == 0) {
      # Report failure and exit:
      exit_with_error("Unable to run `$processor'.", 1);
    }

    # Make sure the raw record directory exists:
    unless (-d $raw_dir) {
      # Create the target directory tree:
      eval { mkpath($raw_dir, { verbose => 0 }); };

      # Make sure the directory creation was successful:
      exit_with_error("Creating directory tree: $@", 13) if $@;
    }

    # Create the raw record file:
    move($temp_raw, $raw) or return 0;
  }

  # Make sure the record body and header directories exist:
  unless (-d $head_dir && -d $body_dir) {
    # Create the target directory tree:
    eval { mkpath($head_dir, $body_dir, { verbose => 0 }); };

    # Make sure the directory creation was successful:
    exit_with_error("Creating directory tree: $@", 13) if $@;
  }

  # Create the record body and header files:
  move($temp_body, $body) or return 0;
  move($temp_head, $head) or return 0;

  # Return success:
  return 1;
}

# Collect reserved posts/pages IDs:
sub collect_ids {
  my $type = shift || 'post';

  # Prepare the posts/pages directory name:
  my $head = catdir($blogdir, '.blaze', "${type}s", 'head');

  # Open the headers directory:
  opendir(HEADS, $head) or return 0;

  # Build a list of used IDs:
  my @used = grep {! /^\.\.?$/ } readdir(HEADS);

  # Close the directory:
  closedir(HEADS);

  # Return the sorted result:
  return sort {$a <=> $b} @used;
}

# Return the first unused ID:
sub choose_id {
  my $type   = shift || 'post';

  # Get the list of reserved IDs unless already done:
  @$reserved = collect_ids($type) unless defined $reserved;

  # Iterate through used IDs:
  while (my $used = shift(@$reserved)) {
    # Check whether the candidate ID is really free:
    if ($chosen == $used) {
      # Try next ID:
      $chosen++;
    }
    else {
      # Push the last checked ID back to the list:
      unshift(@$reserved, $used);

      # Exit the loop:
      last;
    }
  }

  # Return the result and increase the next candidate:
  return $chosen++;
}

# Add given files to the repository:
sub add_files {
  my $type  = shift || 'post';
  my $data  = shift || {};
  my $files = shift || die 'Missing argument';

  # Initialize required variables:
  my @list  = ();

  # Process each file:
  foreach my $file (@{$files}) {
    # Get the first available ID:
    my $id = choose_id($type);

    # Save the record:
    save_record($file, $id, $type, $data)
      and push(@list, $id)
      or display_warning("Unable to add $file.");
  }

  # Return the list of added IDs:
  return @list;
}

# Add new record to the repository:
sub add_new {
  my $type = shift || 'post';
  my $data = shift || {};

  # Decide which editor to use:
  my $edit = $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Prepare the data for the temporary file header:
  my $title  = $data->{header}->{title} || '';
  my $author = $data->{header}->{author}|| $conf->{user}->{name} || 'admin';
  my $date   = $data->{header}->{date}  || date_to_string(time);
  my $tags   = $data->{header}->{tags}  || '';
  my $url    = $data->{header}->{url}   || '';

  # Prepare the temporary file header:
  my $head = << "END_HEAD";
# This and following lines beginning with  `#' are the $type header.  Please
# take your time and replace these options with desired values. Just remem-
# ber that the date has to be in an YYYY-MM-DD form, tags are a comma sepa-
# rated list of categories the post (pages ignore these) belong to, and the
# url, if provided, should consist of alphanumeric characters,  hyphens and
# underscores only. Specifying your own url  is especially recommended when
# you use non-ASCII characters in your $type title.
#
#   title:  $title
#   author: $author
#   date:   $date
#   tags:   $tags
#   url:    $url
#
# The header ends here. The rest is the content of your $type.

END_HEAD

  # Prepare the temporary file name:
  my $temp = catfile($blogdir, '.blaze', 'temp');

  # Open the file for writing:
  if (open(FILE, ">$temp")) {
    # Write the temporary file:
    print FILE $head;

    # Close the file:
    close(FILE);
  }
  else {
    # Report failure:
    display_warning("Unable to create temporary file.");

    # Return failure:
    return 0;
  }

  # Open the temporary file in the external editor:
  unless (system("$edit $temp") == 0) {
    # Report failure and exit:
    exit_with_error("Unable to run `$edit'.", 1);
  }

  # Opent the file for reading:
  if (open(FILE, "$temp")) {
    # Set the IO handler to binmode:
    binmode(FILE);

    # Count checksums:
    my $before = Digest::MD5->new->add($head)->hexdigest;
    my $after  = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);

    # Compare the checksums:
    if ($before eq $after) {
      # Report abortion:
      display_warning("File have not been changed: aborting.");

      # Return success:
      exit 0;
    }
  }

  # Add file to the repository:
  my @list = add_files($type, $data, [ $temp ]);

  # Remove the temporary file:
  unlink $temp;

  # Return the record ID:
  return shift(@list);
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

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'         => sub { display_help();    exit 0; },
  'version|v'      => sub { display_version(); exit 0; },
  'page|pages|p'   => sub { $type    = 'page'; },
  'post|posts|P'   => sub { $type    = 'post'; },
  'no-processor|C' => sub { $process = 0;      },
  'quiet|q'        => sub { $verbose = 0;      },
  'verbose|V'      => sub { $verbose = 1;      },
  'blogdir|b=s'    => sub { $blogdir = $_[1];  },
  'title|t=s'      => sub { $data->{header}->{title}  = $_[1]; },
  'author|a=s'     => sub { $data->{header}->{author} = $_[1]; },
  'date|d=s'       => sub { $data->{header}->{date}   = $_[1]; },
  'tags|tag|T=s'   => sub { $data->{header}->{tags}   = $_[1]; },
  'url|u=s'        => sub { $data->{header}->{url}    = $_[1]; },
);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Read the configuration file:
$conf = read_conf();

# Check whether the processor is enabled in the configuration:
if ($process && (my $processor = $conf->{core}->{processor})) {
  # Make sure the processor specification is valid:
  exit_with_error("Invalid core.processor option.", 1)
    unless ($processor =~ /%in%/i && $processor =~ /%out%/i);
}
else {
  # Disable the processor:
  $process = 0;
}

# Check whether any file is supplied:
if (scalar(@ARGV) == 0) {
  # Add new record to the repository:
  $added   = add_new($type, $data)
    or exit_with_error("Cannot add $type to the repository.", 13);
}
else {
  # Add given files to the repository:
  my @list = add_files($type, $data, \@ARGV)
    or exit_with_error("Cannot add ${type}s to the repository.", 13);

  # Prepare the list of successfully added IDs:
  $added   =  join(', ', sort(@list));
  $added   =~ s/, ([^,]+)$/ and $1/;
}

# Log the event:
add_to_log("Added the $type with ID $added.")
  or display_warning("Unable to log the event.");

# Report success:
print "Successfully added the $type with ID $added.\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-add - add a blog post or a page to the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-add> [B<-pqCPV>] [B<-b> I<directory>] [B<-a> I<author>] [B<-d>
I<date>] [B<-t> I<title>] [B<-T> I<tags>] [B<-u> I<url>] [I<file>...]

B<blaze-add> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-add> adds new blog posts or pages to the BlazeBlogger repository.
If supplied, it tries to read data from the existing I<file>s, otherwise an
external editor is opened to let you create a new content.

Note that inside your posts and pages, you can use several special
placeholders to be replaced by appropriate data later, when the static
content is being generated; the case is not significant, and supported
placeholders are as follows:

=over

=item B<%root%>

Relative path to the root directory of the blog; to be used inside links.

=item B<%home%>

Relative path to the website home (index) page; to be used inside links.

=item B<%page[>I<id>B<]%>

Relative path to the page with given I<id>; to be used inside links.

=item B<%post[>I<id>B<]%>

Relative path to the post with given I<id>; to be used inside links.

=item B<%tag[>I<name>B<]%>

Relative path to the tag with given I<name>; to be used inside links.

=back

You can also use a special form, B<< <!-- break --> >>, to mark the end of
a part to be displayed on index page.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-t>, B<--title> I<title>

Specify the post/page I<title>.

=item B<-a>, B<--author> I<author>

Specify the post/page I<author>.

=item B<-d>, B<--date> I<date>

Specify the post/page date of publishing; the I<date> has to be in the
YYYY-MM-DD form.

=item B<-T>, B<--tags> I<tags>

Specify the comma separated list of I<tags> attached to the blog post;
pages ignore these.

=item B<-u>, B<--url> I<url>

Specify the post/page I<url> to be used instead of the one based on the
post/page title. It should consist of alphanumeric characters, hyphens and
underscores only, and it is especially useful if non-ASCII characters are
present in the title.

=item B<-p>, B<--page>, B<--pages>

Add page instead of blog post.

=item B<-P>, B<--post>, B<--posts>

Add blog post; this is the default option.

=item B<-C>, B<--no-processor>

Disable the use of external processor. Unless the C<core.processor> is
enabled in the configuration, this is the default behaviour.

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
