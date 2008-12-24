use v6;

use Config;

class Tags {
    my $.page_tags_path      = Config.server_root ~ 'data/page_tags/';
    my $.tags_count_path     = Config.server_root ~ 'data/tags_count';
    my $.tags_index_path     = Config.server_root ~ 'data/tags_index';

    method update_tags ($_: Str $page, Str $new_tags) {
        my $old_tags = .read_page_tags($page).chomp;
        return 1 if $new_tags eq $old_tags;

        my @old_tags = .tags_parse: $old_tags;
        my @new_tags = .tags_parse: $new_tags;

        my @to_add    = @new_tags.grep: { $_ eq none(@old_tags) };
        my @to_remove = @old_tags.grep: { $_ eq none(@new_tags) };

        .remove_tags($page, @to_remove);
        .add_tags($page, @to_add);
        .write_page_tags($page, $new_tags);
    }

    method add_tags (Str $page, Array @tags) {

        my $count = self.read_tags_count;

        for @tags -> $t {
            # RAKUDO: Increment not implemented in class 'Undef'
            if $count{$t} {
                $count{$t}++;
            } 
            else {
                $count{$t} = 1;
            }
        }

        self.write_tags_count($count);

        my $index = self.read_tags_index;

        for @tags -> $t {
            unless $index{$t} {
                $index{$t} = [];
            }
            unless any($index{$t}.values) eq $page {
                $index{$t}.push($page);
                $index{$t} = grep { $_ ne '' }, $index{$t}.values;
            }
        }

        self.write_tags_index($index);
    }

    method remove_tags(Str $page, Array @tags) {
        
        my $count = self.read_tags_count;

        for @tags -> $t {
            if $count{$t} && $count{$t} > 0 {
                $count{$t}--;
            } 
            
            if $count{$t} == 0 {
                # RAKUDO: :delete on Hash not implemented yet
                # $count{$t} :delete;
                $count.delete($t); 
            }
        }

        self.write_tags_count($count);

        my $index = self.read_tags_index;

        for @tags -> $t {
            # RAKUDO: @ not implemented yet
            #if $index{$t} && any(@ $index{$t}) eq $page {
            if $index{$t} && any($index{$t}.values) eq $page {
                    $index{$t} = grep { $_ ne $page }, $index{$t}.values;
            }
        }
        self.write_tags_index($index);
    }

    method read_page_tags(Str $page) {
        my $file = $.page_tags_path ~ $page;
        return '' unless $file ~~ :e;
        return slurp($file);
    }

    method write_page_tags (Str $page, Str $tags) {
        my $file = $.page_tags_path ~ $page;
        my $fh = open( $file, :w );
        $fh.say($tags);
        $fh.close;
    }
   
    method read_tags_count {
        my $file = $.tags_count_path;
        return {} unless $file ~~ :e;
        # RAKUDO: can return array here [perl #61642]
        return hash eval slurp $file;
    }

    method write_tags_count (Hash $counts) {
        my $file = $.tags_count_path;
        my $fh = open( $file, :w );
        $fh.say( $counts.perl );
        $fh.close;
    }

    method read_tags_index {  
        my $file = $.tags_index_path;
        return {} unless $file ~~ :e;

        # RAKUDO: can return array here [perl #61642]
        return hash eval slurp $file;
    }

    method write_tags_index (Hash $index) {
        my $file = $.tags_index_path;
        my $fh = open( $file, :w );
        $fh.say( $index.perl );
        $fh.close;
    }

    method tags_parse (Str $tags) {
        return () if $tags ~~ m/^ \s* $/;
        my @tags = $tags.lc.split(/ \s* ( ',' | \n | '.' ) \s* /);
        grep { $_ ne "" }, @tags.uniq;
    }

    method norm_counts (@tags?) {
        my %counts = self.read_tags_count;

        my $min = 0;
        my $max = 0;
        if ?%counts.keys {
            $min = +(%counts.values).min;
            $max = +(%counts.values).max;
        }

        my $norm_counts = {};
        # RAKUDO: stringify Array here
        #for @tags || $counts.keys {

        for @tags || %counts.keys {
            $norm_counts{$_} = self.norm( +%counts{$_}, $min, $max ); 
        }
        return $norm_counts;
    }

    method norm ($count, $min, $max) {
        my $step = ($count - $min) / (($max - $min) || 1);
        return ceiling( ( log($step + 1 ) * 10 ) / log 2 ); 
    }
    
    method page_tags (Str $page) {
        # that`s ugly, we must use template instead, 
        # when new-html-template give us ability to 
        # know last element in the list 
        my @page_tags = self.tags_parse( self.read_page_tags: $page ); 

        my $tags_str;
        if @page_tags {
            @page_tags = @page_tags.map: { tag_html($_) };
            $tags_str = @page_tags.join(', ');
        }
        return $tags_str;
    }

    method cloud_tags {
        my $norm_counts = self.norm_counts; 
        my $tags_str;

        if $norm_counts {
            $tags_str ~= tag_html($_, $norm_counts) ~ ' ' for $norm_counts.keys;
        }

        return $tags_str;
    }

    # that`s ugly, we must use template instead, 
    # when new-html-template give us include 
    sub tag_html ($tag, $norm_counts?) {
        my $html =  '<a';
        $html ~= ' class="t' ~ $norm_counts{$tag} ~ '"' if $norm_counts;
        $html ~= ' href="' ~ Config.web_root ~ '/all?tag=' ~ $tag ~ '">' ~
	    $tag ~ '</a>';
    }
}

# vim:ft=perl6
