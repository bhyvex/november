#!perl6
use v6;
use Impatience;

class CGI {
    has %.param is rw;
    has %.cookie is rw;

    # RAKUDO: BUILD method not supported
    method init() {
        my %params = parse_params( %*ENV<QUERY_STRING> );

        # It's prudent to handle CONTENT_LENGTH too, but right now that's not
        # a priority. It would make our tests scripts more complicated, with
        # little gains. It would look like this:
        # if %*ENV<REQUEST_METHOD> eq 'POST' && %*ENV{CONTENT_LENGTH} > 0 {
        if %*ENV<REQUEST_METHOD> eq 'POST' {
            # Maybe check content_length here and only take that many bytes?
            my $input = $*IN.slurp();
            my %post_params = parse_params( $input );
            for %post_params.kv -> $k, $v {
                add_param( %params, $k, $v);
            }
        }
        $.param = %params;

        my %cookie = parse_params(%*ENV<HTTP_COOKIE>);
        $.cookie = %cookie;
    }

    # For debugging
    method save_params() {
        my $debug = open('/tmp/debug.out', :w);
        for $.param.kv -> $k, $v {
            $debug.say("$k => $v");
        }
        $debug.close;
    }

    method send_response($contents, %opts?) {
        # The header
        print "Content-Type: text/html\r\n";
        if %opts && %opts<cookie> {
            print 'Set-Cookie: ' ~ %opts<cookie> ~ "; path=/;\r\n";
        }
        print "\r\n";
        print $contents;
    }

    sub parse_params($string is rw) {
        my @param_values = split('&' , $string);
        my %param_temp;
        for @param_values -> $param_value {
            my @kvs = split('=', $param_value);
            # TODO: Is the case of 'page=' handled correctly?
            add_param( %param_temp, @kvs[0], unescape(@kvs[1]) );
        }
        return %param_temp;
    }

    sub unescape($string is rw) {
        # RAKUDO: :g plz
        while $string ~~ /\+/ {
            $string = $string.subst('+', ' ');
        }
        # RAKUDO: This could also be rewritten as a single .subst :g call.
        while ( $string ~~ /\%(..)/ ) {
            my $match = $0;
            my $character = chr(:16($match));
            # RAKUDO: DOTTY
            $string = $string.subst('%' ~ $match, $character);
        }
        return $string;
    }

    sub add_param ( Hash %params is rw, Str $key, $value ) {
        # RAKUDO: Hash.:exists not implemented yet
        # TODO: Make code work properly with an existing but undefined $key
        # if %params.:exists{$key} {
        if %params{$key} ~~ Str | Int {
            %params{$key} = [ %params{$key}, $value ];
        } 
        elsif %params{$key} ~~ Array {
            %params{$key}.push( $value );
        } 
        else {
            %params{$key} = $value;
        }
    }
}

