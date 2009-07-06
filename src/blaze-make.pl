#!/usr/bin/env perl

# blaze-make, generate static content from the BlazeBlogger repository
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
use File::Copy;
use File::Spec::Functions;
use Getopt::Long;
use Time::Local 'timelocal_nocheck';

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.8.1';                    # Script version.

# General script settings:
our $blogdir    = '.';                              # Repository location.
our $destdir    = '.';                              # HTML pages location.
our $verbose    = 1;                                # Verbosity level.
our $with_index = 1;                                # Generate index page?
our $with_posts = 1;                                # Generate posts?
our $with_pages = 1;                                # Generate pages?
our $with_tags  = 1;                                # Generate tags?
our $with_rss   = 1;                                # Generate RSS feed?
our $with_css   = 1;                                # Generate stylesheet?
our $full_paths = 0;                                # Generate full paths?

# Global variables:
our $conf       = {};                               # The configuration.
our $locale     = {};                               # The localization.
our $cache      = {};                               # The cache.

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
Usage: $NAME [-pqrtFPV] [-b directory] [-d directory]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -d, --destdir directory     specify the directory where the generated
                              static content is to be placed
  -c, --no-css                disable stylesheet creation
  -i, --no-index              disable index page creation
  -p, --no-posts              disable blog posts creation
  -P, --no-pages              disable pages creation
  -t, --no-tags               disable support for tags
  -r, --no-rss                disable RSS feed creation
  -F, --full-paths            enable full paths creation
  -q, --quiet                 avoid displaying unnecessary messages
  -V, --verbose               display all messages including the list of
                              created files
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

# Translate given date to RFC 822 format string:
sub rfc_822_date {
  my @date = localtime(shift);

  # Prepare the aliases:
  my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
  my @days   = qw( Sun Mon Tue Wed Thu Fri Sat );

  # Return the result:
  return sprintf("%s, %02d %s %d %02d:%02d:%02d GMT", $days[$date[6]],
                 $date[3], $months[$date[4]], 1900 + $date[5],
                 $date[2], $date[1], $date[0]);
}

# Create given directories:
sub make_directories {
  my $dirs = shift || die 'Missing argument';
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

# Read data from the INI file:
sub read_ini {
  my $file    = shift || die 'Missing argument';
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

# Fix the erroneous or missing header data:
sub fix_header {
  my $data = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my $type = shift || die 'Missing argument';

  # Check whether the title is specified:
  unless ($data->{header}->{title}) {
    # Display the appropriate warning:
    print STDERR "Missing title in the $type with ID $id.\n";

    # Assign the default value:
    $data->{header}->{title} = $id;
  }

  # Check whether the author is specified:
  if (my $author = $data->{header}->{author}) {
    # Check whether it contains forbidden characters:
    if ($author =~ /:/) {
      # Display the appropriate warning:
      print STDERR "Invalid author in the $type with ID $id.\n";

      # Strip forbidden characters:
      $data->{header}->{author} = s/://g;
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR "Missing author in the $type with ID $id.\n";

    # Assign the default value:
    $data->{header}->{author} = 'admin';
  }

  # Check whether the date is specified:
  if (my $date = $data->{header}->{date}) {
    # Check whether the format is valid:
    if ($date !~ /\d{4}-[01]\d-[0-3]\d/) {
      # Display the appropriate warning:
      print STDERR "Invalid date in the $type with ID $id.\n";

      # Use the current date instead:
      $data->{header}->{date} = date_to_string(time);
    }
  }
  else {
    # Display the appropriate warning:
    print STDERR "Missing date in the $type with ID $id.\n";

    # Assign the default value:
    $data->{header}->{date} = date_to_string(time);
  }

  # Check whether the tags are specified:
  if (my $tags = $data->{header}->{tags}) {
    # Check whether they contain forbidden characters:
    if ($tags =~ /:/) {
      # Display the appropriate warning:
      print STDERR "Invalid tags in the $type with ID $id.\n";

      # Strip forbidden characters:
      $tags =~ s/://g;
    }

    # Make all tags lower case:
    $tags = lc($tags);

    # Strip superfluous spaces:
    $tags =~ s/\s{2,}/ /g;
    $tags =~ s/\s+$//;

    # Strip trailing commas:
    $tags =~ s/^,+|,+$//g;

    # Remove duplicates:
    my %temp = map { $_, 1 } split(/,+\s*/, $tags);
    $data->{header}->{tags} = join(', ', keys(%temp));
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
      print STDERR "Invalid URL in the $type with ID $id.\n";

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

# Append proper index file name to the end of the URL if requested:
sub fix_url {
  my $url = shift || die 'Missing argument';

  # Check whether the full path is enabled:
  if ($full_paths) {
    # Append slash if missing:
    $url .= "/" unless $url =~ /\/$/;

    # Append index file name:
    $url .= "index." . ($conf->{core}->{extension} || 'html');
  }

  # Return the correct URL:
  return $url;
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
    my $data = read_ini(catfile($head, $id)) or next;

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
  my @month  = qw( january february march april may june july
                   august september october november december );

  # Collect the pages headers:
  my @pages  = collect_headers('page');

  # Collect the posts headers:
  my @posts  = collect_headers('post');

  # Process each post header:
  foreach(@posts) {
    # Decompose the post record:
    $_ =~ /^([^:]*):[^:]*:([^:]*):[^:]*:[^:]*:.*$/;

    # Prepare the information:
    my @tags = split(/,\s*/, $2);
    my $date = substr($1, 0, 7);
    my $temp = $month[int(substr($1, 5, 2)) - 1];
    my $name = ($locale->{lang}->{$temp} || $temp). " " . substr($1, 0, 4);

    # Check whether the month is already present:
    if ($months->{$name}) {
      # Increase the counter:
      $months->{$name}->{count}++;
    }
    else {
      # Prepare the URL:
      (my $url = $date) =~ s/-/\//;

      # Set up the URL:
      $months->{$name}->{url}   = $url;

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
        $tags->{$tag}->{url}   = $url;

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

# Return the list of tags:
sub list_of_tags {
  my $data = shift || die 'Missing argument';
  my $root = shift || '/';

  # Check whether the tags generation is eneabled:
  return '' unless $with_tags;

  # Check whether the list is not empty:
  if (my %tags = %{$data->{tags}}) {
    # Return the list of tags:
    return join("\n", map {
      "<li><a href=\"" . fix_url("${root}tags/" . $tags{$_}->{url}) .
      "\">$_</a> (" . $tags{$_}->{count} . ")</li>"
    } sort(keys(%tags)));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return the list of months:
sub list_of_months {
  my $data = shift || die 'Missing argument';
  my $root = shift || '/';
  my $year = shift || '';

  # Check whether the posts generation is enabled:
  return '' unless $with_posts;

  # Check whether the list is not empty:
  if (my %months = %{$data->{months}}) {
    # Return the list of months:
    return join("\n", sort { $b cmp $a } (map {
      "<li><a href=\"" . fix_url($root . $months{$_}->{url}) .
      "\">$_</a> (" . $months{$_}->{count} . ")</li>"
    } grep(/$year$/, keys(%months))));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return the list of pages:
sub list_of_pages {
  my $data = shift || die 'Missing argument';
  my $root = shift || '/';
  my $list = '';

  # Check whether the pages generation is enabled:
  return $list unless $with_pages;

  # Process each page separately:
  foreach (sort @{$data->{pages}}) {
    # Decompose the page record:
    $_ =~ /^[^:]*:[^:]*:[^:]*:[^:]*:([^:]*):(.*)$/;

    # Add the page link to the list:
    $list .= "<li><a href=\"" . fix_url("$root$1") . "\">$2</a></li>\n";
  }

  # Return the list of pages:
  return $list;
}

# Return the list of posts:
sub list_of_posts {
  my $data  = shift || die 'Missing argument';
  my $root  = shift || '/';
  my $max   = shift || 5;
  my $list  = '';

  # Check whether the posts generation is enabled:
  return $list unless $with_posts;

  # Initialize the counter:
  my $count = 0;

  # Process each post separately:
  foreach my $record (@{$data->{posts}}) {
    # Stop when the post count reaches the limit:
    last if $count == $max;

    # Decompose the record:
    my ($date, $id, undef, undef, $url, $title) = split(/:/, $record, 6);
    my ($year, $month) = split(/-/, $date);

    # Add the post link to the list:
    $list .= "<li><a href=\"" . fix_url("$root$year/$month/$id-$url") .
             "\">$title</a></li>\n";

    # Increase the counter:
    $count++;
  }

  # Return the list of posts:
  return $list;
}

# Write a single page:
sub write_page {
  my $file     = shift || die 'Missing argument';
  my $data     = shift || return 0;
  my $content  = shift || '';
  my $root     = shift || '/';
  my $home     = fix_url($root);
  my $template = '';

  # Check whether the theme is not already cached:
  unless ($cache->{theme}->{$root}) {
    # Read required data from the configuration:
    my $encoding = $conf->{core}->{encoding}  || 'UTF-8';
    my $name     = $conf->{user}->{name}      || 'admin';
    my $email    = $conf->{user}->{email}     || 'admin@localhost';
    my $style    = $conf->{blog}->{style}     || 'default.css';
    my $subtitle = $conf->{blog}->{subtitle}  || 'yet another blog';
    my $theme    = $conf->{blog}->{theme}     || 'default.html';
    my $title    = $conf->{blog}->{title}     || 'My Blog';
    my $ext      = $conf->{core}->{extension} || 'html';

    # Prepare the pages, tags and months lists:
    my $tags     = list_of_tags($data, $root);
    my $archive  = list_of_months($data, $root);
    my $pages    = list_of_pages($data, $root);
    my $posts    = list_of_posts($data, $root);

    # Get the current year:
    my $year     = substr(date_to_string(time), 0, 4);

    # Prepare the meta and link elements for the page header:
    my $date         = "<meta name=\"Date\" content=\"".localtime()."\">";
    my $content_type = "<meta http-equiv=\"Content-Type\" content=\"" .
                       "text/html; charset=$encoding\">";
    my $generator    = "<meta name=\"Generator\" content=\"BlazeBlogger " .
                       VERSION . "\">";
    my $stylesheet   = "<link rel=\"stylesheet\" href=\"$root$style\"" .
                       " type=\"text/css\">";
    my $rss          = "<link rel=\"alternate\" href=\"${root}index.rss\"".
                       " title=\"RSS Feed\" type=\"application/rss+xml\">";

    # Open the theme file for reading:
    open(THEME, catfile($blogdir, '.blaze', 'theme', $theme)) or return 0;

    # Read the theme file:
    $template = do { local $/; <THEME> };

    # Close the theme file:
    close(THEME);

    # Substitute header placeholders:
    $template =~ s/<!--\s*rss\s*-->/$rss/ig if $with_rss;
    $template =~ s/<!--\s*content-type\s*-->/$content_type/ig;
    $template =~ s/<!--\s*stylesheet\s*-->/$stylesheet/ig;
    $template =~ s/<!--\s*generator\s*-->/$generator/ig;
    $template =~ s/<!--\s*date\s*-->/$date/ig;

    # Substitute lists placeholders:
    $template =~ s/<!--\s*tags\s*-->/$tags/ig;
    $template =~ s/<!--\s*archive\s*-->/$archive/ig;
    $template =~ s/<!--\s*pages\s*-->/$pages/ig;
    $template =~ s/<!--\s*posts\s*-->/$posts/ig;

    # Substitute body placeholders:
    $template =~ s/<!--\s*subtitle\s*-->/$subtitle/ig;
    $template =~ s/<!--\s*e-mail\s*-->/$email/ig;
    $template =~ s/<!--\s*title\s*-->/$title/ig;
    $template =~ s/<!--\s*name\s*-->/$name/ig;
    $template =~ s/<!--\s*year\s*-->/$year/ig;

    # Store the theme to the cache:
    $cache->{theme}->{$root} = $template;
  }

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Add page content:
  ($template  = $cache->{theme}->{$root})
              =~ s/<!--\s*content\s*-->/$content/ig;

  # Substitute the root directory placeholder:
  $template   =~ s/%root%/$root/ig;

  # Substitute the home page placeholder:
  $template   =~ s/%home%/$home/ig;

  # Write the line to the file:
  print FILE $template;

  # Close the file:
  close(FILE);

  # Return success:
  return 1;
}

# Read the post/page body/excerpt:
sub read_body {
  my $id      = shift || die 'Missing argument';
  my $type    = shift || 'post';
  my $excerpt = shift || 0;
  my $link    = shift || '';
  my $file    = catfile($blogdir, '.blaze', "${type}s", 'body', $id);
  my $result  = '';

  # Open the body file for reading:
  open(FILE, $file) or return '';

  # Read the content of the file:
  while (my $line = <FILE>) {
    # When excerpt is requested, look for a break mark to stop reading:
    if ($line =~ /<!--\s*break\s*-->/ && $excerpt) {
      # Check whether the link is provided:
      if ($link) {
        # Read required data from the language file:
        my $more = $locale->{lang}->{more} || 'Read more &raquo;';

        # Add the `read more' link:
        $result .= "<p><a href=\"" . fix_url($link) . "\">$more</a></p>\n";
      }

      # Exit the loop:
      last;
    }

    # Add the line to the result:
    $result .= $line;
  }

  # Close the file:
  close(FILE);

  # Return the result:
  return $result;
}

# Return the tag links:
sub format_tags {
  my $data = shift || die 'Missing argument';
  my $root = shift || die 'Missing argument';
  my $tags = shift || return '';

  # Return the list of tag links:
  return join(', ', map {
    "<a href=\"" . fix_url("${root}tags/" . $data->{tags}->{$_}->{url}) .
    "\">$_</a>"
  } split(/,\s*/, $tags));
}

# Return the formatted post heading:
sub format_heading {
  my $title  = shift || die 'Missing argument';
  my $date   = shift || die 'Missing argument';
  my $author = shift || die 'Missing argument';
  my $tags   = shift;

  # Read required data from the language file:
  my $posted_by = $locale->{lang}->{postedby} || 'by';
  my $tagged_as = $locale->{lang}->{taggedas} || 'tagged as';

  # Return the formatted post heading:
  return "<h2 class=\"post\">$title</h2>\n\n" .
         "<div class=\"information\">\n  " .
         "<span class=\"date\">$date</span> " .
         "$posted_by <span class=\"author\">$author</span>" .
         (($with_tags && $tags)
           ? ", $tagged_as <span class=\"tags\">$tags</span>.\n"
           : ".\n"
         ) . "</div>\n\n";
}

# Strip HTML elements:
sub strip_html {
  my $string = shift || die 'Missing argument';

  # Strip HTML elements and forbidded characters:
  $string =~ s/(<[^>]*>|&[^;]*;|<|>|&)//g;

  # Return the result:
  return $string;
}

# Generate RSS feed:
sub generate_rss {
  my $data          = shift || die 'Missing argument';
  my $max_posts     = 10;

  # Read required data from the configuration:
  my $ext           = $conf->{core}->{extension} || 'html';
  my $blog_title    = $conf->{blog}->{title}     || 'My Blog';
  my $blog_subtitle = $conf->{blog}->{subtitle}  || 'yet another blog';
  my $base          = $conf->{blog}->{url};

  # Check whether the base URL is specified:
  unless ($base) {
    # Display the warning:
    print STDERR "Missing blog.url option. Skipping the RSS feed.\n";

    # Disable the RSS:
    $with_rss = 0;

    # Return success:
    return 1;
  }

  # Initialize necessary variables:
  my $count      = 0;

  # Strip HTML elements:
  $blog_title    = strip_html($blog_title);
  $blog_subtitle = strip_html($blog_subtitle);

  # Strip trailing / from the base URL:
  $base =~ s/\/$//;

  # Prepare the RSS file name:
  my $file = ($destdir eq '.') ? 'index.rss'
                               : catfile($destdir, 'index.rss');

  # Open the file for writing:
  open(RSS, ">$file") or return 0;

  # Write the RSS header:
  print RSS "<?xml version=\"1.0\"?>\n<rss version=\"2.0\">\n<channel>\n" .
            "  <title>$blog_title</title>\n" .
            "  <link>$base/</link>\n" .
            "  <description>$blog_subtitle</description>\n" .
            "  <generator>BlazeBlogger " . VERSION . "</generator>\n";

  # Process the requested number of posts:
  foreach my $record (@{$data->{posts}}) {
    # Stop when the post count reaches the limit:
    last if $count == $max_posts;

    # Decompose the record:
    my ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
    my ($year, $month, $day) = split(/-/, $date);

    # Strip HTML elements:
    my $post_title = strip_html($title);
    my $post_desc  = strip_html(substr(read_body($id, 'post', 1), 0, 500));

    # Get the RFC 822 date-time string:
    my $time       = timelocal_nocheck(1, 0, 0, $day, ($month - 1), $year);
    my $date_time  = rfc_822_date($time);

    # Add the post item:
    print RSS "  <item>\n    <title>$post_title</title>\n  " .
              "  <link>$base/$year/$month/$id-$url/index.$ext</link>\n  " .
              "  <description>$post_desc    </description>\n  " .
              "  <pubDate>$date_time</pubDate>\n" .
              "  </item>\n";

    # Increase the number of listed items:
    $count++;
  }

  # Write the RSS footer:
  print RSS "</channel>\n</rss>";

  # Close the file:
  close(RSS);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Generate index page:
sub generate_index {
  my $data      = shift || die 'Missing argument';
  my $body      = '';

  # Read required data from the configuration:
  my $ext       = $conf->{core}->{extension} || 'html';
  my $max_posts = $conf->{blog}->{posts}     || 10;

  # Initialize necessary variables:
  my $count     = 0;

  # Check whether the posts are enabled:
  if ($with_posts) {
    # Process the requested number of posts:
    foreach my $record (@{$data->{posts}}) {
      # Stop when the post count reaches the limit:
      last if $count == $max_posts;

      # Decompose the record:
      my ($date, $id, $tags, $author, $url, $title) = split(/:/,$record,6);
      my ($year, $month) = split(/-/, $date);

      # Add the post heading with excerpt:
      $body.=format_heading("<a href=\"" .fix_url("$year/$month/$id-$url").
                            "\">$title</a>",
                            $date, $author,
                            format_tags($data, './', $tags)) .
             read_body($id, 'post', 1, "$year/$month/$id-$url");

      # Increase the number of listed items:
      $count++;
    }
  }

  # Prepare the index file name:
  my $file = ($destdir eq '.') ? "index.$ext"
                               : catfile($destdir, "index.$ext");

  # Write the index file:
  write_page($file, $data, $body, './') or return 0;

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}


# Generate posts:
sub generate_posts {
  my $data         = shift || die 'Missing argument';

  # Read required data from the configuration:
  my $ext          = $conf->{core}->{extension}  || 'html';
  my $max_posts    = $conf->{blog}->{posts}      || 10;

  # Read required data from the localization:
  my $title_string = $locale->{lang}->{archive}  || 'Archive for';
  my $prev_string  = $locale->{lang}->{previous} || '&laquo; previous';
  my $next_string  = $locale->{lang}->{next}     || 'next &raquo;';

  # Prepare the list of month names:
  my @names        = qw( january february march april may june july
                         august september october november december );

  # Initialize post related variables:
  my $post_body    = '';                            # Blog post content.

  # Inicialize yearly archive related variables:
  my $year_body    = '';                            # List of months.
  my $year_curr    = '';                            # Current year.
  my $year_last    = '';                            # Last processed year.

  # Initialize monthly archive related variables:
  my $month_body   = '';                            # List of posts.
  my $month_curr   = '';                            # Current month.
  my $month_last   = '';                            # Last processed month.
  my $month_count  = 0;                             # Post counter.
  my $month_page   = 0;                             # Page counter.

  # Declare other necessary variables:
  my ($date, $id, $tags, $author, $url, $title, $year, $month, $file);

  # Process each record:
  foreach my $record (@{$data->{posts}}) {
    # Decompose the record:
    ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
    ($year, $month) = split(/-/, $date);

    # Prepare the post body:
    $post_body  = format_heading($title, $date, $author,
                                 format_tags($data, '../../../', $tags)) .
                  read_body($id, 'post', 0);

    # Create the directory tree:
    make_directories [
      catdir($destdir, $year),                      # Year directory.
      catdir($destdir, $year, $month),              # Month directory.
      catdir($destdir, $year, $month, "$id-$url"),  # Post directory.
    ];

    # Prepare the post file name:
    if ($destdir eq '.') {
      $file = catfile($year, $month, "$id-$url", "index.$ext");
    }
    else {
      $file = catfile($destdir, $year, $month, "$id-$url", "index.$ext");
    }

    # Write the post:
    write_page($file, $data, $post_body, '../../../') or return 0;

    # Report success:
    print "Created $file\n" if $verbose > 1;

    # Set the current year:
    $year_curr = $year;

    # Check whether the year has changed:
    if ($year_last ne $year_curr) {
      # Prepare this year's archive body:
      $year_body = "<div class=\"section\">$title_string $year</div>\n\n" .
                   "<ul>\n" . list_of_months($data, '../', $year) .
                   "</ul>";

      # Prepare this year's archive file name:
      if ($destdir eq '.') {
        $file = catfile($year, "index.$ext");
      }
      else {
        $file = catfile($destdir, $year, "index.$ext");
      }

      # Write the file:
      write_page($file, $data, $year_body, '../') or return 0;

      # Make the previous year be the current one:
      $year_last = $year_curr;

      # Report success:
      print "Created $file\n" if $verbose > 1;
    }

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

      # Get information for the heading:
      my $temp = $names[int($month) - 1];
      my $name = ($locale->{lang}->{$temp} || $temp) . " $year";

      # Add heading:
      $month_body  ="<div class=\"section\">$title_string $name</div>\n\n".
                     "$month_body";

      # Add navigation:
      $month_body .= "<div class=\"navigation\">\n";
      $month_body .= "  <a href=\"index$prev.$ext\">$prev_string</a>\n"
        if $month_curr eq $month_last;
      $month_body .= "  <a href=\"index$next.$ext\">$next_string</a>\n"
        if $month_page;
      $month_body .= "</div>\n";

      # Prepare the monthly archive file name:
      if ($destdir eq '.') {
        $file = catfile($year, $month, "index$index.$ext");
      }
      else {
        $file = catfile($destdir, $year, $month, "index$index.$ext");
      }

      # Write the file:
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

      # Clear the monthly archive body:
      $month_body = '';

      # Reset the post counter:
      $month_count = 0;

      # Report success:
      print "Created $file\n" if $verbose > 1;
    }

    # Add the post heading with excerpt:
    $month_body .= format_heading("<a href=\"" . fix_url("$id-$url") .
                                  "\">$title</a>",
                                  $date, $author,
                                  format_tags($data, '../../', $tags)) .
                   read_body($id, 'post', 1, "$id-$url");

    # Increase the number of listed posts:
    $month_count++;
  }

  # Check whether there are any unwritten data:
  if ($month_body) {
    # Prepare information for the page navigation:
    my $index = $month_page     || '';
    my $next  = $month_page - 1 || '';

    # Get information about the last processed month:
    ($year, $month) = split(/\//, $month_curr);

    # Get information for the heading:
    my $temp = $names[int($month) - 1];
    my $name = ($locale->{lang}->{$temp} || $temp) . " $year";

    # Add heading:
    $month_body  = "<div class=\"section\">$title_string $name</div>\n\n" .
                   "$month_body";

    # Add navigation:
    $month_body .= "<div class=\"navigation\">\n";
    $month_body .= "  <a href=\"index$next.$ext\">$next_string</a>\n"
      if $month_page;
    $month_body .= "</div>\n";

    # Prepare the monthly archive file name:
    if ($destdir eq '.') {
      $file = catfile($year, $month, "index$index.$ext");
    }
    else {
      $file = catfile($destdir, $year, $month, "index$index.$ext");
    }

    # Write the file:
    write_page($file, $data, $month_body, '../../') or return 0;

    # Report success:
    print "Created $file\n" if $verbose > 1;
  }

  # Return success:
  return 1;
}

# Generate tags:
sub generate_tags {
  my $data         = shift || die 'Missing argument';

  # Read required data from the configuration:
  my $ext          = $conf->{core}->{extension} || 'html';
  my $max_posts    = $conf->{blog}->{posts}     || 10;

  # Read required data from the localization:
  my $title_string = $locale->{lang}->{tags}     || 'Posts tagged as';
  my $tags_string  = $locale->{lang}->{taglist}  || 'List of tags';
  my $prev_string  = $locale->{lang}->{previous} || '&laquo; previous';
  my $next_string  = $locale->{lang}->{next}     || 'next &raquo;';

  # Process each tag separately:
  foreach my $tag (keys %{$data->{tags}}) {
    # Initialize tag related variables:
    my $tag_body  = '';                             # List of posts.
    my $tag_count = 0;                              # Post counter.
    my $tag_page  = 0;                              # Page counter.

    # Declare other necessary variables:
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
        $tag_body  = "<div class=\"section\">$title_string $tag</div>\n\n".
                     "$tag_body";

        # Add navigation:
        $tag_body .= "<div class=\"navigation\">\n";
        $tag_body .= "  <a href=\"index$prev.$ext\">$prev_string</a>\n";
        $tag_body .= "  <a href=\"index$next.$ext\">$next_string</a>\n"
          if $tag_page;
        $tag_body .= "</div>\n";

        # Create the directory tree:
        make_directories [
          catdir($destdir, 'tags'),
          catdir($destdir, 'tags', $data->{tags}->{$tag}->{url}),
        ];

        # Prepare the tag file name:
        if ($destdir eq '.') {
          $file = catfile('tags', $data->{tags}->{$tag}->{url},
                          "index$index.$ext");
        }
        else {
          $file = catfile($destdir, 'tags', $data->{tags}->{$tag}->{url},
                          "index$index.$ext");
        }

        # Write the file:
        write_page($file, $data, $tag_body, '../../') or return 0;

        # Clear the tag body:
        $tag_body  = '';

        # Reset the post counter:
        $tag_count = 0;

        # Increase the page counter:
        $tag_page++;

        # Report success:
        print "Created $file\n" if $verbose > 1;
      }

      # Add the post heading with excerpt:
      $tag_body .= format_heading("<a href=\"" .
                                  fix_url("../../$year/$month/$id-$url") .
                                  "\">$title</a>", $date, $author,
                                  format_tags($data, '../../', $tags)) .
                   read_body($id, 'post', 1,"../../$year/$month/$id-$url");

      # Increase the number of listed posts:
      $tag_count++;
    }

    # Check whether there are unwritten data:
    if ($tag_body) {
      # Prepare information for the page navigation:
      my $index = $tag_page     || '';
      my $next  = $tag_page - 1 || '';

      # Add heading:
      $tag_body  = "<div class=\"section\">$title_string $tag</div>\n\n" .
                   "$tag_body";

      # Add navigation:
      $tag_body .= "<div class=\"navigation\">\n";
      $tag_body .= "  <a href=\"index$next.$ext\">$next_string</a>\n"
        if $tag_page;
      $tag_body .= "</div>\n";

      # Create the directory tree:
      make_directories [
        catdir($destdir, 'tags'),
        catdir($destdir, 'tags', $data->{tags}->{$tag}->{url}),
      ];

      # Prepare the tag file name:
      if ($destdir eq '.') {
        $file = catfile('tags', $data->{tags}->{$tag}->{url},
                        "index$index.$ext");
      }
      else {
        $file = catfile($destdir, 'tags', $data->{tags}->{$tag}->{url},
                        "index$index.$ext");
      }

      # Write the file:
      write_page($file, $data, $tag_body, '../../') or return 0;

      # Report success:
      print "Created $file\n" if $verbose > 1;
    }
  }

  # Create the tag list if any:
  if (%{$data->{tags}}) {
    # Prepare the tag list body:
    my $taglist_body = "<div class=\"section\">$tags_string</div>\n\n" .
                       "<ul>\n" . list_of_tags($data, '../') . "</ul>";

    # Prepare the tag list file name:
    my $file = ($destdir eq '.') ? catfile('tags', "index.$ext")
                                 : catfile($destdir, 'tags', "index.$ext");

    # Write the file:
    write_page($file, $data, $taglist_body, '../') or return 0;

    # Report success:
    print "Created $file\n" if $verbose > 1;
  }

  # Return success:
  return 1;
}

# Generate pages:
sub generate_pages {
  my $data = shift || die 'Missing argument';
  my $body = '';

  # Read required data from the configuration:
  my $ext  = $conf->{core}->{extension} || 'html';

  # Process each record:
  foreach my $record (@{$data->{pages}}) {
    my ($date, $id, $tags, $author, $url, $title) = split(/:/, $record, 6);
    my ($year, $month) = split(/-/, $date);

    # Prepare the page body:
    $body = "<h2 class=\"post\">$title</h2>\n\n".read_body($id, 'page', 0);

    # Create the directories:
    make_directories [ catdir($destdir, $url) ];

    # Prepare the index file name:
    my $file = ($destdir eq '.') ? catfile($url, "index.$ext")
                                 : catfile($destdir, $url, "index.$ext");

    # Write the index file:
    write_page($file, $data, $body, '../') or return 0;

    # Report success:
    print "Created $file\n" if $verbose > 1;
  }

  # Return success:
  return 1;
}

# Copy the stylesheet:
sub copy_stylesheet {
  # Prepare the file names:
  my $style = $conf->{blog}->{style} || 'default.css';
  my $from  = catfile($blogdir, '.blaze', 'style', $style);
  my $to    = ($destdir eq '.') ? $style : catfile($destdir, $style);

  # Copy the file:
  copy($from, $to) or return 0;

  # Report success:
  print "Created $to\n" if $verbose > 1;

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
  'with-index'    => sub { $with_index = 1 },
  'no-index|i'    => sub { $with_index = 0 },
  'with-posts'    => sub { $with_posts = 1 },
  'no-posts|p'    => sub { $with_posts = 0 },
  'with-pages'    => sub { $with_pages = 1 },
  'no-pages|P'    => sub { $with_pages = 0 },
  'with-tags'     => sub { $with_tags  = 1 },
  'no-tags|t'     => sub { $with_tags  = 0 },
  'with-rss'      => sub { $with_rss   = 1 },
  'no-rss|r'      => sub { $with_rss   = 0 },
  'with-css'      => sub { $with_css   = 1 },
  'no-css|c'      => sub { $with_css   = 0 },
  'full-paths|F'  => sub { $full_paths = 1 },
  'no-full-paths' => sub { $full_paths = 0 },
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

# Read the configuration file:
my $temp = catfile($blogdir, '.blaze', 'config');
$conf    = read_ini($temp)
           or print STDERR "Unable to read configuration.\n";

# Read the language file:
$temp    = catfile($blogdir, '.blaze', 'lang',
                   ($conf->{blog}->{lang} || 'en_GB'));
$locale  = read_ini($temp)
           or print STDERR "Unable to read language file `$temp'.", 13;

# Collect the necessary metadata:
my $data = collect_metadata();

# Generate RSS feed:
generate_rss($data)
  or exit_with_error("An error has occured while creating RSS feed.", 1)
  if $with_rss;

# Copy the stylesheet:
copy_stylesheet()
  or exit_with_error("Unable to copy the stylesheet.", 13)
  if $with_css;

# Generate index page:
generate_index($data)
  or exit_with_error("An error has occured while creating index page.", 1)
  if $with_index;

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

# Report success:
print "Done.\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-make - generate static content from the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-make> [B<-pqrtFPV>] [B<-b> I<directory>] [B<-d> I<directory>]

B<blaze-make> B<-h> | B<-v>

=head1 DESCRIPTION

B<blaze-make> reads the BlazeBlogger repository and generates a complete
directory tree of static pages, optionally including all blog posts, single
pages, browsable yearly and monthly archives, tags and even a RSS feed.
This way, you can benefit from most of the features other CMS usually have,
but without any additional hosting requirements.

=head1 OPTIONS

=over

=item B<-b>, B<--blogdir> I<directory>

Specify the I<directory> where the BlazeBlogger repository is placed. The
default option is the current working directory.

=item B<-d>, B<--destdir> I<directory>

Specify the I<directory> where the generated static content is to be
placed. The default option is the current working directory.

=item B<-c>, B<--no-css>

Disable creation of stylesheet.

=item B<-i>, B<--no-index>

Disable creation of index page. This is especially useful for websites with
pages only.

=item B<-p>, B<--no-posts>

Disable creation of posts as well as any related pages, i.e. tags and RSS
feed. This is especially useful for websites with pages only.

=item B<-P>, B<--no-pages>

Disable creation of pages.

=item B<-t>, B<--no-tags>

Disable support for tags.

=item B<-r>, B<--no-rss>

Disable creation of RSS feed.

=item B<-F>, B<--full-paths>

Enable full paths creation, i.e. always include page names in generated
links.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages including the list of created files.

=item B<-h>, B<--help>

Display usage information and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 FILES

=over

=item I<.blaze/config>

BlazeBlogger configuration file.

=item I<.blaze/theme/>

BlazeBlogger themes directory.

=item I<.blaze/style/>

BlazeBlogger stylesheets directory.

=item I<.blaze/lang/>

BlazeBlogger language files directory.

=back

=head1 SEE ALSO

B<blazetheme>(7), B<blazestyle>(7), B<blaze-config>(1), B<perl>(1).

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

Copyright (C) 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
