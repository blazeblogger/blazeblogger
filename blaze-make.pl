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

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.0.1';                    # Script version.

# General script settings:
our $blogdir    = '.';                              # Repository location.
our $destdir    = '.';                              # HTML pages location.
our $verbose    = 1;                                # Verbosity level.
our $with_posts = 1;                                # Generate posts?
our $with_pages = 1;                                # Genetate pages?
our $with_tags  = 1;                                # Generate tags?
our $with_rss   = 1;                                # Generate RSS feed?

# Global variables:
our $conf       = {};                               # The configuration.

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
Usage: $NAME [-qV] [-b directory] [-d directory]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -d, --destdir directory     specify the directory where the generated
                              static content is to be placed 
  -q, --quiet                 avoid displaying unnecessary messages
  -V, --verbose               display all messages; the default option

  --no-posts                  disable posts creation
  --no-pages                  disable static pages creation
  --no-tags                   disable support for tags
  --no-rss                    disable RSS feed creation

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

# Translate given date to YYYY-MM-DD string:
sub date_to_string {
  my @date = localtime(shift);
  return sprintf("%d-%02d-%02d", ($date[5] + 1900), ++$date[4], $date[3]);
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
    }

    # Strip superfluous spaces and commas:
    $tags =~ s/,+/,/g;
    $tags =~ s/\s{2,}/ /g;
    ($data->{header}->{tags} = $tags) =~ s/^,|,$//g;
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
  return sort { $b cmp $a } @records;
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
      # Make the tag lower case:
      $tag = lc($tag);

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

# Return the list of months:
sub list_of_months {
  my $data = shift || die "Missing argument";
  my $root = shift || '/';

  # Check whether the posts generation is enabled:
  return '' unless $with_posts;

  # Check whether the list is not empty:
  if (my %months = %{$data->{months}}) {
    # Return the list of months:
    return join("\n", sort { $b cmp $a } (map {
      "<li><a href=\"${root}" . $months{$_}->{url} . "\">$_</a> (" .
      $months{$_}->{count} . ")</li>"
    } keys(%months)));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return the list of pages:
sub list_of_pages {
  my $data = shift || die "Missing argument";
  my $root = shift || '/';
  my $list = '';

  # Check whether the pages generation is enabled:
  return '' unless $with_pages;

  # Process each page separately:
  foreach (sort @{$data->{pages}}) {
    # Decompose the page record:
    $_ =~ /^[^:]*:[^:]*:[^:]*:[^:]*:([^:]*):(.*)$/;

    # Add the page link to the list:
    $list .= "<li><a href=\"$root$1\">$2</a></li>\n";
  }

  # Return the list of pages:
  return $list;
}

# Return the list of tags:
sub list_of_tags {
  my $data = shift || die "Missing argument";
  my $root = shift || '/';

  # Check whether the tags generation is eneabled:
  return '' unless $with_tags;

  # Check whether the list is not empty:
  if (my %tags = %{$data->{tags}}) {
    # Return the list of tags:
    return join("\n", map {
      "<li><a href=\"${root}tags/" . $tags{$_}->{url} . "\">$_</a> (" .
      $tags{$_}->{count} . ")</li>"
    } sort(keys(%tags)));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Write a single page:
sub write_page {
  my $file     = shift || die "Missing argument";
  my $data     = shift || return 0;
  my $content  = shift || '';
  my $root     = shift || '/';

  # Read required data from the configuration:
  my $encoding = $conf->{core}->{encoding} || 'UTF-8';
  my $name     = $conf->{user}->{name}     || 'admin';
  my $style    = $conf->{blog}->{style}    || 'default.css';
  my $subtitle = $conf->{blog}->{subtitle} || 'yet another blog';
  my $theme    = $conf->{blog}->{theme}    || 'default.html';
  my $title    = $conf->{blog}->{title}    || 'My Blog';

  # Prepare the pages, tags and months lists:
  my $archive  = list_of_months($data, $root);
  my $pages    = list_of_pages($data, $root);
  my $tags     = list_of_tags($data, $root);

  # Get the current year:
  my $year     = substr(date_to_string(time), 0, 4);

  # Prepare the meta and link elements for the page header:
  my $date         = '<meta name="Date" content="' . localtime() . '">';
  my $content_type = '<meta http-equiv="Content-Type" content="text/html;'.
                     ' charset=' . $encoding . '">';
  my $generator    = '<meta name="Generator" content="BlazeBlogger ' .
                     VERSION . '">';
  my $stylesheet   = '<link rel="stylesheet" href="' . $root . 'style/' .
                     $style . '" type="text/css">';

  # Open the theme file for reading:
  open(THEME, catfile($blogdir, '.blaze', 'theme', $theme)) or return 0;

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Process each line:
  while (my $line = <THEME>) {
    # Substitute lists placeholders:
    $line =~ s/<!--\s*archive\s*-->/$archive/i if $archive;
    $line =~ s/<!--\s*pages\s*-->/$pages/i     if $pages;
    $line =~ s/<!--\s*tags\s*-->/$tags/i       if $tags;

    # Substitute header placeholders:
    $line =~ s/<!--\s*content-type\s*-->/$content_type/i;
    $line =~ s/<!--\s*date\s*-->/$date/i;
    $line =~ s/<!--\s*generator\s*-->/$generator/i;
    $line =~ s/<!--\s*stylesheet\s*-->/$stylesheet/i;

    # Substitute body placeholders:
    $line =~ s/<!--\s*name\s*-->/$name/ig;
    $line =~ s/<!--\s*subtitle\s*-->/$subtitle/ig;
    $line =~ s/<!--\s*title\s*-->/$title/ig;
    $line =~ s/<!--\s*year\s*-->/$year/ig;

    # Substitute the content:
    $line =~ s/<!--\s*content\s*-->/$content/ig if $content;

    # Write the line to the file:
    print FILE $line;
  }

  # Close the files:
  close(THEME);
  close(FILE);

  # Return success:
  return 1;
}

# Read the post/page body/excerpt:
sub read_body {
  my $id      = shift || die "Missing argument";
  my $type    = shift || 'post';
  my $excerpt = shift || 0;
  my $file    = catfile($blogdir, '.blaze', "${type}s", 'body', $id);
  my $result  = '';

  # Open the body file for reading:
  open(FILE, $file) or return '';

  # Read the content of the file:
  while (my $line = <FILE>) {
    # When excerpt is requested, look for a break mark to stop reading:
    last if $line =~ /<!--\s*break\s*-->/ && $excerpt;

    # Add the line to the result:
    $result .= $line;
  }

  # Close the file:
  close(FILE);

  # Return the result:
  return $result;
}

# Return the formatted post heading:
sub format_heading {
  my $title  = shift || die "Missing argument";
  my $date   = shift || die "Missing argument";
  my $author = shift || die "Missing argument";
  my $tags   = shift;

  # Return the formatted post heading:
  return "<h2>$title</h2>\n\n<p style=\"foo\">\n" .
         "<span style=\"date\">$date</span> " .
         "by <span style=\"author\">$author</span>" .
         (($with_tags && $tags)
           ? ", tagged as <span style=\"tags\">$tags</span>.\n"
           : ".\n"
         ) . "</p>\n\n";
}

# Generate posts:
sub generate_posts {
  my $data         = shift || die "Missing argument";

  # Read required data from the configuration:
  my $ext          = $conf->{core}->{extension} || 'html';
  my $max_posts    = $conf->{blog}->{posts}     || 20;

  # Initialize necessary variables:
  my $post_body    = '';
  my $month_body   = '';
  my $month_curr   = '';
  my $month_last   = '';
  my $month_count  = 0;
  my $month_page   = 0;
  my ($date, $id, $tags, $author, $url, $title, $year, $month, $file);

  # Process each record:
  foreach my $record (@{$data->{posts}}) {
    # Decompose the record:
    ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
    ($year, $month) = split(/-/, $date);

    # Prepare the post body:
    $post_body  = format_heading($title, $date, $author, $tags) .
                  read_body($id, 'post', 0);

    # Create the directory tree:
    make_directories [
      catdir($destdir, $year),                      # Year directory.
      catdir($destdir, $year, $month),              # Month directory.
      catdir($destdir, $year, $month, "$id-$url"),  # Post directory.
    ];

    # Prepare the post file name:
    $file = catfile($destdir, $year, $month, "$id-$url", "index.$ext");

    # Write the post:
    write_page($file, $data, $post_body, '../../../') or return 0;

    # Report success:
    print "Created $file\n" if $verbose > 1;

    # If this is the first loop, fake the previous month as the current:
    $month_last = "$year/$month" unless $month_last;

    # Set the current month:
    $month_curr = "$year/$month";

    # Check whether the month has changed  or whether the  number of listed
    # posts reached the limit:
    if (($month_last ne $month_curr) || ($month_count == $max_posts)) {
      # Prepare information for the page navigation:
      my $index = $month_page     || '';
      my $next  = $month_page - 1 || '';
      my $prev  = $month_page + 1;

      # Get information about the last processed month:
      ($year, $month) = split(/\//, $month_last);

      # Add heading:
      $month_body  = "<p>$year/$month</p>\n\n$month_body";

      # Add navigation:
      $month_body .= "<a href=\"index$prev.$ext\">prev</a>\n"
        if $month_curr eq $month_last;
      $month_body .= "<a href=\"index$next.$ext\">next</a>\n"
        if $month_page;

      # Prepare the page file name:
      $file = catfile($destdir, $year, $month, "index$index.$ext");

      # Write the page:
      write_page($file, $data, $month_body, '../../') or return 0;

      # Check whether the month has changed:
      if ($month_curr ne $month_last) {
        # Reset the page counter:
        $month_page = 0;
      }
      else {
        # Increase the page counter:
        $month_page++;
      }

      # Make the previous month be the current one:
      $month_last = $month_curr;

      # Clear the listing body:
      $month_body = '';

      # Reset the item counter:
      $month_count = 0;

      # Report success:
      print "Created $file\n" if $verbose > 1;
    }

    # Add the post heading with excerpt:
    $month_body .= format_heading("<a href=\"$id-$url\">$title</a></h2>",
                                  $date, $author, $tags) .
                   read_body($id, 'post', 1);

    # Increase the number of listed items:
    $month_count++;
  }

  # Check whether there are unwritten data:
  if ($month_body) {
    # Prepare information for the page navigation:
    my $index = $month_page     || '';
    my $next  = $month_page - 1 || '';

    # Get information about the last processed month:
    ($year, $month) = split(/\//, $month_curr);

    # Add heading:
    $month_body  = "<p>$year/$month</p>\n\n$month_body";

    # Add navigation:
    $month_body .= "<a href=\"index$next.$ext\">next</a>\n" if $month_page;

    # Prepare the page file name:
    $file = catfile($destdir, $year, $month, "index$index.$ext");

    # Write the page:
    write_page($file, $data, $month_body, '../../') or return 0;

    # Report success:
    print "Created $file\n" if $verbose > 1;
  }

  # TODO: Generate year listings.

  # Return success:
  return 1;
}

# Generate tags:
sub generate_tags {
  my $data = shift || die "Missing argument";

  # Read required data from the configuration:
  my $ext       = $conf->{core}->{extension} || 'html';
  my $max_posts = $conf->{blog}->{posts}     || 20;

  # Process each tag separately:
  foreach my $tag (keys %{$data->{tags}}) {
    # Initialize necessary variables:
    my $tag_body  = '';
    my $tag_count = 0;
    my $tag_page  = 0;
    my ($date, $id, $tags, $author, $url, $title, $year, $month, $file);

    # Process each record:
    foreach my $record (@{$data->{posts}}) {
      # Decompose the record:
      ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
      ($year, $month) = split(/-/, $date);

      # Check whether the post contains the current tag:
      next unless $tags =~ /(^|,\s*)$tag(,\s*|$)/;

      # Check whether the number of listed posts reached the limit:
      if ($tag_count == $max_posts) {
        # Prepare information for the page navigation:
        my $index = $tag_page     || '';
        my $next  = $tag_page - 1 || '';
        my $prev  = $tag_page + 1;

        # Add heading:
        $tag_body  = "<p>$tag</p>\n\n$tag_body";

        # Add navigation:
        $tag_body .= "<a href=\"index$prev.$ext\">prev</a>\n";
        $tag_body .= "<a href=\"index$next.$ext\">next</a>\n" if $tag_page;

        # Create the directory tree:
        make_directories [
          catdir($destdir, 'tags'),
          catdir($destdir, 'tags', $data->{tags}->{$tag}->{url}),
        ];

        # Prepare the page file name:
        $file = catfile($destdir, 'tags', $data->{tags}->{$tag}->{url},
                        "index$index.$ext");

        # Write the page:
        write_page($file, $data, $tag_body, '../../') or return 0;

        # Clear the body:
        $tag_body  = '';

        # Reset the item counter:
        $tag_count = 0;

        # Increase the page counter:
        $tag_page++;

        # Report success:
        print "Created $file\n" if $verbose > 1;
      }

      # Add the post heading with excerpt:
      $tag_body .= format_heading("<a href=\"../../$year/$month/$id-$url" .
                                  "\">$title</a>", $date, $author, $tags) .
                   read_body($id, 'post', 1);

      # Increase the number of listed items:
      $tag_count++;
    }

    # Check whether there are unwritten data:
    if ($tag_body) {
      # Prepare information for the page navigation:
      my $index = $tag_page     || '';
      my $next  = $tag_page - 1 || '';

      # Add heading:
      $tag_body  = "<p>$tag</p>\n\n$tag_body";

      # Add navigation:
      $tag_body .= "<a href=\"index$next.$ext\">next</a>\n" if $tag_page;

      # Create the directory tree:
      make_directories [
        catdir($destdir, 'tags'),
        catdir($destdir, 'tags', $data->{tags}->{$tag}->{url}),
      ];

      # Prepare the page file name:
      $file = catfile($destdir, 'tags', $data->{tags}->{$tag}->{url},
                      "index$index.$ext");

      # Write the page:
      write_page($file, $data, $tag_body, '../../') or return 0;

      # Report success:
      print "Created $file\n" if $verbose > 1;
    }
  }

  # Return success:
  return 1;
}

# Generate pages:
sub generate_pages {
  my $data = shift || die "Missing argument";
  my $body = '';

  # Read required data from the configuration:
  my $ext  = $conf->{core}->{extension} || 'html';

  # Process each record:
  foreach my $record (@{$data->{pages}}) {
    my ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
    my ($year, $month) = split(/-/, $date);

    # Prepare the page body:
    $body = "<h2>$title</h2>\n\n" . read_body($id, 'page', 0);

    # Create the directories:
    make_directories [ catdir($destdir, $url) ];

    # Write the index file:
    my $file = catfile($destdir, $url, "index.$ext");
    write_page($file, $data, $body, '../') or return 0;

    # Report success:
    print "Created $file\n" if $verbose > 1;
  }

  # Return success:
  return 1;
}

# Set up the options parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command-line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'quiet|q'       => sub { $verbose    = 0;     },
  'verbose|V'     => sub { $verbose    = 2;     },
  'blogdir|b=s'   => sub { $blogdir    = $_[1]; },
  'destdir|d=s'   => sub { $destdir    = $_[1]; },
  'with-posts'    => sub { $with_posts = 1 },
  'no-posts'      => sub { $with_posts = 0 },
  'with-pages'    => sub { $with_pages = 1 },
  'no-pages'      => sub { $with_pages = 0 },
  'with-tags'     => sub { $with_tags  = 1 },
  'no-tags'       => sub { $with_tags  = 0 },
  'with-rss'      => sub { $with_rss   = 1 },
  'no-rss'        => sub { $with_rss   = 0 },
);

# Check superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check the repository is present (however naive this method is):
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# When posts are disabled, disable RSS and tags as well:
unless ($with_posts) {
  $with_tags = 0;
  $with_rss  = 0;
}

# Check whether there is anything to do:
unless ($with_posts || $with_pages) {
  # Report success:
  print "Nothing to do.\n" if $verbose;

  # Return success:
  exit 0;
}

# Prepare the file name:
my $temp = catfile($blogdir, '.blaze', 'config');

# Read the configuration file:
$conf    = ReadINI($temp)
           or exit_with_error("Unable to read `$temp'.", 13);

# Collect the necessary metadata:
my $data = collect_metadata();

# Generate posts:
generate_posts($data)
  or exit_with_error("An error has occurred while creating posts.", 1)
  if $with_posts;

# Generate tags:
generate_tags($data)
  or exit_with_error("An error has occurred while creating tags.", 1)
  if $with_tags;

# Generate pages:
generate_pages($data)
  or exit_with_error("An error has occurred while creating pages.", 1)
  if $with_pages;

# Generate index page:
# ...

# Generate RSS feed:
# ...

# Report success:
print "Done.\n" if $verbose;

# Return success:
exit 0;
