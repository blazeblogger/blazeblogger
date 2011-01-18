#!/usr/bin/env perl

# blaze-make - generates a blog from the BlazeBlogger repository
# Copyright (C) 2009-2010 Jaromir Hradilek

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
use File::Compare;
use File::Copy;
use File::Path;
use File::Spec::Functions;
use Getopt::Long;
use Time::Local 'timelocal_nocheck';

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '1.1.2';                    # Script version.

# General script settings:
our $blogdir     = '.';                             # Repository location.
our $destdir     = '.';                             # HTML pages location.
our $verbose     = 1;                               # Verbosity level.
our $with_index  = 1;                               # Generate index page?
our $with_posts  = 1;                               # Generate posts?
our $with_pages  = 1;                               # Generate pages?
our $with_tags   = 1;                               # Generate tags?
our $with_rss    = 1;                               # Generate RSS feed?
our $with_css    = 1;                               # Generate stylesheet?
our $full_paths  = 0;                               # Generate full paths?

# Global variables:
our $conf        = {};                              # Configuration.
our $locale      = {};                              # Localization.
our $cache_theme = '';                              # Cached template.

# Set up the __WARN__ signal handler:
$SIG{__WARN__}  = sub {
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
Usage: $NAME [-cpqrIFPTV] [-b DIRECTORY] [-d DIRECTORY]
       $NAME -h|-v

  -b, --blogdir DIRECTORY     specify a directory in which the BlazeBlogger
                              repository is placed
  -d, --destdir DIRECTORY     specify a directory in which the generated
                              blog is to be placed
  -c, --no-css                disable creating a style sheet
  -I, --no-index              disable creating the index page
  -p, --no-posts              disable creating blog posts
  -P, --no-pages              disable creating pages
  -T, --no-tags               disable creating tags
  -r, --no-rss                disable creating the RSS feed
  -F, --full-paths            enable including page names in generated
                              links
  -q, --quiet                 do not display unnecessary messages
  -V, --verbose               display all messages, including a list of
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

  # Display the version:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2009-2010 Jaromir Hradilek
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

# Translate a date to a string in the RFC 822 form:
sub rfc_822_date {
  my @date = localtime(shift);

  # Prepare aliases:
  my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
  my @days   = qw( Sun Mon Tue Wed Thu Fri Sat );

  # Return the result:
  return sprintf("%s, %02d %s %d %02d:%02d:%02d GMT", $days[$date[6]],
                 $date[3], $months[$date[4]], 1900 + $date[5],
                 $date[2], $date[1], $date[0]);
}

# Append proper index file name to the end of the link if requested:
sub fix_link {
  my $link = shift || '';

  # Check whether the full path is enabled:
  if ($full_paths) {
    # Append the slash if missing:
    $link .= '/' if ($link && $link !~ /\/$/);

    # Append the index file name:
    $link .= 'index.' . ($conf->{core}->{extension} || 'html');
  }
  else {
    # Make sure the link is not empty:
    $link = '.' unless $link;
  }

  # Return the correct link:
  return $link;
}

# Strip all HTML elements:
sub strip_html {
  my $string = shift || return '';

  # Substitute common HTML entities:
  $string =~ s/&[mn]dash;/--/ig;
  $string =~ s/&[lrb]dquo;/"/ig;
  $string =~ s/&[lr]squo;/'/ig;
  $string =~ s/&hellip;/.../ig;
  $string =~ s/&nbsp;/ /ig;

  # Strip HTML elements and other forbidded characters:
  $string =~ s/(<[^>]*>|&[^;]*;|<|>|&)//g;

  # Strip superfluous whitespaces:
  $string =~ s/\s{2,}/ /g;

  # Return the result:
  return $string;
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

# Read the content of the localization file:
sub read_lang {
  my $name = shift || 'en_US';

  # Prepare the file name:
  my $file = catfile($blogdir, '.blaze', 'lang', $name);

  # Parse the file:
  if (my $lang = read_ini($file)) {
    # Return the result:
    return $lang;
  }
  else {
    # Report failure:
    display_warning("Unable to read the localization file.");

    # Return an empty language settings:
    return {};
  }
}

# Make proper URL from a string, stripping all forbidden characters:
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

# Compose a blog post or a page record:
sub make_record {
  my $type = shift || die 'Missing argument';
  my $id   = shift || die 'Missing argument';
  my ($title, $author, $date, $tags, $url) = @_;

  # Check whether the title is specified:
  if ($title) {
    # Strip trailing spaces:
    $title =~ s/\s+$//;
  }
  else {
    # Assign the default value:
    $title = 'Untitled';

    # Display the appropriate warning:
    display_warning("Missing title in the $type with ID $id. " .
                    "Using `$title' instead.");
  }

  # Check whether the author is specified:
  unless ($author) {
    # Assign the default value:
    $author = $conf->{user}->{name} || 'admin';

    # Report the missing author:
    display_warning("Missing author in the $type with ID $id. " .
                    "Using `$author' instead.");
  }

  # Check whether the date is specified:
  if ($date) {
    # Check whether the format is valid:
    unless ($date =~ /\d{4}-[01]\d-[0-3]\d/) {
      # Use current date instead:
      $date = date_to_string(time);

      # Report the invalid date:
      display_warning("Invalid date in the $type with ID $id. " .
                      "Using `$date' instead.");
    }
  }
  else {
    # Use current date instead:
    $date = date_to_string(time);

    # Report the missing date:
    display_warning("Missing date in the $type with ID $id. " .
                    "Using `$date' instead.");
  }

  # Check whether the tags are specified:
  if ($tags) {
    # Make all tags lower case:
    $tags = lc($tags);

    # Strip superfluous spaces:
    $tags =~ s/\s{2,}/ /g;
    $tags =~ s/\s+$//;

    # Strip trailing commas:
    $tags =~ s/^,+|,+$//g;

    # Remove duplicates:
    my %temp = map { $_, 1 } split(/,+\s*/, $tags);
    $tags = join(', ', sort(keys(%temp)));
  }
  else {
    # Assign the default value:
    $tags = '';
  }

  # Check whether the URL is specified:
  if ($url) {
    # Check whether it contains forbidded characters:
    if ($url =~ /[^\w\-]/) {
      # Strip forbidden characters:
      $url = make_url($url);

      # Report the invalid URL:
      display_warning("Invalid URL in the $type with ID $id. " .
                      ($url ? "Stripping to `$url'."
                            : "Deriving from the title."));
    }
  }

  # Unless already created, derive the URL from the blog post or page
  # title:
  unless ($url) {
    # Derive the URL from the blog post or page title:
    $url = make_url(lc($title));
  }

  # Finalize the URL:
  if ($url) {
    # Prepend the ID to the blog post URL:
    $url = "$id-$url" if $type eq 'post';
  }
  else {
    # Base the URL on the ID:
    $url = ($type eq 'post') ? $id : "page$id";

    # Report missing URL:
    display_warning("Empty URL in the $type with ID $id. " .
                    "Using `$url' instead.");
  }

  # Return the composed record:
  return {
    'id'     => $id,
    'title'  => $title,
    'author' => $author,
    'date'   => $date,
    'tags'   => $tags,
    'url'    => $url,
  };
}

# Return a list of blog post or page header records:
sub collect_headers {
  my $type    = shift || 'post';

  # Initialize required variables:
  my @records = ();

  # Prepare the file name:
  my $head    = catdir($blogdir, '.blaze', "${type}s", 'head');

  # Open the directory:
  opendir(HEAD, $head) or return @records;

  # Process each file:
  while (my $id = readdir(HEAD)) {
    # Skip both . and ..:
    next if $id =~ /^\.\.?$/;

    # Parse header data:
    my $data   = read_ini(catfile($head, $id)) or next;
    my $date   = $data->{header}->{date};
    my $tags   = $data->{header}->{tags};
    my $author = $data->{header}->{author};
    my $url    = $data->{header}->{url};
    my $title  = $data->{header}->{title};

    # Create the record:
    my $record = make_record($type, $id, $title, $author, $date,
                             $tags, $url);

    # Add the record to the beginning of the list:
    push(@records, $record);
  }

  # Close the directory:
  closedir(HEAD);

  # Return the result:
  if ($type eq 'post') {
    return sort {
      sprintf("%s:%08d", $b->{date}, $b->{id}) cmp
      sprintf("%s:%08d", $a->{date}, $a->{id})
    } @records;
  }
  else {
    return sort {
      sprintf("%s:%08d", $a->{date}, $a->{id}) cmp
      sprintf("%s:%08d", $b->{date}, $b->{id})
    } @records;
  }
}

# Collect metadata:
sub collect_metadata {
  # Initialize required variables:
  my $post_links  = {};
  my $page_links  = {};
  my $month_links = {};
  my $tag_links   = {};

  # Prepare the list of month names:
  my @month_name  = qw( january february march april may june july
                        august september october november december );

  # Collect the page headers:
  my @pages  = collect_headers('page');

  # Collect the blog post headers:
  my @posts  = collect_headers('post');

  # Process each blog post header:
  foreach my $record (@posts) {
    # Decompose the record:
    my ($year, $month) = split(/-/, $record->{date});
    my @tags           = split(/,\s*/, $record->{tags});
    my $temp           = $month_name[int($month) - 1];
    my $name           = ($locale->{lang}->{$temp} || "\u$temp") ." $year";
    my $url            = $record->{url};
    my $id             = $record->{id};

    # Set up the blog post URL:
    $post_links->{$id}->{url} = "$year/$month/$url";

    # Check whether the month is already present:
    if ($month_links->{$name}) {
      # Increase the counter:
      $month_links->{$name}->{count}++;
    }
    else {
      # Set up the URL:
      $month_links->{$name}->{url}   = "$year/$month";

      # Set up the counter:
      $month_links->{$name}->{count} = 1;
    }

    # Process each tag separately:
    foreach my $tag (@tags) {
      # Check whether the tag is already present:
      if ($tag_links->{$tag}) {
        # Increase the counter:
        $tag_links->{$tag}->{count}++;
      }
      else {
        # Derive the URL from the tag name:
        my $tag_url = make_url($tag);

        # Make sure the URL string is not empty:
        unless ($tag_url) {
          # Use an MD5 checksum instead:
          $tag_url = Digest::MD5->new->add($tag)->hexdigest;

          # Report the missing URL:
          display_warning("Unable to derive the URL from tag `$tag'. " .
                          "Using `$tag_url' instead.");
        }

        # Set up the URL:
        $tag_links->{$tag}->{url}   = $tag_url;

        # Set up the counter:
        $tag_links->{$tag}->{count} = 1;
      }
    }
  }

  # Process each page header:
  foreach my $record (@pages) {
    # Set up the page URL:
    $page_links->{$record->{id}}->{url} = $record->{url};
  }

  # Return the result:
  return {
    'headers' => {
      'posts'   => \@posts,
      'pages'   => \@pages,
    },
    'links'   => {
      'posts'   => $post_links,
      'pages'   => $page_links,
      'months'  => $month_links,
      'tags'    => $tag_links,
    },
  };
}

# Return a list of tags:
sub list_of_tags {
  my $tags = shift || die 'Missing argument';

  # Check whether the tag creation is enabled:
  return '' unless $with_tags;

  # Check whether the list is not empty:
  if (my %tags = %$tags) {
    # Return the list of tags:
    return join("\n", map {
      "<li><a href=\"" . fix_link("%root%tags/$tags{$_}->{url}") .
      "\">$_ (" . $tags{$_}->{count} . ")</a></li>"
    } sort(keys(%tags)));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return a list of months:
sub list_of_months {
  my $months = shift || die 'Missing argument';
  my $year   = shift || '';

  # Check whether the post creation is enabled:
  return '' unless $with_posts;

  # Check whether the list is not empty:
  if (my %months = %$months) {
    # Return the list of months:
    return join("\n", sort { $b cmp $a } (map {
      "<li><a href=\"" . fix_link("%root%$months{$_}->{url}") .
      "\">$_ (" . $months{$_}->{count} . ")</a></li>"
    } grep(/$year$/, keys(%months))));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return a list of pages:
sub list_of_pages {
  my $pages = shift || die 'Missing argument';

  # Initialize required variables:
  my $list  = '';

  # Check whether the page creation is enabled:
  return '' unless $with_pages;

  # Process each page separately:
  foreach my $record (@$pages) {
    # Decompose the record:
    my $title = $record->{title};
    my $url   = $record->{url};

    # Add the page link to the list:
    $list .= "<li><a href=\"".fix_link("%root%$url")."\">$title</a></li>\n";
  }

  # Strip trailing line break:
  chomp($list);

  # Return the list of pages:
  return $list;
}

# Return a list of blog posts:
sub list_of_posts {
  my $posts = shift || die 'Missing argument';
  my $max   = shift || 5;

  # Initialize required variables:
  my $list  = '';

  # Check whether the blog post creation is enabled:
  return '' unless $with_posts;

  # Initialize the counter:
  my $count = 0;

  # Process each post separately:
  foreach my $record (@$posts) {
    # Stop when the post count reaches the limit:
    last if $count == $max;

    # Decompose the record:
    my $id    = $record->{id};
    my $url   = $record->{url};
    my $title = $record->{title};
    my ($year, $month) = split(/-/, $record->{date});

    # Add the post link to the list:
    $list .= "<li><a href=\"" . fix_link("%root%$year/$month/$url") .
             "\">$title</a></li>\n";

    # Increase the counter:
    $count++;
  }

  # Strip trailing line break:
  chomp($list);

  # Return the list of blog posts:
  return $list;
}

# Return the blog post or page body or synopsis:
sub read_entry {
  my $id      = shift || die 'Missing argument';
  my $type    = shift || 'post';
  my $link    = shift || '';
  my $excerpt = shift || 0;

  # Prepare the file name:
  my $file    = catfile($blogdir, '.blaze', "${type}s", 'body', $id);

  # Initialize required variables:
  my $result  = '';

  # Open the file for reading:
  open (FILE, $file) or return '';

  # Read the content of the file:
  while (my $line = <FILE>) {
    # When the synopsis is requested, look for a break mark:
    if ($excerpt && $line =~ /<!--\s*break\s*-->/i) {
      # Check whether the link is provided:
      if ($link) {
        # Read required data from the localization file:
        my $more = $locale->{lang}->{more} || 'Read more &raquo;';

        # Add the `Read more' link to the end of the synopsis:
        $result .= "<p><a href=\"$link\" class=\"more\">$more</a></p>\n";
      }

      # Stop the parsing here:
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

# Return a formatted blog post or page heading:
sub format_heading {
  my $title = shift || die 'Missing argument';
  my $link  = shift || '';

  # Return the result:
  return $link ? "<h2 class=\"post\"><a href=\"$link\">$title</a></h2>\n"
               : "<h2 class=\"post\">$title</h2>\n";
}

# Return formatted blog post or page information:
sub format_information {
  my $record = shift || die 'Missing argument';
  my $tags   = shift || die 'Missing argument';
  my $type   = shift || 'top';

  # Initialize required variables:
  my $class  = ($type eq 'top') ? 'information' : 'post-footer';
  my ($date, $author, $taglist) = ('', '', '');

  # Read required data from the configuration:
  my $author_location = $conf->{post}->{author} || 'top';
  my $date_location   = $conf->{post}->{date}   || 'top';
  my $tags_location   = $conf->{post}->{tags}   || 'top';

  # Read required data from the localization file:
  my $posted_on = $locale->{lang}->{postedon}   || '';
  my $posted_by = $locale->{lang}->{postedby}   || 'by';
  my $tagged_as = $locale->{lang}->{taggedas}   || 'tagged as';

  # Check whether the date of publishing is to be included:
  if ($date_location eq $type) {
    # Format the date of publishing:
    $date   = "$posted_on <span class=\"date\">$record->{date}</span>";
  }

  # Check whether the author is to be included:
  if ($author_location eq $type) {
    # Format the author:
    $author = "$posted_by <span class=\"author\">$record->{author}</span>";

    # Prepend a space if the date of publishing is included:
    $author = " $author" if $date;
  }

  # Check whether the tags are to be included (and if there are any):
  if ($tags_location eq $type && $with_tags && $record->{tags}) {
    # Convert tags to proper links:
    $taglist = join(', ', map {
      "<a href=\"". fix_link("%root%tags/$tags->{$_}->{url}") ."\">$_</a>"
      } split(/,\s*/, $record->{tags}));

    # Format the tags:
    $taglist = "$tagged_as <span class=\"tags\">$taglist</span>";

    # Prepend a comma if the date of publishing or the author are included:
    $taglist = ", $taglist" if $date || $author;
  }

  # Check if there is anything to return:
  if ($date || $author || $taglist) {
    # Return the result:
    return "<div class=\"$class\">\n  \u$date$author$taglist\n</div>\n";
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return a formatted blog post or page entry:
sub format_entry {
  my $data    = shift || die 'Missing argument';
  my $record  = shift || die 'Missing argument';
  my $type    = shift || 'post';
  my $excerpt = shift || 0;

  # Initialize required variables:
  my $tags    = $data->{links}->{tags};
  my $title   = $record->{title};
  my $id      = $record->{id};
  my ($link, $information, $post_footer) = ('', '', '');

  # If the synopsis is requested, prepare the entry link:
  if ($excerpt) {
    # Check whether the entry is a blog post, or a page:
    if ($type eq 'post') {
      # Decompose the record:
      my ($year, $month) = split(/-/, $record->{date});

      # Compose the link:
      $link = fix_link("%root%$year/$month/$record->{url}")
    }
    else {
      # Compose the link:
      $link = fix_link("%root%$record->{url}");
    }
  }

  # Prepare the blog post or page heading, and the body or the synopsis:
  my $heading = format_heading($title, $link);
  my $body    = read_entry($id, $type, $link, $excerpt);

  # For blog posts, prepare its additional information:
  if ($type eq 'post') {
    $information = format_information($record, $tags, 'top');
    $post_footer = format_information($record, $tags, 'bottom');
  }

  # Return the result:
  return "\n$heading$information$body$post_footer";
}

# Return a formatted section title:
sub format_section {
  my $title = shift || die 'Missing argument';

  # Return the result:
  return "<div class=\"section\">$title</div>\n";
}

# Return a formatted navigation links:
sub format_navigation {
  my $type  = shift || die 'Missing argument';
  my $index = shift || '';

  # Read required data from the configuration:
  my $ext   = $conf->{core}->{extension} || 'html';

  # Read required data from the localization:
  my $prev_string = $locale->{lang}->{previous} || '&laquo; Previous';
  my $next_string = $locale->{lang}->{next}     || 'Next &raquo;';

  # Prepare the label:
  my $label = ($type eq 'previous') ? $prev_string : $next_string;

  # Return the result:
  return "<div class=\"$type\"><a href=\"index$index.$ext\">$label</a>" .
         "</div>\n";
}

# Prepare a template:
sub format_template {
  my $data          = shift || die 'Missing argument';
  my $theme_file    = shift || $conf->{blog}->{theme} || 'default.html';
  my $style_file    = shift || $conf->{blog}->{style} || 'default.css';

  # Restore the template from the cache if available:
  return $cache_theme if $cache_theme;

  # Read required data from the documentation:
  my $conf_doctype  = $conf->{core}->{doctype}  || 'html';
  my $conf_encoding = $conf->{core}->{encoding} || 'UTF-8';
  my $conf_title    = $conf->{blog}->{title}    || 'My Blog';
  my $conf_subtitle = $conf->{blog}->{subtitle} || 'yet another blog';
  my $conf_name     = $conf->{user}->{name}     || 'admin';
  my $conf_email    = $conf->{user}->{email}    || 'admin@localhost';
  my $conf_nickname = $conf->{user}->{nickname} || $conf_name;

  # Prepare a list of blog posts, pages, tags, and months:
  my $list_pages    = list_of_pages($data->{headers}->{pages});
  my $list_posts    = list_of_posts($data->{headers}->{posts});
  my $list_months   = list_of_months($data->{links}->{months});
  my $list_tags     = list_of_tags($data->{links}->{tags});

  # Determine the current year:
  my $current_year  = substr(date_to_string(time), 0, 4);

  # Prepare the META tags:
  my $meta_content_type = '<meta http-equiv="Content-Type" content="' .
                          'txt/html; charset=' . $conf_encoding . '">';
  my $meta_generator    = '<meta name="Generator" content="BlazeBlogger ' .
                          VERSION . '">';
  my $meta_date         = '<meta name="Date" content="'. localtime() .'">';

  # Prepare the LINK tags:
  my $link_stylesheet   = '<link rel="stylesheet" href="%root%' .
                          $style_file . '" type="text/css">';
  my $link_feed         = '<link rel="alternate" href="%root%index.rss" ' .
                          'title="RSS Feed" type="application/rss+xml">';

  # Prepare the document header and footer:
  my $document_start;
  my $document_end      = '</html>';

  # Decide which document type to use:
  if ($conf_doctype ne 'xhtml') {
    # Fix the document header:
    $document_start = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
                      "http://www.w3.org/TR/html4/strict.dtd">
<html>';
  }
  else {
    # Fix the document header:
    $document_start = '<?xml version="1.0" encoding="$conf_encoding"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
                      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">';

    # Fix the tags:
    $meta_content_type =~ s/>$/ \/>/;
    $meta_generator    =~ s/>$/ \/>/;
    $meta_date         =~ s/>$/ \/>/;
    $meta_description  =~ s/>$/ \/>/;
    $meta_keywords     =~ s/>$/ \/>/;
    $link_stylesheet   =~ s/>$/ \/>/;
    $link_feed         =~ s/>$/ \/>/;
  }

  # Open the theme file for reading:
  open(THEME, catfile($blogdir, '.blaze', 'theme', $theme_file))
    or return 0;

  # Read the theme file:
  my $template = do { local $/; <THEME> };

  # Close the theme file:
  close(THEME);

  # Substitute the header placeholders:
  $template =~ s/<!--\s*start-document\s*-->/$document_start/ig;
  $template =~ s/<!--\s*end-document\s*-->/$document_end/ig;
  $template =~ s/<!--\s*content-type\s*-->/$meta_content_type/ig;
  $template =~ s/<!--\s*generator\s*-->/$meta_generator/ig;
  $template =~ s/<!--\s*date\s*-->/$meta_date/ig;
  $template =~ s/<!--\s*stylesheet\s*-->/$link_stylesheet/ig;
  $template =~ s/<!--\s*feed\s*-->/$link_feed/ig if $with_rss;
  $template =~ s/<!--\s*rss\s*-->/$link_feed/ig if $with_rss; # Deprecated.

  # Substitute the list placeholders:
  $template =~ s/<!--\s*pages\s*-->/$list_pages/ig;
  $template =~ s/<!--\s*posts\s*-->/$list_posts/ig;
  $template =~ s/<!--\s*archive\s*-->/$list_months/ig;
  $template =~ s/<!--\s*tags\s*-->/$list_tags/ig;

  # Substitute body placeholders:
  $template =~ s/<!--\s*title\s*-->/$conf_title/ig;
  $template =~ s/<!--\s*subtitle\s*-->/$conf_subtitle/ig;
  $template =~ s/<!--\s*name\s*-->/$conf_name/ig;
  $template =~ s/<!--\s*nickname\s*-->/$conf_nickname/ig;
  $template =~ s/<!--\s*e-mail\s*-->/$conf_email/ig;
  $template =~ s/<!--\s*year\s*-->/$current_year/ig;

  # Store the template to the cache:
  $cache_theme = $template;

  # Return the result:
  return $template;
}

# Write a single page:
sub write_page {
  my $data    = shift || die 'Missing argument';
  my $target  = shift || '';
  my $root    = shift || '';
  my $content = shift || '';
  my $heading = shift || $conf->{blog}->{title} || 'My Blog';
  my $index   = shift || '';

  # Initialize required variables:
  my $home    = fix_link($root);
  my $temp    = $root || '#';

  # Read required data from the configuration:
  my $ext     = $conf->{core}->{extension}    || 'html';

  # Load the template:
  my $template = format_template($data);

  # Substitute the page title:
  $template    =~ s/<!--\s*page-title\s*-->/$heading/ig;

  # Add the page content:
  $template    =~ s/<!--\s*content\s*-->/$content/ig;

  # Substitute the root directory:
  $template    =~ s/%root%/$root/ig;

  # Substitute the home page:
  $template    =~ s/%home%/$home/ig;

  # Substitute the `blog post / page / tag with the selected ID'
  # placeholder:
  while ($template =~ /%(post|page|tag)\[([^\]]+)\]%/i) {
    # Decompose the placeholder:
    my $type = $1;
    my $id   = lc($2);

    # Check whether the selected blog post / page / tag exists:
    if (defined $data->{links}->{"${type}s"}->{$id}) {
      # Get the blog post / page / tag link:
      my $link = $data->{links}->{"${type}s"}->{$id}->{url};

      # Compose the URL:
      $link    = ($type ne 'tag')
               ? fix_link("$root$link")
               : fix_link("${root}tags/$link");

      # Substitute the placeholder:
      $template =~ s/%$type\[$id\]%/$link/ig;
    }
    else {
      # Report the invalid reference:
      display_warning("Invalid reference to $type with ID $id.");

      # Disable the placeholder:
      $template =~ s/%$type\[$id\]%/#/ig;
    }
  }

  # Check whether to create a directory tree:
  if ($target) {
    # Create the target directory tree:
    eval { mkpath($target, 0) };

    # Make sure the directory creation was successful:
    exit_with_error("Creating `$target': $@", 13) if $@;
  }

  # Prepare the file name:
  my $file = $target
           ? catfile($target, "index$index.$ext")
           : "index$index.$ext";

  # Open the file for writing:
  open(FILE, ">$file") or return 0;

  # Write the line to the file:
  print FILE $template;

  # Close the file:
  close(FILE);

  # Report success:
  print "Created $file\n" if $verbose > 1;

  # Return success:
  return 1;
}

# Copy the style sheet:
sub copy_stylesheet {
  # Prepare file names:
  my $style = $conf->{blog}->{style} || 'default.css';
  my $from  = catfile($blogdir, '.blaze', 'style', $style);
  my $to    = ($destdir eq '.') ? $style : catfile($destdir, $style);

  # Check whether the existing style sheet differs:
  if (compare($from,$to)) {
    # Copy the file:
    copy($from, $to) or return 0;

    # Report success:
    print "Created $to\n" if $verbose > 1;
  }

  # Return success:
  return 1;
}

# Generate the RSS feed:
sub generate_rss {
  my $data          = shift || die 'Missing argument';

  # Read required data from the configuration:
  my $core_encoding  = $conf->{core}->{encoding}  || 'UTF-8';
  my $blog_title     = $conf->{blog}->{title}     || 'My Blog';
  my $blog_subtitle  = $conf->{blog}->{subtitle}  || 'yet another blog';
  my $feed_fullposts = $conf->{feed}->{fullposts} || 'false';
  my $feed_posts     = $conf->{feed}->{posts}     || 10;
  my $feed_baseurl   = $conf->{feed}->{baseurl};

  # Handle a deprecated setting; for the backward compatibility reasons
  # only, and to be removed in the near future:
  if ((defined $conf->{blog}->{url}) && (not $feed_baseurl)) {
    # Use the value from the deprecated option:
    $feed_baseurl = $conf->{blog}->{url};

    # Display the warning:
    display_warning("Option blog.url is deprecated. Use feed.baseurl " .
                    "instead.");
  }

  # Check whether the base URL is specified:
  unless ($feed_baseurl) {
    # Display the warning:
    display_warning("Missing feed.baseurl option. " .
                    "Skipping the RSS feed creation.");

    # Disable the RSS:
    $with_rss = 0;

    # Return success:
    return 1;
  }

  # Make sure the blog post number is a valid integer:
  unless ($feed_posts =~ /^\d+$/) {
    # Use default value:
    $feed_posts = 10;

    # Display a warning:
    display_warning("Invalid feed.posts option. Using the default value.");
  }

  # Set up the blog post item type:
  my $excerpt = ($feed_fullposts =~ /^(true|auto)\s*$/i) ? 0 : 1;

  # Initialize necessary variables:
  my $count      = 0;

  # Strip HTML elements:
  $blog_title    = strip_html($blog_title);
  $blog_subtitle = strip_html($blog_subtitle);

  # Strip trailing forward slash from the base URL:
  $feed_baseurl  =~ s/\/+$//;

  # Prepare the RSS feed file name:
  my $file = ($destdir eq '.') ? 'index.rss'
                               : catfile($destdir, 'index.rss');

  # Open the file for writing:
  open(RSS, ">$file") or return 0;

  # Write the RSS header:
  print RSS "<?xml version=\"1.0\" encoding=\"$core_encoding\"?>\n" .
            "<rss version=\"2.0\">\n<channel>\n" .
            "  <title>$blog_title</title>\n" .
            "  <link>$feed_baseurl/</link>\n" .
            "  <description>$blog_subtitle</description>\n" .
            "  <generator>BlazeBlogger " . VERSION . "</generator>\n";

  # Process the requested number of posts:
  foreach my $record (@{$data->{headers}->{posts}}) {
    # Stop when the post count reaches the limit:
    last if $count == $feed_posts;

    # Decompose the record:
    my $url        = $record->{url};
    my ($year, $month, $day) = split(/-/, $record->{date});

    # Get the RFC 822 date-time string:
    my $time       = timelocal_nocheck(1, 0, 0, $day, ($month - 1), $year);
    my $date_time  = rfc_822_date($time);

    # Prepare the blog post title:
    my $post_title = strip_html($record->{title});

    # Open the blog post item:
    print RSS "  <item>\n    <title>$post_title</title>\n  " .
              "  <link>$feed_baseurl/$year/$month/$url/</link>\n  " .
              "  <guid>$feed_baseurl/$year/$month/$url/</guid>\n  " .
              "  <pubDate>$date_time</pubDate>\n  ";

    # Read the blog post body:
    my $post_desc = read_entry($record->{id}, 'post', '', $excerpt);

    # Substitute the root directory placeholder:
    $post_desc =~ s/%root%/$feed_baseurl\//ig;

    # Substitute the home page placeholder:
    $post_desc =~ s/%home%/$feed_baseurl\//ig;

    # Add the blog post body:
    print RSS "  <description><![CDATA[$post_desc    ]]></description>\n";

    # Close the blog post item:
    print RSS "  </item>\n";

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

# Generate the index page:
sub generate_index {
  my $data       = shift || die 'Missing argument';

  # Initialize required variables:
  my $body       = '';                              # List of posts.
  my $count      = 0;                               # Post counter.
  my $page       = 0;                               # Page counter.

  # Read required data from the configuration:
  my $blog_posts = $conf->{blog}->{posts}     || 10;
  my $blog_title = $conf->{blog}->{title}     || 'My Blog';

  # Prepare the target directory name:
  my $target     = ($destdir eq '.') ? '' : $destdir;

  # Make sure the posts number is a valid integer:
  unless ($blog_posts =~ /^\d+$/) {
    # Use the default value:
    $blog_posts = 10;

    # Display a warning:
    display_warning("Invalid blog.posts option. Using the default value.");
  }

  # Check whether the blog posts are enabled:
  if ($with_posts) {
    # Process the requested number of blog posts:
    foreach my $record (@{$data->{headers}->{posts}}) {
      # Check whether the number of listed blog posts reached the limit:
      if ($count == $blog_posts) {
        # Prepare information for the page navigation:
        my $index = $page     || '';
        my $next  = $page - 1 || '';
        my $prev  = $page + 1;

        # Add the navigation:
        $body .= format_navigation('previous', $prev);
        $body .= format_navigation('next', $next) if $page;

        # Write the index page:
        write_page($data, $target, '', $body, $blog_title, $index)
          or return 0;

        # Clear the page body:
        $body  = '';

        # Reset the blog post counter:
        $count = 0;

        # Increase the page counter:
        $page++;
      }

      # Add the blog post synopsis to the page body:
      $body .= format_entry($data, $record, 'post', 1);

      # Increase the number of listed blog posts:
      $count++;
    }

    # Check whether there are unwritten data:
    if ($body) {
      # Prepare information for the page navigation:
      my $index = $page     || '';
      my $next  = $page - 1 || '';

      # Add navigation:
      $body .= format_navigation('next', $next) if $page;

      # Write the index page:
      write_page($data, $target, '', $body, $blog_title, $index)
        or return 0;
    }
  }
  else {
    # Write an empty index page:
    write_page($data, $target, '', $body, $blog_title) or return 0;
  }

  # Return success:
  return 1;
}

# Generate the blog posts:
sub generate_posts {
  my $data         = shift || die 'Missing argument';

  # Read required data from the configuration:
  my $blog_posts   = $conf->{blog}->{posts}      || 10;

  # Read required data from the localization:
  my $title_string = $locale->{lang}->{archive}  || 'Archive for';

  # Prepare the list of month names:
  my @names        = qw( january february march april may june july
                         august september october november december );

  # Initialize post related variables:
  my $post_body    = '';                            # Blog post content.

  # Inicialize yearly archive-related variables:
  my $year_body    = '';                            # List of months.
  my $year_curr    = '';                            # Current year.
  my $year_last    = '';                            # Last processed year.

  # Initialize monthly archive-related variables:
  my $month_body   = '';                            # List of posts.
  my $month_curr   = '';                            # Current month.
  my $month_last   = '';                            # Last processed month.
  my $month_count  = 0;                             # Post counter.
  my $month_page   = 0;                             # Page counter.

  # Declare other necessary variables:
  my ($year, $month, $target);

  # Make sure the blog post number is a valid integer:
  unless ($blog_posts =~ /^\d+$/) {
    # Use the default value:
    $blog_posts = 10;

    # Display a warning:
    display_warning("Invalid blog.posts option. Using the default value.");
  }

  # Process each record:
  foreach my $record (@{$data->{headers}->{posts}}) {
    # Decompose the record:
    ($year, $month) = split(/-/, $record->{date});

    # Prepare the blog post body:
    $post_body = format_entry($data, $record, 'post', 0);

    # Prepare the target directory name:
    $target    = ($destdir eq '.')
               ? catdir($year, $month, $record->{url})
               : catdir($destdir, $year, $month, $record->{url});

    # Write the blog post:
    write_page($data, $target, '../../../', $post_body, $record->{title})
      or return 0;

    # Set the year:
    $year_curr = $year;

    # Check whether the year has changed:
    if ($year_last ne $year_curr) {
      # Prepare the section title:
      my $title   = "$title_string $year";

      # Add the yearly archive section title:
      $year_body  = format_section($title);

      # Add the yearly archive list of months:
      $year_body .= "<ul>\n" . list_of_months($data->{links}->{months},
                                              $year) . "\n</ul>";

      # Prepare the yearly archive target directory name:
      $target = ($destdir eq '.') ? $year : catdir($destdir, $year);

      # Write the yearly archive index page:
      write_page($data, $target, '../', $year_body, $title) or return 0;

      # Change the previous year to the currently processed one:
      $year_last = $year_curr;
    }

    # If this is the first loop, fake the previous month as the current:
    $month_last = "$year/$month" unless $month_last;

    # Set the month:
    $month_curr = "$year/$month";

    # Check whether the month has changed, or whether the  number of listed
    # posts has reached the limit:
    if (($month_last ne $month_curr) || ($month_count == $blog_posts)) {
      # Prepare information for the page navigation:
      my $index = $month_page     || '';
      my $next  = $month_page - 1 || '';
      my $prev  = $month_page + 1;

      # Get information about the last processed month:
      ($year, $month) = split(/\//, $month_last);

      # Prepare the section tile:
      my $temp  = $names[int($month) - 1];
      my $name  = ($locale->{lang}->{$temp} || $temp) . " $year";
      my $title = "$title_string $name";

      # Add the section title:
      $month_body  = format_section($title) . $month_body;

      # Add the navigation:
      $month_body .= format_navigation('previous', $prev)
                     if $month_curr eq $month_last;
      $month_body .= format_navigation('next', $next)
                     if $month_page;

      # Prepare the monthly archive target directory name:
      $target = ($destdir eq '.')
              ? catdir($year, $month)
              : catdir($destdir, $year, $month);

      # Write the monthly archive index page:
      write_page($data, $target, '../../', $month_body, $title, $index)
        or return 0;

      # Check whether the month has changed:
      if ($month_curr ne $month_last) {
        # Reset the page counter:
        $month_page = 0;
      }
      else {
        # Increase the page counter:
        $month_page++;
      }

      # Change the previous month to the currently processed one:
      $month_last = $month_curr;

      # Clear the monthly archive body:
      $month_body = '';

      # Reset the blog post counter:
      $month_count = 0;
    }

    # Add the blog post synopsis:
    $month_body .= format_entry($data, $record, 'post', 1);

    # Increase the number of listed blog posts:
    $month_count++;
  }

  # Check whether there are any unwritten data:
  if ($month_body) {
    # Prepare information for the page navigation:
    my $index = $month_page     || '';
    my $next  = $month_page - 1 || '';

    # Get information about the last processed month:
    ($year, $month) = split(/\//, $month_curr);

    # Get information for the title:
    my $temp  = $names[int($month) - 1];
    my $name  = ($locale->{lang}->{$temp} || $temp) . " $year";
    my $title = "$title_string $name";

    # Add the section title:
    $month_body  = format_section($title) . $month_body;

    # Add the navigation:
    $month_body .= format_navigation('next', $next) if $month_page;

    # Prepare the monthly archive target directory name:
    $target = ($destdir eq '.')
            ? catdir($year, $month)
            : catdir($destdir, $year, $month);

    # Write the monthly archive index page:
    write_page($data, $target, '../../', $month_body, $title, $index)
      or return 0;
  }

  # Return success:
  return 1;
}

# Generate the tags:
sub generate_tags {
  my $data         = shift || die 'Missing argument';

  # Read required data from the configuration:
  my $blog_posts   = $conf->{blog}->{posts}      || 10;

  # Read required data from the localization:
  my $title_string = $locale->{lang}->{tags}     || 'Posts tagged as';
  my $tags_string  = $locale->{lang}->{taglist}  || 'List of tags';

  # Make sure the blog post number is a valid integer:
  unless ($blog_posts =~ /^\d+$/) {
    # Use the default value:
    $blog_posts = 10;

    # Display a warning:
    display_warning("Invalid blog.posts option. Using the default value.");
  }

  # Process each tag separately:
  foreach my $tag (keys %{$data->{links}->{tags}}) {
    # Initialize tag related variables:
    my $tag_body  = '';                             # List of posts.
    my $tag_count = 0;                              # Post counter.
    my $tag_page  = 0;                              # Page counter.

    # Declare other necessary variables:
    my $target;

    # Process each record:
    foreach my $record (@{$data->{headers}->{posts}}) {
      # Check whether the blog post contains the current tag:
      next unless $record->{tags} =~ /(^|,\s*)$tag(,\s*|$)/;

      # Check whether the number of listed blog posts reached the limit:
      if ($tag_count == $blog_posts) {
        # Prepare information for the page navigation:
        my $index = $tag_page     || '';
        my $next  = $tag_page - 1 || '';
        my $prev  = $tag_page + 1;

        # Prepare the section title:
        my $title = "$title_string $tag";

        # Add the section title:
        $tag_body  = format_section($title) . $tag_body;

        # Add the navigation:
        $tag_body .= format_navigation('previous', $prev);
        $tag_body .= format_navigation('next', $next) if $tag_page;

        # Prepare the tag target directory name:
        $target = ($destdir eq '.')
                ? catdir('tags', $data->{links}->{tags}->{$tag}->{url})
                : catdir($destdir, 'tags',
                         $data->{links}->{tags}->{$tag}->{url});

        # Write the tag index page:
        write_page($data, $target, '../../', $tag_body, $title, $index)
          or return 0;

        # Clear the tag body:
        $tag_body  = '';

        # Reset the blog post counter:
        $tag_count = 0;

        # Increase the page counter:
        $tag_page++;
      }

      # Add the blog post synopsis:
      $tag_body .= format_entry($data, $record, 'post', 1);

      # Increase the number of listed blog posts:
      $tag_count++;
    }

    # Check whether there are unwritten data:
    if ($tag_body) {
      # Prepare information for the page navigation:
      my $index = $tag_page     || '';
      my $next  = $tag_page - 1 || '';

      # Prepare the section title:
      my $title = "$title_string $tag";

      # Add the section title:
      $tag_body  = format_section($title) . $tag_body;

      # Add the navigation:
      $tag_body .= format_navigation('next', $next) if $tag_page;

      # Prepare the tag target directory name:
      $target = ($destdir eq '.')
              ? catdir('tags', $data->{links}->{tags}->{$tag}->{url})
              : catdir($destdir, 'tags',
                       $data->{links}->{tags}->{$tag}->{url});

      # Write the tag index page:
      write_page($data, $target, '../../', $tag_body, $title, $index)
        or return 0;
    }
  }

  # Create the tag list, if any:
  if (%{$data->{links}->{tags}}) {
    # Add the tag list section title:
    my $taglist_body = format_section($tags_string);

    # Add the tag list:
    $taglist_body   .= "<ul>\n".list_of_tags($data->{links}->{tags},'../').
                       "\n</ul>";

    # Prepare the tag list target directory name:
    my $target = ($destdir eq '.') ? 'tags' : catdir($destdir, 'tags');

    # Write the tag list index page:
    write_page($data, $target, '../', $taglist_body, $tags_string)
      or return 0;
  }

  # Return success:
  return 1;
}

# Generate the pages:
sub generate_pages {
  my $data = shift || die 'Missing argument';

  # Process each record:
  foreach my $record (@{$data->{headers}->{pages}}) {
    # Prepare the page body:
    my $body   = format_entry($data, $record, 'page', 0);

    # Prepare the target directory name:
    my $target = ($destdir eq '.')
               ? catdir($record->{url})
               : catdir($destdir, $record->{url});

    # Write the page:
    write_page($data, $target, '../', $body, $record->{title}) or return 0;
  }

  # Return success:
  return 1;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Process command line options:
GetOptions(
  'help|h'        => sub { display_help();    exit 0; },
  'version|v'     => sub { display_version(); exit 0; },
  'quiet|q'       => sub { $verbose    = 0;     },
  'verbose|V'     => sub { $verbose    = 2;     },
  'blogdir|b=s'   => sub { $blogdir    = $_[1]; },
  'destdir|d=s'   => sub { $destdir    = $_[1]; },
  'with-index'    => sub { $with_index = 1 },
  'no-index|I'    => sub { $with_index = 0 },
  'with-posts'    => sub { $with_posts = 1 },
  'no-posts|p'    => sub { $with_posts = 0 },
  'with-pages'    => sub { $with_pages = 1 },
  'no-pages|P'    => sub { $with_pages = 0 },
  'with-tags'     => sub { $with_tags  = 1 },
  'no-tags|T'     => sub { $with_tags  = 0 },
  'with-rss'      => sub { $with_rss   = 1 },
  'no-rss|r'      => sub { $with_rss   = 0 },
  'with-css'      => sub { $with_css   = 1 },
  'no-css|c'      => sub { $with_css   = 0 },
  'full-paths|F'  => sub { $full_paths = 1 },
  'no-full-paths' => sub { $full_paths = 0 },
);

# Check superfluous options:
exit_with_error("Invalid option `$ARGV[0]'.", 22) if (scalar(@ARGV) != 0);

# Check whether the repository is present, no matter how naive this method
# actually is:
exit_with_error("Not a BlazeBlogger repository! Try `blaze-init' first.",1)
  unless (-d catdir($blogdir, '.blaze'));

# Make sure there is something to do at all:
unless ($with_posts || $with_pages) {
  # Report success:
  print "Nothing to do.\n" if $verbose;

  # Return success:
  exit 0;
}

# When the blog post creation is disabled, disable the RSS feed and the tag
# creation as well:
unless ($with_posts) {
  $with_tags = 0;
  $with_rss  = 0;
}

# Read the configuration file:
$conf    = read_conf();

# Read the localization file:
$locale  = read_lang($conf->{blog}->{lang});

# Collect the metadata:
my $data = collect_metadata();

# Copy the style sheet:
copy_stylesheet()
  or exit_with_error("An error has occurred while creating the stylesheet.")
  if $with_css;

# Generate RSS feed:
generate_rss($data)
  or exit_with_error("An error has occurred while creating the RSS feed.")
  if $with_rss;

# Generate index page:
generate_index($data)
  or exit_with_error("An error has occurred while creating the index page.")
  if $with_index;

# Generate posts:
generate_posts($data)
  or exit_with_error("An error has occurred while creating the blog posts.")
  if $with_posts;

# Generate tags:
generate_tags($data)
  or exit_with_error("An error has occurred while creating the tags.")
  if $with_tags;

# Generate pages:
generate_pages($data)
  or exit_with_error("An error has occurred while creating the pages.")
  if $with_pages;

# Report success:
print "Done.\n" if $verbose;

# Return success:
exit 0;

__END__

=head1 NAME

blaze-make - generates a blog from the BlazeBlogger repository

=head1 SYNOPSIS

B<blaze-make> [B<-cpqrIFPTV>] [B<-b> I<directory>] [B<-d> I<directory>]

B<blaze-make> B<-h>|B<-v>

=head1 DESCRIPTION

B<blaze-make> reads the BlazeBlogger repository, and generates a complete
directory tree of static pages, including blog posts, single pages, monthly
and yearly archives, tags, and even an RSS feed.

=head1 OPTIONS

=over

=item B<-b> I<directory>, B<--blogdir> I<directory>

Allows you to specify a I<directory> in which the BlazeBlogger repository
is placed. The default option is a current working directory.

=item B<-d> I<directory>, B<--destdir> I<directory>

Allows you to specify a I<directory> in which the generated blog is to be
placed. The default option is a current working directory.

=item B<-c>, B<--no-css>

Disables creating a style sheet.

=item B<-I>, B<--no-index>

Disables creating the index page.

=item B<-p>, B<--no-posts>

Disables creating blog posts.

=item B<-P>, B<--no-pages>

Disables creating pages.

=item B<-T>, B<--no-tags>

Disables creating tags.

=item B<-r>, B<--no-rss>

Disables creating the RSS feed.

=item B<-F>, B<--full-paths>

Enables including page names in generated links.

=item B<-q>, B<--quiet>

Disables displaying of unnecessary messages.

=item B<-V>, B<--verbose>

Enables displaying of all messages, including a list of created files.

=item B<-h>, B<--help>

Displays usage information and exits.

=item B<-v>, B<--version>

Displays version information and exits.

=back

=head1 FILES

=over

=item I<.blaze/theme/>

A directory containing blog themes.

=item I<.blaze/style/>

A directory containing style sheets.

=item B<.blaze/lang/>

A directory containing language files.

=back

=head1 EXAMPLE USAGE

Generate a blog in a current working directory:

  ~]$ blaze-make
  Done.

Generate a blog in the C<~/public_html/> directory:

  ~]$ blaze-make -d ~/public_html
  Done.

Generate a blog with full paths enabled:

  ~]$ blaze-make -F
  Done.

=head1 SEE ALSO

B<blaze-init>(1), B<blaze-config>(1), B<blaze-add>(1)

=head1 BUGS

To report a bug or to send a patch, please, add a new issue to the bug
tracker at <http://code.google.com/p/blazeblogger/issues/>, or visit the
discussion group at <http://groups.google.com/group/blazeblogger/>.

=head1 COPYRIGHT

Copyright (C) 2009-2010 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
