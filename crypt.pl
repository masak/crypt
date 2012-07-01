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
    has $.source;
    has $.target;
}

class AchievementUnlocked does Event {
}

class AchievementLocked does Event {
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

class X::Hanoi::RodHasNoDisks is Exception {
    has $.name;

    method message($_:) {
        "Cannot move from the {.name} rod because there is no disk there"
    }
}

class HanoiGame {
    my @disks = map { "$_ disk" }, <tiny small medium big huge>;
    my %size_of = @disks Z 1..5;

    has %!state =
        left   => [reverse @disks],
        middle => [],
        right  => [],
    ;

    has $!achievement = 'locked';

    method move($source, $target) {
        die X::Hanoi::NoSuchRod.new(:rod<source>, :name($source))
            unless %!state.exists($source);
        die X::Hanoi::NoSuchRod.new(:rod<target>, :name($target))
            unless %!state.exists($target);
        my @source_rod := %!state{$source};
        die X::Hanoi::RodHasNoDisks.new(:name($source))
            unless @source_rod;
        my @target_rod := %!state{$target};
        my $moved_disk = @source_rod[*-1];
        if @target_rod {
            my $covered_disk = @target_rod[*-1];
            if %size_of{$moved_disk} > %size_of{$covered_disk} {
                die X::Hanoi::LargerOnSmaller.new(
                    :larger($moved_disk),
                    :smaller($covered_disk)
                );
            }
        }
        @target_rod.push( @source_rod.pop );
        my $size = $moved_disk.words[0];
        my @events = DiskMoved.new(:$size, :$source, :$target);
        if %!state<right> == @disks && $!achievement eq 'locked' {
            $!achievement = 'unlocked';
            @events.push(AchievementUnlocked.new);
        }
        if $size eq 'small' && $!achievement eq 'unlocked' {
            $!achievement = 'locked';
            @events.push(AchievementLocked.new);
        }
        return @events;
    }
}

sub throws_exception(&code, $ex_type, $message, &followup?) {
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
    {
        my $game = HanoiGame.new();

        is $game.move('left', 'middle'),
           DiskMoved.new(:size<tiny>, :source<left>, :target<middle>),
           'legal move (+)';

        throws_exception
            { $game.move('left', 'middle') },
            X::Hanoi::LargerOnSmaller,
            'legal move (-) larger disk on smaller',
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
            'legal move (-) no such source rod',
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
            'legal move (-) no such target rod',
            {
                is .rod, 'target', '.rod attribute';
                is .name, 'clown', '.name attribute';
                is .message,
                   q[No such target rod 'clown'],
                   '.message attribute';
            };

        throws_exception
            { $game.move('right', 'middle') },
            X::Hanoi::RodHasNoDisks,
            'legal move (-) rod has no disks',
            {
                is .name, 'right', '.name attribute';
                is .message,
                   q[Cannot move from the right rod because there is no disk there],
                   '.message attribute';
            };
    }

    {
        my $game = HanoiGame.new();

        multi hanoi_moves($source, $, $target, 1) {
            # A single disk, easy; just move it directly.
            $source, 'to', $target
        }
        multi hanoi_moves($source, $helper, $target, $n) {
            # $n-1 disks on to; move them off to the $helper rod first...
            hanoi_moves($source, $target, $helper, $n-1),
            # ...then move over the freed disk at the bottom...
            hanoi_moves($source, $helper, $target, 1),
            # ...and finally move the rest from $helper to $target.
            hanoi_moves($helper, $source, $target, $n-1)
        }

        # Let's play out the thing to the end. 32 moves.
        my @moves = hanoi_moves("left", "middle", "right", 5);
        # RAKUDO: .splice doesn't do WhateverCode yet: wanted *-3
        my @last_move = @moves.splice(@moves.end-2);

        lives_ok {
            for @moves -> $source, $, $target {
                my ($event, @rest) = $game.move($source, $target);
                die "Unexpected event type: {$event.name}"
                    unless $event ~~ DiskMoved;
                die "Unexpected extra events: @rest"
                    if @rest;
            }
        }, 'making all the moves to the end of the game works';

        {
            my ($source, $, $target) = @last_move;
            is $game.move($source, $target), (
                DiskMoved.new(:size<tiny>, :$source, :$target),
                AchievementUnlocked.new(),
            ), 'putting all disks on the right rod unlocks achievement';

            $game.move($target, $source);
            is $game.move($source, $target), (
                DiskMoved.new(:size<tiny>, :$source, :$target),
            ), 'moving things back and forth does not unlock achievement again';
        }

        {
            $game.move('right', 'middle');
            is $game.move(my $source = 'right', my $target = 'left'), (
                DiskMoved.new(:size<small>, :$source, :$target),
                AchievementLocked.new(),
            ), 'removing two disks from the right rod locks achievement';
        }
    }

    done;
}
