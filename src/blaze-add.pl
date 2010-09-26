#!/usr/bin/env perl

# blaze-add - adds a blog post or a page to the BlazeBlogger repository
# Copyright (C) 2008-2010 Jaromir Hradilek

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
our $editor   = '';                                 # Editor to use.
our $process  = 1;                                  # Use processor?
our $verbose  = 1;                                  # Verbosity level.

# Global variables:
our $chosen   = 1;                                  # Available ID guess.
our $reserved = undef;                              # Reserved ID list.
our $conf     = {};                                 # Configuration.

# Command line options:
my  $type     = 'post';                             # Type: post or page.
my  $added    = '';                                 # List of added IDs.
my  $data     = {};                                 # Post/page meta data.

# Set up the __WARN__ signal handler:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display an error message, and terminate the script:
sub exit_with_error {
  my $message      = shift || 'An error has occurred.';
  my $return_value = shift || 1;

  # Display the error message:
  print STDERR NAME . ": $message\n";

  # Terminate the script:
  exit $return_value;
}

# Display a warning message:
sub display_warning {
  my $message = shift || 'A warning was requested.';

  # Display the warning message:
  print STDERR "$message\n";

  # Return success:
  return 1;
}

# Display usage information:
sub display_help {
  my $NAME = NAME;

  # Display the usage:
  print << "END_HELP";
Usage: $NAME [-pqCPV] [-b DIRECTORY] [-E EDITOR] [-a AUTHOR] [-d DATE]
                 [-t TITLE] [-T TAGS] [-u URL] [FILE...]
       $NAME -h|-v

  -b, --blogdir DIRECTORY     specify a directory in which the BlazeBlogger
                              repository is placed
  -E, --editor EDITOR         specify an external text editor
  -t, --title TITLE           specify a title
  -a, --author AUTHOR         specify an author
  -d, --date DATE             specify a date of publishing
  -T, --tags TAGS             specify a comma-separated list of tags
  -u, --url URL               specify a URL
  -p, --page                  add a page or pages
  -P, --post                  add a blog post or blog posts
  -C, --no-processor          disable processing the blog post or page with
                              an external application
  -q, --quiet                 do not display unnecessary messages
  -V, --verbose               display all messages
  -h, --help                  display this help and exit
  -v, --version               display version information and exit
END_HELP

  # Return success:
  return 1;
}

# Display version information:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Display the version:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008-2010 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Translate a date to the YYYY-MM-DD form:
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
    # Parse the line:
    if ($line =~ /^\s*\[([^\]]+)\]\s*$/) {
      # Change the section:
      $section = $1;
    }
    elsif ($line =~ /^\s*(\S+)\s*=\s*(\S.*)$/) {
      # Add the option to the hash:
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
    # Write the section header to the file::
    print INI "[$section]\n";

    # Process each option in the section:
    foreach my $option (sort(keys(%{$hash->{$section}}))) {
      # Write the option and its value to the file:
      print INI "  $option = $hash->{$section}->{$option}\n";
    }
  }

  # Close the file:
  close(INI);

  # Return success:
  return 1;
}

# Read the content of the configuration file:
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
    display_warning("Unable to read the configuration.");

    # Return an empty configuration:
    return {};
  }
}

# Make proper URL from the string while stripping all forbidden characters:
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

# Fix erroneous or missing header data:
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

    # Report the missing author:
    display_warning("Missing author in the $type with ID $id. " .
                    "Using `$author' instead.");
  }

  # Check whether the date is specified:
  if (my $date = $data->{header}->{date}) {
    # Check whether the format is valid:
    unless ($date =~ /\d{4}-[01]\d-[0-3]\d/) {
      # Use current date instead:
      $date = $data->{header}->{date} = date_to_string(time);

      # Report the invalid date:
      display_warning("Invalid date in the $type with ID $id. " .
                      "Using `$date' instead.");
    }
  }
  else {
    # Use current date instead:
    my $date = $data->{header}->{date} = date_to_string(time);

    # Report the missing date:
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

    # Make sure none of the tags will have an empty URL:
    foreach my $tag (keys %temp) {
      # Derive the URL from the tag name:
      my $tag_url = make_url($tag);

      # Make sure the result is not empty:
      unless ($tag_url) {
        # Report the missing tag URL:
        display_warning("Unable to derive the URL from the tag `$tag'. " .
                        "Please use ASCII characters only.");
      }
    }
  }

  # Check whether the URL is specified:
  if (my $url = $data->{header}->{url}) {
    # Check whether it contains forbidden characters:
    if ($url =~ /[^\w\-]/) {
      # Strip forbidden characters:
      $data->{header}->{url} = $url = make_url($url);

      # Report the invalid URL:
      display_warning("Invalid URL in the $type with ID $id. " .
                      ($url ? "Stripping to `$url'."
                            : "It will be derived from the title."));
    }
  }

  # Make sure the URL can be derived from the title if necessary:
  unless ($data->{header}->{url}) {
    # Derive the URL from the post or page title:
    my $url = make_url(lc($data->{header}->{title}));

    # Check whether the URL is not empty:
    unless ($url) {
      # Report the missing URL:
      display_warning("Unable to derive the URL in the $type with ID $id. " .
                      "Please specify it yourself.");
    }
  }

  # Return success:
  return 1;
}

# Create a record from a single file:
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
    # Substitute placeholders with actual file names:
    $processor  =~ s/%in%/$temp_raw/ig;
    $processor  =~ s/%out%/$temp_body/ig;
  }

  # Open the input file for reading:
  open(FIN, "$file") or return 0;

  # Parse the file header:
  while ($line = <FIN>) {
    # The header ends with the first line not beginning with "#":
    last unless $line =~ /^#/;

    # Collect data for the record header:
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
      eval { mkpath($raw_dir, 0); };

      # Make sure the directory creation was successful:
      exit_with_error("Creating the directory tree: $@", 13) if $@;
    }

    # Create the raw record file:
    move($temp_raw, $raw) or return 0;
  }

  # Make sure the record body and header directories exist:
  unless (-d $head_dir && -d $body_dir) {
    # Create the target directory tree:
    eval { mkpath([$head_dir, $body_dir], 0); };

    # Make sure the directory creation was successful:
    exit_with_error("Creating the directory tree: $@", 13) if $@;
  }

  # Create the record body and header files:
  move($temp_body, $body) or return 0;
  move($temp_head, $head) or return 0;

  # Return success:
  return 1;
}

# Collect reserved post or page IDs:
sub collect_ids {
  my $type = shift || 'post';

  # Prepare the post or page directory name:
  my $head = catdir($blogdir, '.blaze', "${type}s", 'head');

  # Open the header directory:
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

  # Iterate through the used IDs:
  while (my $used = shift(@$reserved)) {
    # Check whether the candidate ID is really free:
    if ($chosen == $used) {
      # Try the next ID:
      $chosen++;
    }
    else {
      # Push the last checked ID back to the list:
      unshift(@$reserved, $used);

      # Exit the loop:
      last;
    }
  }

  # Return the result, and increase the next candidate number:
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

# Add a new record to the repository:
sub add_new {
  my $type = shift || 'post';
  my $data = shift || {};

  # Decide which editor to use:
  my $edit = $editor || $conf->{core}->{editor} || $ENV{EDITOR} || 'vi';

  # Prepare the data for the temporary file header:
  my $title  = $data->{header}->{title} || '';
  my $author = $data->{header}->{author}|| $conf->{user}->{nickname}
                                        || $conf->{user}->{name} || 'admin';
  my $date   = $data->{header}->{date}  || date_to_string(time);
  my $tags   = $data->{header}->{tags}  || '';
  my $url    = $data->{header}->{url}   || '';

  # Prepare the temporary file header:
  my $head = << "END_HEAD";
# This and following lines beginning with  '#' are the $type header.  Please
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
    display_warning("Unable to create the temporary file.");

    # Return failure:
    return 0;
  }

  # Open the temporary file in the external editor:
  unless (system("$edit $temp") == 0) {
    # Report failure and exit:
    exit_with_error("Unable to run `$edit'.", 1);
  }

  # Open the file for reading:
  if (open(FILE, "$temp")) {
    # Set the input/output handler to "binmode":
    binmode(FILE);

    # Count the checksums:
    my $before = Digest::MD5->new->add($head)->hexdigest;
    my $after  = Digest::MD5->new->addfile(*FILE)->hexdigest;

    # Close the file:
    close(FILE);

    # Compare the checksums:
    if ($before eq $after) {
      # Report abortion:
      display_warning("The file has not been changed: aborting.");

      # Return success:
      exit 0;
    }
  }

  # Add the file to the repository:
  my @list = add_files($type, $data, [ $temp ]);

  # Remove the temporary file:
  unlink $temp;

  # Return the record ID:
  return shift(@list);
}

# Add the event to the log:
sub add_to_log {
  my $text = shift || 'Something miraculous has just happened!';

  # Prepare the log file name:
  my $file = catfile($blogdir, '.blaze', 'log');

  # Open the log file for appending:
  open(LOG, ">>$file") or return 0;

  # Write the event to the file:
  print LOG localtime(time) . " - $text\n";

  # Close the file:
  close(LOG);

  # Return success:
  return 1;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command line options:
GetOptions(
  'help|h'         => sub { display_help();    exit 0; },
  'version|v'      => sub { display_version(); exit 0; },
  'page|pages|p'   => sub { $type    = 'page'; },
  'post|posts|P'   => sub { $type    = 'post'; },
  'no-processor|C' => sub { $process = 0;      },
  'quiet|q'        => sub { $verbose = 0;      },
  'verbose|V'      => sub { $verbose = 1;      },
  'blogdir|b=s'    => sub { $blogdir = $_[1];  },
  'editor|E=s'     => sub { $editor  = $_[1];  },
  'title|t=s'      => sub { $data->{header}->{title}  = $_[1]; },
  'author|a=s'     => sub { $data->{header}->{author} = $_[1]; },
  'date|d=s'       => sub { $data->{header}->{date}   = $_[1]; },
  'tags|tag|T=s'   => sub { $data->{header}->{tags}   = $_[1]; },
  'url|u=s'        => sub { $data->{header}->{url}    = $_[1]; },
);

# Check whether the repository is present, no matter how naive this method
# actually is:
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

# Check whether a file is supplied:
if (scalar(@ARGV) == 0) {
  # Add a new record to the repository:
  $added   = add_new($type, $data)
    or exit_with_error("Cannot add the $type to the repository.", 13);
}
else {
  # Add given files to the repository:
  my @list = add_files($type, $data, \@ARGV)
    or exit_with_error("Cannot add the ${type}s to the repository.", 13);

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

blaze-add - adds a blog post or a page to the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-add> [B<-pqCPV>] [B<-b> I<directory>] [B<-E> I<editor>] [B<-a> I<author>] [B<-d> I<date>] [B<-t> I<title>] [B<-T> I<tags>] [B<-u> I<url>] [I<file>...]

B<blaze-add> B<-h>|B<-v>

=head1 DESCRIPTION

B<blaze-add> adds a blog post or a page to the BlazeBlogger repository. If
a I<file> is supplied, it adds the content of that file, otherwise an
external text editor is opened for you. Note that there are several special
forms and placeholders that can be used in the text, and that will be
replaced with a proper data when the blog is generated.

=head2 Special Forms

=over

=item B<< <!-- break --> >>

A mark to delimit a blog post synopsis.

=back

=head2 Placeholders

=over

=item B<%root%>

A relative path to the root directory of the blog.

=item B<%home%>

A relative path to the index page of the blog.

=item B<%page[>I<id>B<]%>

A relative path to a page with the supplied I<id>.

=item B<%post[>I<id>B<]%>

A relative path to a blog post with the supplied I<id>.

=item B<%tag[>I<name>B<]%>

A relative path to a tag with the supplied I<name>.

=back

=head1 OPTIONS

=over

=item B<-b> I<directory>, B<--blogdir> I<directory>

Allows you to specify a I<directory> in which the BlazeBlogger repository
is placed. The default option is a current working directory.

=item B<-E> I<editor>, B<--editor> I<editor>

Allows you to specify an external text I<editor>. When supplied, this
option overrides the relevant configuration option.

=item B<-t> I<title>, B<--title> I<title>

Allows you to specify the I<title> of a blog post or page.

=item B<-a> I<author>, B<--author> I<author>

Allows you to specify the I<author> of a blog post or page.

=item B<-d> I<date>, B<--date> I<date>

Allows you to specify the I<date> of publishing of a blog post or page.

=item B<-T> I<tags>, B<--tags> I<tags>

Allows you to supply a comma-separated list of I<tags> attached to a blog
post.

=item B<-u> I<url>, B<--url> I<url>

Allows you to specify the I<url> of a blog post or page. Allowed characters
are letters, numbers, hyphens, and underscores.

=item B<-p>, B<--page>, B<--pages>

Tells B<blaze-add> to add a page or pages.

=item B<-P>, B<--post>, B<--posts>

Tells B<blaze-add> to add a blog post or blog posts. This is the default
option.

=item B<-C>, B<--no-processor>

Disables processing a blog post or page with an external application. For
example, if you use Markdown to convert the lightweight markup language to
the valid HTML output, this will enable you to write this particular post
in plain HTML directly.

=item B<-q>, B<--quiet>

Disables displaying of unnecessary messages.

=item B<-V>, B<--verbose>

Enables displaying of all messages. This is the default option.

=item B<-h>, B<--help>

Displays usage information and exits.

=item B<-v>, B<--version>

Displays version information and exits.

=back

=head1 ENVIRONMENT

=over

=item B<EDITOR>

Unless the B<core.editor> option is set, BlazeBlogger tries to use
system-wide settings to decide which editor to use.

=back

=head1 EXAMPLE USAGE

Write a new blog post in an external text editor:

  ~]$ blaze-add

Add a new blog post from a file:

  ~]$ blaze-add new_packages.txt
  Successfully added the post with ID 10.

Write a new page in an external text editor:

  ~]$ blaze-add -p

Write a new page in B<nano>:

  ~]$ blaze-add -p -E nano

=head1 SEE ALSO

B<blaze-init>(1), B<blaze-config>(1), B<blaze-edit>(1), B<blaze-remove>(1),
B<blaze-make>(1)

=head1 BUGS

To report a bug or to send a patch, please, add a new issue to the bug
tracker at <http://code.google.com/p/blazeblogger/issues/>, or visit the
discussion group at <http://groups.google.com/group/blazeblogger/>.

=head1 COPYRIGHT

Copyright (C) 2008-2010 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
