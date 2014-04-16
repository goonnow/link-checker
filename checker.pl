use URI;
use Web::Scraper;
use AnyEvent::HTTP;
use HTTP::Tiny;
use Timer::Simple ();
use Data::Dump qw(dump);

my $t = Timer::Simple->new();
$t->start();

my $url =  $ARGV[0] || "http://www.startsiden.no/";
my $links = scraper {
    process "a", "links[]" => sub {
        my $elem = shift;

        my $href = $elem->attr('href');
        $href =~ s|^/|$url|g;
        return {
            title => $elem->attr('title'),
            alt => $elem->attr('alt'),
            id => $elem->attr('id'),
            class => $elem->attr('class'),
            href => $href,
        };
    };
};

my $res = $links->scrape( URI->new($url) );

my @links = remove_dup($res->{links});
my $total = scalar @links;
my $bad   = 0;

my $start_time = localtime;

print "There're $total links\n";

for my $l ( @links ) {
    my $response = HTTP::Tiny->new->get($l->{href});
    if( $response->{success} ) {
        print "GOOD\t $l->{href}\n"; 
    }else{
        $bad++;
        print "BAD\t$l\n";
        print "$response->{status} \t $response->{reason}\n";
        print dump $l
    }
}

$t->stop();

#print "=== Found $bad bad links from $total links in $url\n";
#printf "In total took : ", $t->hms;

sub remove_dup {
    my $links  = shift;
    my @new;

    foreach my $l ( @{$links} ) {
        my $found = 0;

        # Check dup loop
        foreach my $c ( @new ) {
            if( $l->{href} eq $c->{href} ){
                $found=1;
                last;
            }
        }

        if( !$found ) {
            push( @new, $l );
        }
    }
    return @new;
}
