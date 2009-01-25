#!/usr/bin/env perl

# blaze-make, generate the static content from the BlazeBlogger repository
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
use File::Basename;
use File::Spec::Functions;
use Config::IniHash;
use Getopt::Long;
use POSIX qw(strftime);

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.0.1';                    # Script version.

# General script settings:
our $blogdir = '.';                                 # Repository location.
our $destdir = '.';                                 # HTML pages location.
our $verbose = 1;                                   # Verbosity level.

# Global variables:
our $conf    = {};                                  # The configuration.

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
Usage: $NAME [-qV] [-b directory] [-d directory]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -d, --destdir directory     specify the directory where the generated
                              static content is to be placed 
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

# Create given directories:
sub make_directories {
  my $dirs = shift || die "Missing argument";
  my $mask = shift || 0777;

  # Process each directory:
  foreach my $dir (sort @$dirs) {
    # Skip existing directories:
    unless (-d $dir) {
      # Create the directory:
      mkdir($dir, $mask) || exit_with_error("Creating `$dir': $!", 13);
    }
  }

  # Return success:
  return 1;
}

# Write string to the given file:
sub write_to_file {
  my $file = shift || die "Missing argument";
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

# Fix the erroneous or missing header data:
sub fix_header {
  my $data = shift || die "Missing argument";
  my $id   = shift || die "Missing argument";
  my $type = shift || die "Missing argument";

  # Check whether the title is specified:
  unless ($data->{header}->{title}) {
    # Display the appropriate warning:
    print STDERR NAME . ": Missing title in the $type with ID $id.\n"
      if $verbose;

    # Assign the default value:
    $data->{header}->{title} = $id;
  }

  # Check whether the author is specified:
  if (my $author = $data->{header}->{author}) {
    # Check whether it contains forbidden characters:
    if ($author =~ /[^\w\s\-]/) {
      # Display the appropriate warning:
      print STDERR NAME . ": Invalid author in the $type with ID $id.\n"
        if $verbose;

      # Strip forbidden characters:
      $data->{header}->{author} = s/[^\w\s\-]//g;
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR NAME . ": Missing author in the $type with ID $id.\n"
      if $verbose;

    # Assign the default value:
    $data->{header}->{author} = 'admin';
  }

  # Check whether the date is specified:
  if (my $date = $data->{header}->{date}) {
    # Check whether the format is valid:
    if ($date !~ /\d{4}-[01]\d-[0-3]\d/) {
      # Display the appropriate warning:
      print STDERR NAME . ": Invalid date in the $type with ID $id.\n"
        if $verbose;

      # Use the current date instead:
      $data->{header}->{date} = date_to_string(time);
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR NAME . ": Missing date in the $type with ID $id.\n"
      if $verbose;

    # Assign the default value:
    $data->{header}->{date} = date_to_string(time);
  }

  # Check whether the tags are specified:
  if (my $tags = $data->{header}->{tags}) {
    # Check whether they contain forbidden characters:
    if ($tags =~ /:/) {
      # Display the appropriate warning:
      print STDERR NAME . ": Invalid tags in the $type with ID $id.\n"
        if $verbose;

      # Strip forbidden characters:
      $tags =~ s/://g;
      $tags =~ s/,+/,/;
      $tags =~ s/\s{2,}/ /;
      ($data->{header}->{tags} = $tags) =~ s/^,|,$//g;
    }
  }
  else {
    # Assign the default value:
    $data->{header}->{tags} = '';
  }

  # Check whether the URL is specified:
  if (my $url = $data->{header}->{url}) {
    # Check whether it contains forbidden characters:
    if ($url =~ /[^\w\-]/) {
      # Display the appropriate warning:
      print STDERR NAME . ": Invalid URL in the $type with ID $id.\n"
        if $verbose;

      # Strip forbidden characters and substitute spaces:
      $url =~ s/[^\w\s\-]//g;
      ($data->{header}->{url} = $url) =~ s/\s/-/g;
    }
  }
  else {
    # Assign the title:
    $url = lc($data->{header}->{title});

    # Strip forbidden characters:
    $url =~ s/[^\w\s\-]//g;
    ($data->{header}->{url} = $url) =~ s/\s/-/g;
  }

  # Return success:
  return 1;
}

# Return the list of posts/pages header records:
sub collect_headers {
  my $type    = shift || 'post';
  my $head    = catdir($blogdir, '.blaze', "${type}s", 'head');
  my @records = ();

  # Open the headers directory:
  opendir(HEAD, $head) or return @records;

  # Process each file:
  while (my $id = readdir(HEAD)) {
    # Skip both . and ..:
    next if $id =~ /^\.\.?$/;

    # Parse the header data:
    my $data = ReadINI(catfile($head, $id)) or next;

    # Fix the erroneous or missing header data:
    fix_header($data, $id, $type);

    # Add the record to the beginning of the list:
    push(@records, $data->{header}->{date}   . ':' . $id . ':' .
                   $data->{header}->{tags}   . ':' .
                   $data->{header}->{author} . ':' .
                   $data->{header}->{url}    . ':' .
                   $data->{header}->{title});
  }

  # Close the directory:
  closedir(HEAD);

  # Return the result:
  return @records;
}

# Collect the necessary metadata:
sub collect_metadata {
  my $tags   = {};
  my $months = {};

  # Prepare the list of month names:
  my @month  = qw( January February March April May June July
                   August September October November December );

  # Collect the pages headers:
  my @pages  = collect_headers('page');

  # Collect the posts headers:
  my @posts  = collect_headers('post');

  # Process each post header:
  foreach(@posts) {
    # Decompose the post record:
    $_ =~ /^([^:]*):[^:]*:([^:]*):[^:]*:[^:]*:.*$/;

    # Prepare the information:
    my $date = substr($1, 0, 7);
    my $name = $month[int(substr($1, 5, 2)) - 1] . " " . substr($1, 0, 4);
    my @tags = split(/,\s*/, $2);

    # Check whether the month is already present:
    if ($months->{$name}) {
      # Increase the counter:
      $months->{$name}->{count}++;
    }
    else {
      # Prepare the URL:
      (my $url = $date) =~ s/-/\//;

      # Set up the URL:
      $months->{$name}->{url}   = "$url/";

      # Set up the counter:
      $months->{$name}->{count} = 1;
    }

    # Process each tag separately:
    foreach my $tag (@tags) {
      # Check whether the tag is already present:
      if ($tags->{$tag}) {
        # Increase the counter:
        $tags->{$tag}->{count}++;
      }
      else {
        # Prepare an URL:
        (my $url = $tag) =~ s/[^\w\s\-]//g; $url =~ s/\s/-/g;

        # Set up the URL:
        $tags->{$tag}->{url}   = "$url/";

        # Set up the counter:
        $tags->{$tag}->{count} = 1;
      }
    }
  }

  # Return the result:
  return {
    'posts'  => \@posts,
    'pages'  => \@pages,
    'tags'   => $tags,
    'months' => $months,
  };
}

# Return the theme file with most of the placeholders substituted:
sub read_theme {
  my $data     = shift || return 0;
  my $root     = shift || '/';
  my $result   = '';

  # Read required data from the configuration:
  my $theme    = $conf->{blog}->{theme}    || 'default.html';
  my $style    = $conf->{blog}->{style}    || 'default.css';
  my $title    = $conf->{blog}->{title}    || 'My Blog';
  my $subtitle = $conf->{blog}->{subtitle} || 'yet another blog';
  my $encoding = $conf->{core}->{encoding} || 'UTF-8';
  my $name     = $conf->{user}->{name}     || 'admin';

  # Get the current year:
  my $year     = substr(date_to_string(time), 0, 4);

  # Prepare the meta and link elements:
  my $content_type = '<meta http-equiv="Content-Type" content="text/html;'.
                     ' charset=' . $encoding . '">';
  my $generator    = '<meta name="Generator" content="' . NAME . ' ' .
                     VERSION . '">';
  my $date         = '<meta name="Date" content="' . 
                     strftime("%a %b %e %H:%M:%S %Y", localtime) . '">';
  my $stylesheet   = '<link rel="stylesheet" href="' . $root . 'style/' .
                     $style . '" type="text/css">';

  # Prepare the list of tags:
  my $tags     = $data->{tags}
                 ? join("\n", map {
                     '<li><a href="' . $root . 'tags/' .
                     $data->{tags}->{$_}->{url} . '">' . $_ . '</a> (' .
                     $data->{tags}->{$_}->{count} . ')</li>'
                   } sort(keys(%{$data->{tags}})))
                 : '';

  # Prepare the archive list::
  my $archive  = $data->{months}
                 ? join("\n", map {
                     '<li><a href="' . $root . $data->{months}->{$_}->{url}.
                     '">' . $_ . '</a> (' . $data->{months}->{$_}->{count} .
                     ')</li>'
                   } sort(keys(%{$data->{months}})))
                 : '';

  # TODO: Prepare the list of pages:
  my $pages    = '';

  # Open the file for reading:
  open(FILE, catfile($blogdir, '.blaze', 'theme', $theme)) or return 0;

  # Process each line:
  while (my $line = <FILE>) {
    # Substitute header placeholders:
    $line =~ s/<!--\s*content-type\s*-->/$content_type/i;
    $line =~ s/<!--\s*generator\s*-->/$generator/i;
    $line =~ s/<!--\s*date\s*-->/$date/i;
    $line =~ s/<!--\s*stylesheet\s*-->/$stylesheet/i;

    # Substitute sidebar placeholders:
    $line =~ s/<!--\s*pages\s*-->/$pages/i;
    $line =~ s/<!--\s*tags\s*-->/$tags/i;
    $line =~ s/<!--\s*archive\s*-->/$archive/i;

    # Substitute body placeholders:
    $line =~ s/<!--\s*title\s*-->/$title/ig;
    $line =~ s/<!--\s*subtitle\s*-->/$subtitle/ig;
    $line =~ s/<!--\s*name\s*-->/$name/ig;
    $line =~ s/<!--\s*year\s*-->/$year/ig;

    # Add the line to the result:
    $result .= $line;
  }

  # Close the file:
  close(FILE);

  # Return the result:
  return $result;
}

# Generate posts:
sub generate_posts {
  my $data  = shift || die "Missing argument";
  my $ext   = $conf->{core}->{extension} || 'html';
  my $body  = '';

  # Prepare the template:
  my $theme = read_theme($data, '../../../');

  # Process each record:
  foreach my $record (sort { $b cmp $a } @{$data->{posts}}) {
    my ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
    my ($year, $month) = split(/-/, $date);

    # Prepare the post heading:
    my $heading = << "END_HEADING";
<div class="heading">
  <h2>$title</h2>
  <span class="date">$date</span> |
  posted by: <span class="author">$author</span> |
  tagged as: <span class="tags">$tags</span>
</div>
END_HEADING

    # Open the body file for reading:
    open(FILE, catfile($blogdir, '.blaze', 'posts', 'body', $id))
      or return 0;

    # Read the content of the file:
    $body = do { local $/; <FILE> };

    # Close the file:
    close(FILE);

    # Substitute the placeholder in the template:
    (my $page = $theme) =~ s/<!--\s*content\s*-->/$heading$body/ig;

    # Create the directories:
    make_directories [
      catdir($destdir, $year),                      # Year directory.
      catdir($destdir, $year, $month),              # Month directory.
      catdir($destdir, $year, $month, "$id-$url"),  # Post directory.
    ];

    # Write the index file:
    write_to_file(catfile($destdir, $year, $month, "$id-$url",
                          "index.$ext"), $page) or return 0;
  }

  # Return success:
  return 1;
}

# Generate pages:
sub generate_pages {
  my $data  = shift || die "Missing argument";
  my $ext   = $conf->{core}->{extension} || 'html';
  my $body  = '';

  # Prepare the template:
  my $theme = read_theme($data, '../');

  # Process each record:
  foreach my $record (sort { $b cmp $a } @{$data->{pages}}) {
    my ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
    my ($year, $month) = split(/-/, $date);

    # Prepare the post heading:
    my $heading = << "END_HEADING";
<div class="heading">
  <h2>$title</h2>
</div>
END_HEADING

    # Open the body file for reading:
    open(FILE, catfile($blogdir, '.blaze', 'pages', 'body', $id))
      or return 0;

    # Read the content of the file:
    $body = do { local $/; <FILE> };

    # Close the file:
    close(FILE);

    # Substitute the placeholder in the template:
    (my $page = $theme) =~ s/<!--\s*content\s*-->/$heading$body/ig;

    # Create the directories:
    make_directories [ catdir($destdir, $url) ];    # Page directory.

    # Write the index file:
    write_to_file(catfile($destdir, $url, "index.$ext"), $page)
      or return 0;
  }

  # Return success:
  return 1;
}

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
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
  'destdir|d=s'   => sub { $destdir = $_[1]; },
);

# Check superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Prepare the file name:
my $temp = catfile($blogdir, '.blaze', 'config');

# Read the configuration file:
$conf    = ReadINI($temp)
           or exit_with_error("Unable to read `$temp'.", 13);

# Collect the necessary metadata:
my $data = collect_metadata();

# Generate pages:
# ...

# Generate posts:
generate_posts($data);

# Generate archives:
generate_pages($data);

# Generate tags:
# ...

# Generate index page:
# ...

# Generate RSS feed:
# ...

# Return success:
exit 0;
