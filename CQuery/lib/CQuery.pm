package CQuery;
use v5.10;
use Dancer ':syntax';
use Dancer::Plugin::FlashMessage;
use Template::Stash;
use CWB::CQP::More;
use Data::Dumper;
use Try::Tiny;
use File::Spec;
use Lingua::NATools::PTD;
use File::Basename;
use XML::Simple;

use lib '/home/smash/playground/per-fide-code/CAdmin/lib'; # XXX
use CAdmin::Utils;

our $VERSION = '0.1';
our $SAMPLE_SIZE = 50;
our $PTD_DIR = File::Spec->catdir(File::Spec->rootdir() => 'home' => 'ptd');
our $RESOURCES = '/home/resources';

$Template::Stash::LIST_OPS->{exists} = sub {
    my ($list, $var) = @_;
    return (grep { $_ eq $var } @$list) ? 1 : 0;
};

sub mybase {
    my $base = request->base();
    $base .= "/" unless $base =~ m'/$';
    return $base;
};

hook before_template => sub {
    my $tokens = shift;
    my $path = request->base->path;
    $tokens->{uri_base} = $path eq '/' ? $path : $path.'/';
};

get '/ptd/:id/:dir/' => sub { redirect "/"; };

get '/ptd/:id/:l1/:l2/:word' => sub {
    my $id = params->{id};
    my $corpus = corpus_info($id);
    my ($l1,$l2) = (params->{l1}, params->{l2});
    my $word = lc(params->{word});

    my ($dir1, $dir2) = ('st', 'ts');
    my ($query1, $query2);
    unless ($l1 =~ /^pt$/i) {
        ($dir1, $dir2) = ('ts', 'st');
        ($l2, $l1) = ($l1, $l2);
        $query2 = $word;
    }
    else {
        $query1 = $word;
    }

    my $ptds   = corpus_ptds($id, $l1, $l2);
    my $mptds  = mega_ptd($l1, $l2);

    unless ($ptds) {
        flash error => 'The corpus you choose does not have PTDs available';
        return redirect mybase;
    }
    my ($mptd, $ptd, $occ, $message);

    $ptd = { dir1 => $dir1, dir2 => $dir2,
             cname => $corpus->{name}, l1 => $l1, l2 => $l2 };

    ($dir1 eq 'ts') and
       ($ptd->{l1}, $ptd->{l2}) = ($ptd->{l2},$ptd->{l1});
    

    my $sellang = sprintf("%s-%s", $l1, $l2);

    $mptd = {%$ptd};

    if ($occ = $ptds->{$dir1}->count($word)) {
        my $i = 0;
        $ptd->{word} = $word;
        $ptd->{count} = $occ;
        my %t = $ptds->{$dir1}->transHash($word);
        my $grad = gradient(0,100);
        for my $t (sort {$t{$b} <=> $t{$a}} keys %t) {
            my $entry = {
                         i => $i++,
                         count => $ptds->{$dir2}->count($t),
                         prob  => $t{$t} * 100,
                         color => $grad->($t{$t} * 100),
                         term  => $t,
                        };
            my $c = $entry->{count};
            my %t2 = $ptds->{$dir2}->transHash($t);
            for my $tt (sort {$t2{$b} <=> $t2{$a}} keys %t2) {
                $entry->{good} = 1 if $tt eq $word;
                push @{$entry->{translations}}, {
                                                 color => $grad->(100*$t2{$tt}),
                                                 prob  => 100*$t2{$tt},
                                                 term  => $tt,
                                                 count => $ptds->{$dir1}->count($tt)
                                                };
            }
            push @{$ptd->{entries}}, $entry;
        }
    } else {
        $message = "<h3>'$word' not found on corpus $id.</h3>";
        $ptd = undef;
    }

    if ($mptds and $occ = $mptds->{$dir1}->count($word)) {
        my $i = 0;
        $mptd->{word} = $word;
        $mptd->{count} = $occ;
        my %t = $mptds->{$dir1}->transHash($word);
        my $grad = gradient(0,100);
        for my $t (sort {$t{$b} <=> $t{$a}} keys %t) {
            my $entry = {
                         i => $i++,
                         count => $mptds->{$dir2}->count($t),
                         prob  => $t{$t} * 100,
                         color => $grad->($t{$t} * 100),
                         term  => $t,
                        };
            my $c = $entry->{count};
            my %t2 = $mptds->{$dir2}->transHash($t);
            for my $tt (sort {$t2{$b} <=> $t2{$a}} keys %t2) {
                $entry->{good} = 1 if $tt eq $word;
                push @{$entry->{translations}}, {
                                                 color => $grad->(100*$t2{$tt}),
                                                 prob  => 100*$t2{$tt},
                                                 term  => $tt,
                                                 count => $mptds->{$dir1}->count($tt)
                                                };
            }
            push @{$mptd->{entries}}, $entry;
        }
    } else { $mptd = undef; }

    template 'index' => {
                         'ptd'        => $ptd,
                         'mptd'       => $mptd,
                         'main'       => $message,
                         'sidebar'    => 3, 'ctype' => 'bilingual',
                         'selcorpora' => params->{id},
                         'lang1'      => $l1,
                         'lang2'      => $l2,
                         'langs'      => languages('bilingual'),
                         'corpora'    => corpora('bilingual' => $sellang),
                         'sellang'    => $sellang,
                         'query1_string' => $query1,
                         'query2_string' => $query2,
                         'options' => session 'options',
                        };

};

get '/meta/:id' => sub {
    my $id = params->{id};

    my $info = CAdmin::Utils::corpus_info($id);
    return redirect mybase unless $info;

    my $ctype = session 'search_ctype';
    my $lang = session 'search_lang';

    template 'index' => {
                         'info'    => $info,
                         'log'     => "Meta for $id",
                         'sidebar' => 3,
                         'ctype'   => $ctype,
                         'sellang' => $lang,
                         #($data->{target_id} ? ('lang1' => $data->{source_language},
                         #                       'lang2' => $data->{target_language}):()),
                         'langs'   => languages($ctype),
                         #'selcorpora' => params->{corpora},
                         'corpora' => corpora($ctype, $lang),
                         'options' => session 'options',
                        };
};

# XXX remover this route if possible
any ['post','get'] => qr'/search/bilingual/([A-Z]{2})-([A-Z]{2})' => sub {
    return pass unless params->{ptd1} || params->{ptd2};
    my ($l1, $l2) = splat;
    my $ctype = "bilingual";
    # XXX get first ID
    my ($corpora) = ref(params->{corpora}) ? @{params->{corpora}} : (params->{corpora});
    my ($dir, $word);
    if (params->{ptd1}) {
        $word = params->{query1};
    } else {
        ($l2, $l1) = ($l1, $l2);
        $word = params->{query2};
    }
    $word = lc $word;
    $word =~ s/^\s+//;
    $word =~ s/\s.*$//;

    redirect "/ptd/$corpora/$l1/$l2/$word";
};

any ['get', 'post'] => qr'/export/(bilingual)/([A-Z]{2})-([A-Z]{2})' => sub {
    return pass if params->{ptd1} || params->{ptd2};
    my ($ctype, $l1, $l2) = splat;
    my $lang = "${l1}_${l2}";
    my $sellang = "${l1}-${l2}";
    my $query1_string = params->{query1} || '';
    my $query1 = guess_query($query1_string) || '';
    my $query2_string = params->{query2} || '';
    my $query2 = guess_query($query2_string) || '';
    unless (params->{corpora}) {
        flash error => 'No corpus selected';
        return redirect request->referer;
    }
	header('Content-Type' => 'text/xml');
    my $corpora = ref(params->{corpora}) eq 'ARRAY' ? params->{corpora} : [params->{corpora}];
    return redirect '/' unless ($corpora and ($query1 or $query2) );

    my ($bil,$search_results);

	my $curr;

    if ($query1 xor $query2) {
        $search_results = __search_results_bil($query1,$query2,$lang,$corpora, 1);
        ($bil,$curr) = __search_bilingual_xor($query1,$query2,$lang,0,-1,0,$corpora, 1);
    }
    else {
        ($bil,$search_results,$curr) = __search_bilingual($query1_string,$query2_string,$lang,0,-1,0,$corpora, 1);
    }

    my $options = session 'options';
    template 'toXML' => { 
                         'toolbar' => { tmx => 0, csv => 0, xces => 0 },
                         'bil'     => $bil,
                         'search_results' => $search_results,
                         'sidebar' => 3,
                         'ctype'   => $ctype,
                         'sellang' => $sellang,
                         'lang1'   => $l1, 'lang2' => $l2,
                         'langs'   => languages($ctype),
                         'selcorpora' => $corpora,
                         'corpora' => corpora($ctype, $lang),
                         'options' => $options,
                         'query1_string' => $query1_string,
                         'query2_string' => $query2_string,
                        }, { layout => 'xml' };
};



any ['get', 'post'] => qr'/search/(bilingual)/([A-Z]{2})-([A-Z]{2})' => sub {
    return pass if params->{ptd1} || params->{ptd2};
    my ($ctype, $l1, $l2) = splat;
    my $lang = "${l1}_${l2}";
    my $sellang = "${l1}-${l2}";
    my $query1_string = params->{query1} || '';
    my $query1 = guess_query($query1_string) || '';
    my $query2_string = params->{query2} || '';
    my $query2 = guess_query($query2_string) || '';
    my $curr = params->{curr} || 0;
    my $from = params->{from} || 0;
    my $pp = params->{pp} || 20;
    unless (params->{corpora}) {
        flash error => 'No corpus selected';
        return redirect request->referer;
    }
    my $corpora = ref(params->{corpora}) eq 'ARRAY' ? params->{corpora} : [params->{corpora}];
    return redirect '/' unless ($corpora and ($query1 or $query2) );

    my $has_prev = 0;
    $has_prev = 1 if ($from > 0 or $curr > 0);
    my $has_next = 1;
    my ($bil,$search_results);

    if ($query1 xor $query2) {
        $search_results = __search_results_bil($query1,$query2,$lang,$corpora);
        ($bil,$curr) = __search_bilingual_xor($query1,$query2,$lang,$curr,$pp,$from,$corpora);
        $from = @$bil[-1]->{to_entry};
        $has_next = 0 if $from >= $search_results->{@$bil[-1]->{crp}};
    }
    else {
        ($bil,$search_results,$curr) = __search_bilingual($query1_string,$query2_string,$lang,$curr,$pp,$from,$corpora);
        $from = @$bil[-1]->{to_entry};
        $has_next = 0 if $from >= $search_results->{@$bil[-1]->{crp}};
    }

    # highlight word concords in opposite language
    if ($query1 xor $query2) {
        my $search = $query1_string ? $query1_string : $query2_string;
        my $side = $query1_string ? 'right' : 'left';
        my $where = $query1_string ? 'st' : 'ts';

        my $found;
        for my $id (@$corpora) {
        		my $ptds = corpus_ptds($id,$l1,$l2);
            my %tmp = $ptds->{$where}->transHash(lc $search);	# lowercase hack. Needs fix in the future
            $found->{$_} = $tmp{$_} foreach (keys %tmp);
        }

        foreach my $c (@$bil) {
            foreach my $i (@{$c->{'ans'}}) {
                $i->{$side} = __highlight_concord($i->{$side}, $found);
            }
        }
    }

    my $options = session 'options';
    template 'index' => { 
                         'toolbar' => { tmx => 0, csv => 0, xces => 0 },
                         'bil'     => $bil,
                         'search_results' => $search_results,
                         'sidebar' => 3,
                         'ctype'   => $ctype,
                         'sellang' => $sellang,
                         'lang1'   => $l1, 'lang2' => $l2,
                         'langs'   => languages($ctype),
                         'selcorpora' => $corpora,
                         'corpora' => corpora($ctype, $lang),
                         'options' => $options,
                         'has_next' => $has_next,
                         'has_prev' => $has_prev,
                         'query1_string' => $query1_string,
                         'query2_string' => $query2_string,
                         'pp'       => $pp,
                         'curr'     => $curr,
                         'from'     => $from,
                        };
};

any ['get', 'post'] => qr'/search/(monolingual)/([A-Z]{2})' => sub {
    my ($ctype, $lang) = splat;
    my $query_string = params->{query} || '';
    my $query = guess_query($query_string) || '';
    my $curr = params->{curr} || 0;
    my $from = params->{from} || 0;
    my $pp = params->{pp} || 20;
    unless (params->{corpora}) {
        flash error => 'No corpus selected';
	     return redirect request->referer;
    }
    my $corpora = ref(params->{corpora}) eq 'ARRAY' ? params->{corpora} : [params->{corpora}];
    return redirect '/' unless ($corpora and $query);

    my $has_prev = 0;
    $has_prev = 1 if ($from > 0 or $curr > 0);

    my $search_results = __search_results($query,$lang,$corpora);
    my $ans;
    ($ans,$curr) = __search_monolingual($query,$lang,$curr,$pp,$from,$corpora);
    $from = @$ans[-1]->{to_entry};

    my $has_next = 1;
    $has_next = 0 if $from >= $search_results->{@$ans[-1]->{crp}};

    my $options = session 'options';
    template 'index' => {
                         'toolbar'  => { tmx => 0, csv => 0, xces => 0 },
                         'mono'     => $ans,
                         'search_results' => $search_results,
                         'log'      => "Querying corpora @$corpora with [$query]",
                         'sidebar'  => 3,
                         'ctype'    => $ctype,
                         'sellang'  => $lang,
                         'langs'    => languages($ctype),
                         'selcorpora' => $corpora,
                         'corpora'  => corpora($ctype, $lang),
                         'options'  => $options,
                         'has_next' => $has_next,
                         'has_prev' => $has_prev,
                         'query_string' => $query_string,
                         'pp'       => $pp,
                         'curr'     => $curr,
                         'from'     => $from,
                        };
};

get qr'/(monolingual|bilingual)/([A-Z]{2}(?:-[A-Z]{2})?)' => sub {
    my ($ctype, $lang) = splat;
    my ($l1, $l2);
    ($l1, $l2) = ($lang =~ /^(..).+(..)$/) if $ctype eq "bilingual";
    session 'search_ctype' => $ctype;
    session 'search_lang' => $lang; # XXX

    template 'index' => {
                         'main'    => 'Select corpus',
                         'sidebar' => 3,
                         'ctype'   => $ctype,
                         'sellang' => $lang,
                         'lang1'   => $l1, 'lang2' => $l2,
                         'langs'   => languages($ctype),
                         'corpora' => corpora($ctype, $lang),
                         'options' => session 'options',
                        };
};

get qr'/(monolingual|bilingual)' => sub {
    my ($type) = splat;
    template 'index' => {
                         'main'    => 'Please fill-in the form',
                         'sidebar' => 2,
                         'ctype'   => $type,
                         'langs'   => languages($type),
                         'options' => session 'options',
                        };
};

get '/' => sub {
    template 'index' => {
                         'main'    => 'Please fill-in the form',
                         'sidebar' => 1,
                         'ctype'   => 'monolingual',
                         'options' => session 'options',
                        };
};

post '/redirect' => sub {
    my $var = params->{var};
    given ($var) {
        when ('ctype') {
            redirect mybase . params->{ctype};
        }
        when ('langs') {
            redirect mybase . params->{ctype}."/".params->{langs};
        }
        default {
            redirect mybase;
        }
    };
};

get '/options/:key/:value' => sub {
    my $key = params->{'key'};
    my $value = params->{'value'};

    if ($key eq 'menu_hor') { # XXX verify other keys/values
        my $s = session;
        $s->{'options'}->{$key} = $value;
    }

	redirect request->referer;
};

sub corpora {
	my ($ctype, $lang) = @_;
	$lang = lc $lang;
	$lang =~ s/[\_\-]/-/;

	my $corpus;
   my @dirs = <$RESOURCES/corpus/*>;
   foreach (@dirs) {
      my $name = basename $_;
      next if $name =~ m/^\./;
      next if $name =~ m/deleted$/;

      my $metafile = "$RESOURCES/corpus/$name/corpus.xml";
      if (-e $metafile) {
         my $c = XMLin($metafile);

			# language filter
			next unless ($c->{generated}->{cwb});
			my $found = 0;
			if (ref($c->{generated}->{cwb}) eq 'ARRAY') {
				foreach (@{$c->{generated}->{cwb}}) {
					$found++ if $_->{dirname} =~ m/\-$lang$/;
				}
			}
			else {
				$found++ if $c->{generated}->{cwb}->{dirname} =~ m/\-$lang$/
			}

         $corpus->{$name} = $c if $found;
      }
   }

   return $corpus;
}

sub languages {
	my ($ctype) = @_;

	my %langs;
	my @dirs = <$RESOURCES/corpus/*>;
	foreach (@dirs) {
		my $name = basename $_;
		next if $name =~ m/^\./;
		next if $name =~ m/deleted$/;

		my $metafile = "$RESOURCES/corpus/$name/corpus.xml";
		if (-e $metafile) {
			my $c = XMLin($metafile);
			next unless ($c->{generated} and $c->{generated}->{cwb});

			foreach (@{$c->{generated}->{cwb}}) {
				next unless (ref($_) eq 'HASH');

				if ($ctype eq 'monolingual') {
					if ($_->{dirname} =~ m/\-(\w{2})$/) { # XXX
						$langs{uc($1)}++;
					}
				}
				else {
					if ($_->{dirname} =~ m/\-(\w{2})[\-\_]+(\w{2})$/) { # XXX
						$langs{uc($1).'-'.uc($2)}++;
					}
				}
			}
		}
	}

	return [sort keys %langs];
}

sub __search_monolingual {
    my ($query,$lang,$curr,$pp,$from_entry,$corpora) = @_;
    my $to_entry = $from_entry + $pp - 1;

    my %data = __corpora_data($corpora,$lang);

    my ($ans, $C);
    my $cwb = CWB::CQP::More->new( { utf8 => 1 } );
    my $total = 0;
    while ($curr < scalar(@$corpora)) {
        my $id = @$corpora[$curr];

        if ($total+$to_entry-$from_entry > $pp) {
            $to_entry = $pp - $total;  
        }
        $cwb->change_corpus($data{$id}->{cwb_id});
        $cwb->set(Context => 'tu', PrintStructures => '"tu_id"',
                  LD => "'<b>'", RD => "'</b>'");
        $cwb->annotation_hide('cpos');
        try {
            $cwb->exec_query($query);
            my $size = $cwb->size('A');
            my $lines;
            if ($size > 0) {
                @$lines = map {
                    my ($tu, $text) = clean_simplematch($_);
                    ++$C;
                    my $meta = "#".($from_entry+$C)." &mdash; $data{$id}{name} &mdash; TU $tu";
                    { meta => $meta, match => $text }
                } $cwb->cat('A', $from_entry, $to_entry);
                push @$ans, { crp => $data{$id}{name},
                              from_entry => $from_entry,
                              to_entry => $from_entry+scalar(@$lines),
                              size => $size,
                              shown_size => min($size, $SAMPLE_SIZE),
                              ans => $lines }
            } else {
                push @$ans, { crp => $data{$id}{name},
                              from_entry => 0,
                              to_entry => 0,
                              shown_size => 0,
                              size => 0 }
            }
            $total += scalar(@$lines) + 1;
        } catch {
            ## XXX => fixme
            print STDERR "CWB ERROR ==> $_\n";
        };
        if ($total > $pp) {
            last;
        }
        $curr++;
        $C = 0;
    }

    return ($ans,$curr);
}

sub __search_bilingual_xor {
    my ($query1,$query2,$lang,$curr,$pp,$from_entry,$corpora,$raw) = @_;
    my $to_entry = $from_entry + $pp - 1;

    my %data = __corpora_data_bil($corpora,$lang);

    my $cwb = CWB::CQP::More->new({utf8 => 1});
    my ($C, $bil);
    if ($query1 xor $query2) {
        my $total = 0;
        while ($curr < scalar(@$corpora)) {
            my $id = @$corpora[$curr];

            if ($total+$to_entry-$from_entry > $pp) {
                $to_entry = $pp - $total;
            }

            if ($query1) {
                $cwb->change_corpus($data{$id}->{cwb_sid});
                $cwb->annotation_show($data{$id}->{cwb_tid});
            } else {
                $cwb->change_corpus($data{$id}->{cwb_tid});
                $cwb->annotation_show($data{$id}->{cwb_sid});
            }
			
			if(defined $raw){
				$cwb->set(Context => 'tu', LD => "''", RD => "''", PrintStructures => '"tu_id"');
			}
			else{
				$cwb->set(Context => 'tu', LD => "'<b>'", RD => "'</b>'", PrintStructures => '"tu_id"');
			}
            $cwb->annotation_hide('cpos');
            try {
                $cwb->exec_query($query1 ? $query1 : $query2);
                my $size = $cwb->size('A');
                my (@pairs, $res, @lines);
                if ($size > 0) {
                    @lines = $cwb->cat('A', $from_entry, $to_entry);
                    while (@lines) {
                        push @pairs, [shift @lines, shift @lines];
                    }
                    @$res = map {
                        my ($tu, $m) = clean_simplematch($_->[0]);
                        my $t = clean_translation($_->[1]);
                        $C++;
                        my ($left, $right) = $query1 ? ($m, $t) : ($t, $m);
                        +{ 'meta'  => "#".($from_entry+$C)." &mdash; $data{$id}{name} &mdash; TU $tu",
                           'left'  => $left,
                           'right' => $right }
                    } @pairs;
                    push @$bil, { crp => $data{$id}{name},
                                  from_entry => $from_entry,
                                  to_entry => $from_entry+scalar(@pairs),
                                  id => $id,
                                  size => $size,
                                  #note => $data{$id}{ptd} ? "with PTD" : "",
                                  shown_size => min($size, $SAMPLE_SIZE),
                                  ans => $res };
                } else {
                    push @$bil, { crp => $data{$id}{name},
                                  from_entry => 0,
                                  to_entry => 0,
                                  shown_size => 0,
                                  size => 0 };
                }
                $total += scalar(@pairs) + 1;
            } catch {
                ## XXX => fixme
                error "CWB ERROR ==> $_\n";
                print STDERR "CWB ERROR ==> $_\n";
            };
            if ($pp != -1 && $total > $pp) {
                last;
            }
            $curr++;
            $C = 0;
        }
    }

    return ($bil, $curr);
}

sub __search_bilingual {
    my ($query1_string,$query2_string,$lang,$curr,$pp,$from_entry,$corpora, $raw) = @_;
    my $to_entry = $from_entry + $pp - 1;

    my %data = __corpora_data_bil($corpora,$lang);
    my $query1 = guess_query($query1_string);
    my $query2 = guess_query($query2_string, "B");

    my $cwb = CWB::CQP::More->new({utf8 => 1});
    my ($C, $bil);
    foreach my $id (@$corpora) {
       try {
            $cwb->change_corpus($data{$id}{cwb_sid});

			if(defined $raw){
				$cwb->set(Context => 'tu', LD => "''", RD => "''", PrintStructures => '"tu_id"');
			}
			else{
				$cwb->set(Context => 'tu', LD => "'<b>'", RD => "'</b>'", PrintStructures => '"tu_id"');
			}

            $cwb->annotation_hide('cpos');
            $cwb->exec_query($query1);
            my $s1  = $cwb->size('A');
            my $it1 = $cwb->iterator('A', size => 1, corpus => $data{$id}{cwb_sid});

            $cwb->change_corpus($data{$id}{cwb_tid});
			if(defined $raw){
				$cwb->set(Context => 'tu', LD => "''", RD => "''", PrintStructures => '"tu_id"');
			}
			else{
				$cwb->set(Context => 'tu', LD => "'<b>'", RD => "'</b>'", PrintStructures => '"tu_id"');
			}

            $cwb->annotation_hide('cpos');
            $cwb->exec_query($query2);
            my $s2  = $cwb->size('B');
            my $it2 = $cwb->iterator('B', size => 1, corpus => $data{$id}{cwb_tid});

            if ($s1 > 0 && $s2 > 0) {
            	my ($id1, $id2, $match1, $match2, $list);    
                my $C = 0;
                my ($peeked1, $peeked2) = (0, 0);
                my $nriterations;

                ($id1, $match1) = clean_simplematch($it1->next);
                ($id2, $match2) = clean_simplematch($it2->next);

                while ($id1 && $id2) {
                    $nriterations++;
                    if ($id1 == $id2) {
                        $C++;
                        push @$list, {
                                      meta  => "#$C $id1",
                                      left  => $match1,
                                      right => $match2
                                     };
                        ($id1, $match1) = clean_simplematch($it1->next);
                        ($id2, $match2) = clean_simplematch($it2->next);
                    }
                    elsif ($id1 + 1000 < $id2 && not($peeked1)) {
                        my $peek = $it1->peek(100);
                        if ($peek) {
                            my ($i, $m) = clean_simplematch($peek);
                            if ($i < $id2) {
                                ($id1, $match1) = ($i, $m);
                                $it1->forward(100);
                            } else {
                                $peeked1 = 100;
                            }
                        }
                        if (!$peek || $peeked1) {
                            ($id1, $match1) = clean_simplematch($it1->next);
                        }
                        }
                    elsif ($id2 + 1000 < $id1 && not($peeked2)) {
                        my $peek = $it2->peek(100);
                        if ($peek) {
                            my ($i, $m) = clean_simplematch($peek);
                            if ($i < $id1) {
                                ($id2, $match2) = ($i, $m);
                                $it2->forward(100);

                            } else {
                                $peeked2 = 100;
                            }
                        }
                        if (!$peek || $peeked2) {
                            ($id2, $match2) = clean_simplematch($it2->next);
                        }
                    }
                    elsif ($id1 < $id2) {
                        $peeked1-- if $peeked1;
                        ($id1, $match1) = clean_simplematch($it1->next);
                    }
                    elsif ($id2 < $id1) {
                        $peeked2-- if $peeked2;
                        ($id2, $match2) = clean_simplematch($it2->next);
                    }
                }

                if ($C) {
                    push @$bil, { id => $id,
                                  from_entry => 0,
                                  to_entry => 0,
                                  crp => $data{$id}{name},
                                  ans => $list,
                                  note => $data{$id}{ptd} ? "with PTD" : "",
                                  shown_size => $C,
                                  size => '?' };
                } else {
                    push @$bil, { crp => $data{$id}{name},
                                  from_entry => 0,
                                  to_entry => 0,
                                  shown_size => 0,
                                  size => 0 };
                }
            } else {
                push @$bil, { crp => $data{$id}{name},
                              from_entry => 0,
                              to_entry => 0,
                              shown_size => 0,
                              size => 0 };
            }
        } catch {
            ## XXX => fixme
            error  "CWB ERROR ==> $_\n";
            print STDERR "CWB ERROR ==> $_\n";
        };
    }

    # calculate search results before cut
    my $search_results;
    foreach my $c (@$bil) {
        $search_results->{$c->{crp}} = $c->{ans} ? scalar @{$c->{ans}} : 0;
    }

    # cut final results
    my $total = 0;
    my $cut = [];
    while ($curr < scalar(@$bil)) {
        my $c = @$bil[$curr];
        $c->{ans} = [@{$c->{ans}}[$from_entry .. $to_entry]];
        $c->{ans} = [grep {defined} @{$c->{ans}}];
        my $entries = scalar @{$c->{ans}};
        $c->{from_entry} = $from_entry;
        $c->{to_entry} = $from_entry + $entries;
        $total += $entries;
        push @$cut, $c;

        if ($pp != -1 && $total >= $pp) {
            last;
        }

        $curr++;
        $from_entry = 0;
        $to_entry = $from_entry + ($pp - $entries) - 1;
    }
    $bil = $cut;

    return ($bil, $search_results, $curr);
}

sub __search_results {
    my ($query,$lang,$corpora, $raw) = @_;

    my $search_results;
    my %data = __corpora_data($corpora,$lang);

    my $cwb = CWB::CQP::More->new( { utf8 => 1 } );
    foreach my $id (@$corpora) {
        $cwb->change_corpus($data{$id}->{cwb_id});

		if(defined $raw){
			$cwb->set(Context => 'tu', LD => "''", RD => "''", PrintStructures => '"tu_id"');
		}
		else{
			$cwb->set(Context => 'tu', LD => "'<b>'", RD => "'</b>'", PrintStructures => '"tu_id"');
		}

        $cwb->annotation_hide('cpos');
        my $size;
        try {
            $cwb->exec_query($query);
            $size = $cwb->size('A');
        } catch {
            ## XXX => fixme
            print STDERR "CWB ERROR ==> $_\n";
        };

        $search_results->{$id} = $size;
    }

    return $search_results;
}

sub __search_results_bil { # XXX merge with __search_results if possible ???
    my ($query1,$query2,$lang,$corpora, $raw) = @_;

    my $search_results;
    my %data = __corpora_data_bil($corpora,$lang);

    my $cwb = CWB::CQP::More->new( { utf8 => 1 } );
    foreach my $id (@$corpora) {
        if ($query1) {
            $cwb->change_corpus($data{$id}->{cwb_sid});
            $cwb->annotation_show($data{$id}->{cwb_tid});
        } else {
            $cwb->change_corpus($data{$id}->{cwb_tid});
            $cwb->annotation_show($data{$id}->{cwb_sid});
        }

		if(defined $raw){
			$cwb->set(Context => 'tu', LD => "''", RD => "''", PrintStructures => '"tu_id"');
		}
		else{
			$cwb->set(Context => 'tu', LD => "'<b>'", RD => "'</b>'", PrintStructures => '"tu_id"');
		}

        $cwb->annotation_hide('cpos');
        my $size;
        try {
            $cwb->exec_query($query1 ? $query1 : $query2);
            $size = $cwb->size('A');
        } catch {
            ## XXX => fixme
            print STDERR "CWB ERROR ==> $_\n";
        };

        $search_results->{$id} = $size;
    }

    return $search_results;
}

sub __corpora_data {
    my ($corpora,$lang) = @_;

    my %data;
    foreach my $id (@$corpora) {
        $data{$id} = { name => $id, cwb_id => __get_cwb_id($id,$lang) };
    }

    return %data;
}

sub __corpora_data_bil { # XXX merge with __corpora_data if possible ???
    my ($corpora,$lang) = @_;

    my %data;
    for my $id (@$corpora) {
        $data{$id} = {
            name => $id,
                cwb_sid => __get_cwb_id($id,$lang,'sid'),
                cwb_tid => __get_cwb_id($id,$lang,'tid'),
          };
    }

    return %data;
}



sub max {
    return $_[0]>$_[1]?$_[0]:$_[1];
}
sub min {
    return $_[0]<$_[1]?$_[0]:$_[1];
}

sub guess_query {
    my $query = shift;
    my $name = shift || "A";
    return "" unless $query !~ /^\s*$/;
    $query =~ s/^\s+//;
    $query =~ s/\s+$//;
    if ($query !~ /"/) {
        $query =~ s/^/"/;
        $query =~ s/$/"/;
        $query =~ s/\s+/" "/g;
    }
    $query .= ";" unless $query =~ /;\s*$/;
    $query = "$name = $query";

    return $query;
}


sub clean_simplematch {
    my $match = shift;
    return (0, undef) unless $match;
    $match =~ s/<\/tu_id>//;
    $match =~ s/<tu_id\s+(\d+)>\s*:?//;
    my $tu = $1;
    return ($tu, $match);
}

sub clean_translation {
    my $match = shift;
    $match =~ s/^-->[^:]+:\s*//;
    return $match;
}

sub corpus_info {
    my $id = shift;

    my $metafile = "$RESOURCES/corpus/$id/corpus.xml";
    return unless -e $metafile;
    my $c = XMLin($metafile);

    return $c;
}

sub corpus_ptds {
	my ($name,$l1,$l2) = @_;

	my $metafile = "$RESOURCES/corpus/$name/corpus.xml";
	return unless -e $metafile;

	my $c = XMLin($metafile);
	return unless ($c->{generated} and $c->{generated}->{ptd});

	my $res;
	if (ref($c->{generated}->{ptd}) eq 'ARRAY') {
		foreach (@{$c->{generated}->{ptd}}) {
			if ($_ =~ m/$l1\-$l2/i) {
				my $file = "$RESOURCES/corpus/$name/$_";
				$file =~ s/dmp$/sqlite/;
				my $st = Lingua::NATools::PTD->new($file);
				$res->{st} = $st;
			}
			if ($_ =~ m/$l2\-$l1/i) {
				my $file = "$RESOURCES/corpus/$name/$_";
				$file =~ s/dmp$/sqlite/;
				my $ts = Lingua::NATools::PTD->new($file);
				$res->{ts} = $ts;
			}
		}
	}
	else {
		# XXX only one ptd !?
	}

	return $res;
}

sub mega_ptd {
    my @langs = map { lc } @_;
    my $dir = File::Spec->catdir($PTD_DIR => sprintf("all_%s_%s", @langs));
    if (-d $dir) {
        my $st = Lingua::NATools::PTD->new(File::Spec->catfile($dir => sprintf("%s-%s.sqlite",@langs))) if -e sprintf("%s-%s.sqlite",@langs);
        my $ts = Lingua::NATools::PTD->new(File::Spec->catfile($dir => sprintf("%s-%s.sqlite",reverse @langs))) if -e sprintf("%s-%s.sqlite",reverse @langs);
        return undef unless $st && $ts;
        return { st => $st, ts => $ts };
    } else {
        return undef;
    }
}

# Stolen code from Ovid blog.
sub gradient {
    my ( $min, $max ) = @_;

    my $middle = ( $min + $max ) / 2;
    my $scale = 255 / ( $middle - $min );

    return sub {
        my $num = shift;
        return "FF0000" if $num <= $min;    # lower boundry
        return "00FF00" if $num >= $max;    # upper boundary

        if ( $num < $middle ) {
            return sprintf "FF%02X00" => int( ( $num - $min ) * $scale );
        }
        else {
            return
              sprintf "%02XFF00" => 255 - int( ( $num - $middle ) * $scale );
        }
    };
}

sub __highlight_concord {
    my ($txt, $found) = @_;
    my $grad = gradient(0,100);

    foreach (keys %$found) {
        my $color = $grad->(100*$found->{$_});
        $txt =~ s/\b$_\b/<span class="hl" style="color: #$color;">$_<\/span>/gi;	
    }

    return $txt;
}

sub __get_cwb_id {
	my ($corpus, $lang, $pair) = @_;
	$lang = lc $lang;
	$lang =~ s/_/-/;

	my $metafile = "$RESOURCES/corpus/$corpus/corpus.xml";
	my $c = XMLin($metafile);
	return unless ($c and $c->{generated} and $c->{generated}->{cwb});

	my $id;
	foreach (@{$c->{generated}->{cwb}}) {
		if ($pair) {
			$id = $_->{content} if (($_->{dirname} =~ m/\-$lang/) and ($_->{pair} eq $pair));
		}
		else {
			$id = $_->{content} if ($_->{dirname} =~ m/\-$lang/);
		}
	}

	return lc($id);
}

true;
