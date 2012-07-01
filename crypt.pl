use Test;

role Event {
    method Str {
        sub event() { self.^name }
        sub name($attr) { $attr.name.substr(2) }
        sub value($attr) { $attr.get_value(self) }

        "{event}[{map { ":{name $_}<{value $_}>" }, self.^attributes}]"
    }
}

class DiskMoved does Event {
    has $.size;
    has $.from;
    has $.to;
}

class X::Hanoi::LargerOnSmaller is Exception {
    has $.larger;
    has $.smaller;

    method message($_:) {
        "Cannot put the {.larger} on the {.smaller}"
    }
}

class X::Hanoi::NoSuchRod is Exception {
    has $.rod;
    has $.name;

    method message($_:) {
        "No such {.rod} rod '{.name}'"
    }
}

class HanoiGame {
    my @names = map { "$_ disk" }, <tiny small medium big huge>;
    my %size_of = @names Z 1..5;

    has %!state =
        left   => [reverse @names],
        middle => [],
        right  => [],
    ;

    method move($from, $to) {
        die X::Hanoi::NoSuchRod.new(:rod<source>, :name($from))
            unless %!state.exists($from);
        die X::Hanoi::NoSuchRod.new(:rod<target>, :name($to))
            unless %!state.exists($to);
        my @from_rod := %!state{$from};
        my @to_rod   := %!state{$to};
        my $moved_disk = @from_rod[*-1];
        if @to_rod {
            my $covered_disk = @to_rod[*-1];
            if %size_of{$moved_disk} > %size_of{$covered_disk} {
                die X::Hanoi::LargerOnSmaller.new(
                    :larger($moved_disk),
                    :smaller($covered_disk)
                );
            }
        }
        @to_rod.push( @from_rod.pop );
        my $size = $moved_disk.words[0];
        DiskMoved.new(:$size, :$from, :$to);
    }
}

sub throws_exception(&code, $ex_type, &followup?) {
    my $message = 'code dies as expected';
    &code();
    ok 0, $message;
    if &followup {
        diag 'Not running followup because an exception was not triggered';
    }
    CATCH {
        default {
            ok 1, $message;
            my $type_ok = $_.WHAT === $ex_type;
            ok $type_ok , "right exception type ({$ex_type.^name})";
            if $type_ok {
                &followup($_);
            } else {
                diag "Got:      {$_.WHAT.gist}\n"
                    ~"Expected: {$ex_type.gist}";
                diag "Exception message: $_.message()";
                diag 'Not running followup because type check failed';
            }
        }
    }
}

multi MAIN('test', 'hanoi') {
    my $game = HanoiGame.new();

    is $game.move('left', 'middle'),
       DiskMoved.new(:size<tiny>, :from<left>, :to<middle>),
       'legal move (+)';

    throws_exception
        { $game.move('left', 'middle') },
        X::Hanoi::LargerOnSmaller,
        {
            is .larger, 'small disk', '.larger attribute';
            is .smaller, 'tiny disk', '.smaller attribute';
            is .message,
               'Cannot put the small disk on the tiny disk',
               '.message attribute';
        };

    throws_exception
        { $game.move('gargle', 'middle') },
        X::Hanoi::NoSuchRod,
        {
            is .rod, 'source', '.rod attribute';
            is .name, 'gargle', '.name attribute';
            is .message,
               q[No such source rod 'gargle'],
               '.message attribute';
        };

    throws_exception
        { $game.move('middle', 'clown') },
        X::Hanoi::NoSuchRod,
        {
            is .rod, 'target', '.rod attribute';
            is .name, 'clown', '.name attribute';
            is .message,
               q[No such target rod 'clown'],
               '.message attribute';
        };

    done;
}
