# Copyright: SZABO Gergely <szg@subogero.com>, GNU LGPL v2.1
package WWW::U2B;
use strict;
use warnings;
use URI::Escape;

use Exporter 'import';
our @EXPORT_OK = qw(search extract_streams suffix uid);

sub search; sub extract_streams; sub suffix; sub uid;

# Query, URL-encoded
sub search {
    my $query = 'https://gdata.youtube.com/feeds/api/videos?q=';
    $query .= join '%20', @_;
    my $xml = `curl $query 2>/dev/null`;
    # Parse response XML
    my @hits;
    while ($xml =~ m|^.*?<entry>(.+?)</media:group>(.*)|s) {
        $xml = $2;
        my $vid = $1;
        next unless $vid =~ m|<link .+?href='([^']+?)&amp;|;
        my $url = $1;
        $vid =~ m|<media:title type='plain'>(.+?)</media:title>|;
        my $title = $1;
        $vid =~ m|<media:thumbnail url='([^']+?)' height='90'[^>]+?/>|;
        my $thumbnail = $1;
        push @hits, { thumbnail => $thumbnail, label => $title, name => $url };
    }
    return @hits;
}

# Extract stream URLs and metadata from a video HTML page:
# Look for quoted string after "url_encoded_fmt_stream_map":
# uri_unescape string
# Comma-split for list of stream data (comma inside quote does not split)
# Split each part by "\u0026" for url, itag, type, quality, fallback_host keys
# Return list of parts, each a hashref of url, itag, type, quality
sub extract_streams {
    unlink 'jar';
    my $html = `curl -c jar -L $_[0] 2>/dev/null`;
    return unless $html =~ /url_encoded_fmt_stream_map":"(.+?)"/;
    my $map = uri_unescape $1;
    my ($stream, @streams);
    while ($map) {
        $stream .= $1 if $map =~ s/^([^,"]+)//;
        $stream .= $1 if $map =~ s/^("[^"]+?")//;
        if ($map eq '' || $map =~ s/^,//) {
            push @streams, $stream;
            $stream = '';
        }
    }
    my @result;
    foreach my $str (@streams) {
        my %fields = map { split /=/, $_, 2 } split /\\u0026/, $str;
        $fields{extension} = suffix $fields{itag};
        push @result, \%fields;
    }
    return @result;
}

# Map itag format ids to file extensions
sub suffix {
    my $itag = shift;
    return $itag =~ /^(43|44|45|46)$/ ? 'webm'
         : $itag =~ /^(18|22|37|38)$/ ? 'mp4'
         : $itag =~ /^(13|17|36)$/    ? '3gp'
         :                              'flv';
}

sub uid {
    my $url = shift;
    my $uid = $url;
    die "$url: no valid video URL or ID" unless $uid =~ s/^(.+=)?(.{11})$/$2/;
    return $uid;
}

1;
