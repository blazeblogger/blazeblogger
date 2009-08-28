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
use File::Path;
use File::Spec::Functions;
use Digest::MD5;
use Getopt::Long;
use Time::Local 'timelocal_nocheck';

# General script information:
use constant NAME    => basename($0, '.pl');        # Script name.
use constant VERSION => '0.9.1';                    # Script version.

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
our $conf       = {};                               # Configuration.
our $locale     = {};                               # Localization.
our $cache      = {};                               # Cache.

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
Usage: $NAME [-cpqrtIFPV] [-b directory] [-d directory]
       $NAME -h | -v

  -b, --blogdir directory     specify the directory where the BlazeBlogger
                              repository is placed
  -d, --destdir directory     specify the directory where the generated
                              static content is to be placed
  -c, --no-css                disable stylesheet creation
  -I, --no-index              disable index page creation
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

# Append proper index file name to the end of the link if requested:
sub fix_link {
  my $link = shift || '';

  # Check whether the full path is enabled:
  if ($full_paths) {
    # Append slash if missing:
    $link .= '/' if ($link && $link !~ /\/$/);

    # Append index file name:
    $link .= 'index.' . ($conf->{core}->{extension} || 'html');
  }

  # Return the correct link:
  return $link;
}

# Strip HTML elements:
sub strip_html {
  my $string = shift || return '';

  # Substitute most common HTML entities:
  $string =~ s/&[mn]dash;/--/ig;
  $string =~ s/&[lrb]dquo;/"/ig;
  $string =~ s/&[lr]squo;/'/ig;
  $string =~ s/&hellip;/.../ig;
  $string =~ s/&nbsp;/ /ig;

  # Strip other HTML elements and forbidded characters:
  $string =~ s/(<[^>]*>|&[^;]*;|<|>|&)//g;

  # Strip superfluous whitespace characters:
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

# Read the language file:
sub read_lang {
  my $name = shift || 'en_GB';

  # Prepare the file name:
  my $file = catfile($blogdir, '.blaze', 'lang', $name);

  # Parse the file:
  if (my $lang = read_ini($file)) {
    # Return the result:
    return $lang;
  }
  else {
    # Report failure:
    display_warning("Unable to read selected language file.");

    # Return empty language settings:
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

# Compose a post/page record:
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

    # Report missing author:
    display_warning("Missing author in the $type with ID $id. " .
                    "Using `$author' instead.");
  }

  # Check whether the date is specified:
  if ($date) {
    # Check whether the format is valid:
    unless ($date =~ /\d{4}-[01]\d-[0-3]\d/) {
      # Use current date instead:
      $date = date_to_string(time);

      # Report invalid date:
      display_warning("Invalid date in the $type with ID $id. " .
                      "Using `$date' instead.");
    }
  }
  else {
    # Use current date instead:
    $date = date_to_string(time);

    # Report missing date:
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

      # Report invalid URL:
      display_warning("Invalid URL in the $type with ID $id. " .
                      ($url ? "Stripping to `$url'."
                            : "Deriving from title."));
    }
  }

  # Unless already created, derive URL from the post/page title:
  unless ($url) {
    # Derive URL from the post/page title:
    $url = make_url(lc($title));
  }

  # Finalise the URL:
  if ($url) {
    # Prepend ID to the post URL:
    $url = "$id-$url" if $type eq 'post';
  }
  else {
    # Base URL on ID:
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

# Return the list of posts/pages header records:
sub collect_headers {
  my $type    = shift || 'post';

  # Initialize required variables:
  my @records = ();

  # Prepare the file name:
  my $head    = catdir($blogdir, '.blaze', "${type}s", 'head');

  # Open the headers directory:
  opendir(HEAD, $head) or return @records;

  # Process each file:
  while (my $id = readdir(HEAD)) {
    # Skip both . and ..:
    next if $id =~ /^\.\.?$/;

    # Parse the header data:
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
    return sort {"$b->{date}:$b->{id}" cmp "$a->{date}:$a->{id}"} @records;
  }
  else {
    return sort {"$a->{date}:$a->{id}" cmp "$b->{date}:$b->{id}"} @records;
  }
}

# Collect the necessary metadata:
sub collect_metadata {
  # Initialize required variables:
  my $post_links  = {};
  my $page_links  = {};
  my $month_links = {};
  my $tag_links   = {};

  # Prepare the list of month names:
  my @month_name  = qw( january february march april may june july
                        august september october november december );

  # Collect the pages headers:
  my @pages  = collect_headers('page');

  # Collect the posts headers:
  my @posts  = collect_headers('post');

  # Process each post header:
  foreach my $record (@posts) {
    # Decompose the record:
    my ($year, $month) = split(/-/, $record->{date});
    my @tags           = split(/,\s*/, $record->{tags});
    my $temp           = $month_name[int($month) - 1];
    my $name           = ($locale->{lang}->{$temp} || "\u$temp") ." $year";
    my $url            = $record->{url};
    my $id             = $record->{id};

    # Set up the post URL:
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
        # Derive URL from tag name:
        my $tag_url = make_url($tag);

        # Make sure the URL is not empty:
        unless ($tag_url) {
          # Use MD5 checksum instead:
          $tag_url = Digest::MD5->new->add($tag)->hexdigest;

          # Report missing URL:
          display_warning("Unable to derive URL from tag `$tag'. " .
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

# Return the list of tags:
sub list_of_tags {
  my $tags = shift || die 'Missing argument';
  my $root = shift || '';

  # Check whether the tags generation is eneabled:
  return '' unless $with_tags;

  # Check whether the list is not empty:
  if (my %tags = %$tags) {
    # Return the list of tags:
    return join("\n", map {
      "<li><a href=\"" . fix_link("${root}tags/" . $tags{$_}->{url}) .
      "\">$_ (" . $tags{$_}->{count} . ")</a></li>"
    } sort(keys(%tags)));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return the list of months:
sub list_of_months {
  my $months = shift || die 'Missing argument';
  my $root   = shift || '';
  my $year   = shift || '';

  # Check whether the posts generation is enabled:
  return '' unless $with_posts;

  # Check whether the list is not empty:
  if (my %months = %$months) {
    # Return the list of months:
    return join("\n", sort { $b cmp $a } (map {
      "<li><a href=\"" . fix_link($root . $months{$_}->{url}) .
      "\">$_ (" . $months{$_}->{count} . ")</a></li>"
    } grep(/$year$/, keys(%months))));
  }
  else {
    # Return an empty string:
    return '';
  }
}

# Return the list of pages:
sub list_of_pages {
  my $pages = shift || die 'Missing argument';
  my $root  = shift || '';

  # Initialize required variables:
  my $list  = '';

  # Check whether the pages generation is enabled:
  return '' unless $with_pages;

  # Process each page separately:
  foreach my $record (@$pages) {
    # Decompose the record:
    my $title = $record->{title};
    my $url   = $record->{url};

    # Add the page link to the list:
    $list .= "<li><a href=\"".fix_link("$root$url")."\">$title</a></li>\n";
  }

  # Strip trailing line break:
  chomp($list);

  # Return the list of pages:
  return $list;
}

# Return the list of posts:
sub list_of_posts {
  my $posts = shift || die 'Missing argument';
  my $root  = shift || '';
  my $max   = shift || 5;

  # Initialize required variables:
  my $list  = '';

  # Check whether the posts generation is enabled:
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
    $list .= "<li><a href=\"" . fix_link("$root$year/$month/$url") .
             "\">$title</a></li>\n";

    # Increase the counter:
    $count++;
  }

  # Strip trailing line break:
  chomp($list);

  # Return the list of posts:
  return $list;
}

# Return post/page body or excerpt:
sub read_entry {
  my $id      = shift || die 'Missing argument';
  my $type    = shift || 'post';
  my $link    = shift || '';
  my $excerpt = shift || 0;

  # Prepare the file name:
  my $file    = catfile($blogdir, '.blaze', "${type}s", 'body', $id);

  # Initialize required variables:
  my $result  = '';

  # Open the post/page body file for reading:
  open (FILE, $file) or return '';

  # Read the content of the file:
  while (my $line = <FILE>) {
    # When excerpt is requested, look for a break mark:
    if ($excerpt && $line =~ /<!--\s*break\s*-->/i) {
      # Check whether the link is provided:
      if ($link) {
        # Read required data from the language file:
        my $more = $locale->{lang}->{more} || 'Read more &raquo;';

        # Add the `Read more' link to the end of the excerpt:
        $result .= "<p><a href=\"$link\" class=\"more\">$more</a></p>\n";
      }

      # Stop reading here:
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

# Return formatted post/page heading:
sub format_heading {
  my $title = shift || die 'Missing argument';
  my $link  = shift || '';

  # Return the result:
  return $link ? "<h2 class=\"post\"><a href=\"$link\">$title</a></h2>\n"
               : "<h2 class=\"post\">$title</h2>\n";
}

# Return formatted post/page information:
sub format_information {
  my $record = shift || die 'Missing argument';
  my $tags   = shift || die 'Missing argument';
  my $root   = shift || '';
  my $type   = shift || 'top';

  # Initialize required variables:
  my $class  = ($type eq 'top') ? 'information' : 'post-footer';
  my ($date, $author, $taglist) = ('', '', '');

  # Read required data from the configuration:
  my $author_location = $conf->{post}->{author} || 'top';
  my $date_location   = $conf->{post}->{date}   || 'top';
  my $tags_location   = $conf->{post}->{tags}   || 'top';

  # Read required data from the language file:
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

  # Check whether the tags are to be included (and there are any):
  if ($tags_location eq $type && $with_tags && $record->{tags}) {
    # Convert tags to proper links:
    $taglist = join(', ', map {
      "<a href=\"". fix_link("${root}tags/$tags->{$_}->{url}") ."\">$_</a>"
      } split(/,\s*/, $record->{tags}));

    # Format the tags:
    $taglist = "$tagged_as <span class=\"tags\">$taglist</span>";

    # Prepend a comma if the date of publishing or author are included:
    $taglist = ", $taglist" if $date || $author;
  }

  # Check whether there is anything to return:
  if ($date || $author || $taglist) {
    # Return the result:
    return "<div class=\"$class\">\n  \u$date$author$taglist\n</div>\n";
  }
  else {
    # Return empty string:
    return '';
  }
}

# Return formatted post/page entry:
sub format_entry {
  my $data    = shift || die 'Missing argument';
  my $record  = shift || die 'Missing argument';
  my $root    = shift || '';
  my $type    = shift || 'post';
  my $excerpt = shift || 0;

  # Initialize required variables:
  my $tags    = $data->{links}->{tags};
  my $title   = $record->{title};
  my $id      = $record->{id};
  my ($link, $information, $post_footer) = ('', '', '');

  # If the excerpt is requested, prepare the entry link:
  if ($excerpt) {
    # Check whether the entry is post or page:
    if ($type eq 'post') {
      # Decompose the record:
      my ($year, $month) = split(/-/, $record->{date});

      # Compose the link:
      $link = fix_link("$root$year/$month/$record->{url}")
    }
    else {
      # Compose the link:
      $link = fix_link("$root$record->{url}");
    }
  }

  # Prepare the post/page heading and body/excerpt:
  my $heading = format_heading($title, $link);
  my $body    = read_entry($id, $type, $link, $excerpt);

  # For posts, prepare its additional information:
  if ($type eq 'post') {
    $information = format_information($record, $tags, $root, 'top');
    $post_footer = format_information($record, $tags, $root, 'bottom');
  }

  # Return the result:
  return "\n$heading$information$body$post_footer";
}

# Return formatted section title:
sub format_section {
  my $title = shift || die 'Missing argument';

  # Return the result:
  return "<div class=\"section\">$title</div>\n";
}

# Return formatted navigation:
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
  my $ext     = $conf->{core}->{extension}      || 'html';

  # Check whether the template is not already cached:
  unless ($cache->{theme}->{$temp}) {
    # Read required data from the configuration:
    my $encoding = $conf->{core}->{encoding}  || 'UTF-8';
    my $name     = $conf->{user}->{name}      || 'admin';
    my $email    = $conf->{user}->{email}     || 'admin@localhost';
    my $style    = $conf->{blog}->{style}     || 'default.css';
    my $subtitle = $conf->{blog}->{subtitle}  || 'yet another blog';
    my $theme    = $conf->{blog}->{theme}     || 'default.html';
    my $title    = $conf->{blog}->{title}     || 'My Blog';

    # Prepare the posts, pages, tags and months lists:
    my $tags     = list_of_tags($data->{links}->{tags}, $root);
    my $archive  = list_of_months($data->{links}->{months}, $root);
    my $pages    = list_of_pages($data->{headers}->{pages}, $root);
    my $posts    = list_of_posts($data->{headers}->{posts}, $root);

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
    my $template = do { local $/; <THEME> };

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

    # Store the template to the cache:
    $cache->{theme}->{$temp} = $template;
  }

  # Load the template from the cache:
  my $template = $cache->{theme}->{$temp};

  # Substitute page title:
  $template   =~ s/<!--\s*page-title\s*-->/$heading/ig;

  # Add page content:
  $template   =~ s/<!--\s*content\s*-->/$content/ig;

  # Substitute the root directory placeholder:
  $template   =~ s/%root%/$root/ig;

  # Substitute the home page placeholder:
  $template   =~ s/%home%/$home/ig;

  # Substitute the `post/page with selected ID' placeholder:
  while ($template =~ /%(post|page)\[(\d+)\]%/i) {
    # Check whether the selected post/page exists:
    if (my $link = $data->{links}->{"$1s"}->{$2}->{url}) {
      # Compose the URL:
      $link = fix_link("$root$link");

      # Substitute the placeholder:
      $template =~ s/%$1\[$2\]%/$link/ig;
    }
    else {
      # Report invalid reference:
      display_warning("Invalid reference to $1 with ID $2.");

      # Disable the placeholder:
      $template =~ s/%$1\[$2\]%/#/ig;
    }
  }

  # Create the target directory tree:
  eval { mkpath($target, { verbose => 0 }) };

  # Make sure the directory creation was successful:
  exit_with_error("Creating `$target': $@", 13) if $@;

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

# Generate RSS feed:
sub generate_rss {
  my $data          = shift || die 'Missing argument';

  # Initialize required variables:
  my $max_posts     = 10;

  # Read required data from the configuration:
  my $blog_title    = $conf->{blog}->{title}     || 'My Blog';
  my $blog_subtitle = $conf->{blog}->{subtitle}  || 'yet another blog';
  my $base          = $conf->{blog}->{url};

  # Check whether the base URL is specified:
  unless ($base) {
    # Display the warning:
    display_warning("Missing blog.url option. " .
                    "Skipping the RSS feed creation.");

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

  # Strip trailing forward slash from the base URL:
  $base =~ s/\/+$//;

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
  foreach my $record (@{$data->{headers}->{posts}}) {
    # Stop when the post count reaches the limit:
    last if $count == $max_posts;

    # Decompose the record:
    my $url        = $record->{url};
    my ($year, $month, $day) = split(/-/, $record->{date});

    # Read the post excerpt:
    my $post_body  = read_entry($record->{id}, 'post', '', 1);

    # Strip HTML elements:
    my $post_title = strip_html($record->{title});
    my $post_desc  = substr(strip_html($post_body), 0, 500);

    # Get the RFC 822 date-time string:
    my $time       = timelocal_nocheck(1, 0, 0, $day, ($month - 1), $year);
    my $date_time  = rfc_822_date($time);

    # Add the post item:
    print RSS "  <item>\n    <title>$post_title</title>\n  " .
              "  <link>$base/$year/$month/$url/</link>\n  " .
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
  my $data       = shift || die 'Missing argument';

  # Initialize required variables:
  my $body       = '';
  my $count      = 0;

  # Read required data from the configuration:
  my $max_posts  = $conf->{blog}->{posts}     || 10;
  my $blog_title = $conf->{blog}->{title}     || 'My Blog';

  # Check whether the posts are enabled:
  if ($with_posts) {
    # Process the requested number of posts:
    foreach my $record (@{$data->{headers}->{posts}}) {
      # Stop when the post count reaches the limit:
      last if $count == $max_posts;

      # Add the post excerpt to the listing:
      $body .= format_entry($data, $record, '', 'post', 1);

      # Increase the number of listed items:
      $count++;
    }
  }

  # Prepare the target directory name:
  my $target = ($destdir eq '.') ? '' : $destdir;

  # Write the index file:
  write_page($data, $target, '', $body, $blog_title) or return 0;

  # Return success:
  return 1;
}

# Generate posts:
sub generate_posts {
  my $data         = shift || die 'Missing argument';

  # Read required data from the configuration:
  my $max_posts    = $conf->{blog}->{posts}      || 10;

  # Read required data from the localization:
  my $title_string = $locale->{lang}->{archive}  || 'Archive for';

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
  my ($year, $month, $target);

  # Process each record:
  foreach my $record (@{$data->{headers}->{posts}}) {
    # Decompose the record:
    ($year, $month) = split(/-/, $record->{date});

    # Prepare the post body:
    $post_body = format_entry($data, $record, '../../../', 'post', 0);

    # Prepare the target directory name:
    $target    = ($destdir eq '.')
               ? catdir($year, $month, $record->{url})
               : catdir($destdir, $year, $month, $record->{url});

    # Write the post:
    write_page($data, $target, '../../../', $post_body, $record->{title})
      or return 0;

    # Set the current year:
    $year_curr = $year;

    # Check whether the year has changed:
    if ($year_last ne $year_curr) {
      # Prepare the section title:
      my $title   = "$title_string $year";

      # Add this year's archive section title:
      $year_body  = format_section($title);

      # Add this year's archive list of months:
      $year_body .= "<ul>\n" . list_of_months($data->{links}->{months},
                                              '../', $year) . "\n</ul>";

      # Prepare this year's archive target directory name:
      $target = ($destdir eq '.') ? $year : catdir($destdir, $year);

      # Write this year's archive index page:
      write_page($data, $target, '../', $year_body, $title) or return 0;

      # Make the previous year the current one:
      $year_last = $year_curr;
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

      # Prepare the section tile:
      my $temp  = $names[int($month) - 1];
      my $name  = ($locale->{lang}->{$temp} || $temp) . " $year";
      my $title = "$title_string $name";

      # Add section title:
      $month_body  = format_section($title) . $month_body;

      # Add navigation:
      $month_body .= format_navigation('previous', $prev)
                     if $month_curr eq $month_last;
      $month_body .= format_navigation('next', $next)
                     if $month_page;

      # Prepare this month's archive target directory name:
      $target = ($destdir eq '.')
              ? catdir($year, $month)
              : catdir($destdir, $year, $month);

      # Write this month's archive index page:
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

      # Make the previous month the current one:
      $month_last = $month_curr;

      # Clear the monthly archive body:
      $month_body = '';

      # Reset the post counter:
      $month_count = 0;
    }

    # Add the post excerpt:
    $month_body .= format_entry($data, $record, '../../', 'post', 1);

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

    # Get information for the title:
    my $temp  = $names[int($month) - 1];
    my $name  = ($locale->{lang}->{$temp} || $temp) . " $year";
    my $title = "$title_string $name";

    # Add section title:
    $month_body  = format_section($title) . $month_body;

    # Add navigation:
    $month_body .= format_navigation('next', $next) if $month_page;

    # Prepare this month's archive target directory name:
    $target = ($destdir eq '.')
            ? catdir($year, $month)
            : catdir($destdir, $year, $month);

    # Write this month's archive index page:
    write_page($data, $target, '../../', $month_body, $title, $index)
      or return 0;
  }

  # Return success:
  return 1;
}

# Generate tags:
sub generate_tags {
  my $data         = shift || die 'Missing argument';

  # Read required data from the configuration:
  my $max_posts    = $conf->{blog}->{posts}      || 10;

  # Read required data from the localization:
  my $title_string = $locale->{lang}->{tags}     || 'Posts tagged as';
  my $tags_string  = $locale->{lang}->{taglist}  || 'List of tags';

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
      # Check whether the post contains the current tag:
      next unless $record->{tags} =~ /(^|,\s*)$tag(,\s*|$)/;

      # Check whether the number of listed posts reached the limit:
      if ($tag_count == $max_posts) {
        # Prepare information for the page navigation:
        my $index = $tag_page     || '';
        my $next  = $tag_page - 1 || '';
        my $prev  = $tag_page + 1;

        # Prepare the section title:
        my $title = "$title_string $tag";

        # Add section title:
        $tag_body  = format_section($title) . $tag_body;

        # Add navigation:
        $tag_body .= format_navigation('previous', $prev);
        $tag_body .= format_navigation('next', $next) if $tag_page;

        # Prepare this tag's target directory name:
        $target = ($destdir eq '.')
                ? catdir('tags', $data->{links}->{tags}->{$tag}->{url})
                : catdir($destdir, 'tags',
                         $data->{links}->{tags}->{$tag}->{url});

        # Write this tag's index page:
        write_page($data, $target, '../../', $tag_body, $title, $index)
          or return 0;

        # Clear the tag body:
        $tag_body  = '';

        # Reset the post counter:
        $tag_count = 0;

        # Increase the page counter:
        $tag_page++;
      }

      # Add the post excerpt:
      $tag_body .= format_entry($data, $record, '../../', 'post', 1);

      # Increase the number of listed posts:
      $tag_count++;
    }

    # Check whether there are unwritten data:
    if ($tag_body) {
      # Prepare information for the page navigation:
      my $index = $tag_page     || '';
      my $next  = $tag_page - 1 || '';

      # Prepare the section title:
      my $title = "$title_string $tag";

      # Add section title:
      $tag_body  = format_section($title) . $tag_body;

      # Add navigation:
      $tag_body .= format_navigation('next', $next) if $tag_page;

      # Prepare this tag's target directory name:
      $target = ($destdir eq '.')
              ? catdir('tags', $data->{links}->{tags}->{$tag}->{url})
              : catdir($destdir, 'tags',
                       $data->{links}->{tags}->{$tag}->{url});

      # Write this tag's index page:
      write_page($data, $target, '../../', $tag_body, $title, $index)
        or return 0;
    }
  }

  # Create the tag list if any:
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

# Generate pages:
sub generate_pages {
  my $data = shift || die 'Missing argument';

  # Process each record:
  foreach my $record (@{$data->{headers}->{pages}}) {
    # Prepare the page body:
    my $body   = format_entry($data, $record, '../', 'page', 0);

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
  'no-index|I'    => sub { $with_index = 0 },
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

# Check whether there is anything to do:
unless ($with_posts || $with_pages) {
  # Report success:
  print "Nothing to do.\n" if $verbose;

  # Return success:
  exit 0;
}

# When posts are disabled, disable RSS and tags as well:
unless ($with_posts) {
  $with_tags = 0;
  $with_rss  = 0;
}

# Read the configuration file:
$conf    = read_conf();

# Read the language file:
$locale  = read_lang($conf->{blog}->{lang});

# Collect the necessary metadata:
my $data = collect_metadata();

# Copy the stylesheet:
copy_stylesheet()
  or exit_with_error("An error has occurred while creating stylesheet.", 1)
  if $with_css;

# Generate RSS feed:
generate_rss($data)
  or exit_with_error("An error has occurred while creating RSS feed.", 1)
  if $with_rss;

# Generate index page:
generate_index($data)
  or exit_with_error("An error has occurred while creating index page.", 1)
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

B<blaze-make> [B<-cpqrtIFPV>] [B<-b> I<directory>] [B<-d> I<directory>]

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

=item B<-I>, B<--no-index>

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

B<blazetheme>(7), B<blaze-config>(1), B<perl>(1).

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
