use Test;

role Event {
    method Str {
        sub event() { self.^name }
        sub name($attr) { $attr.name.substr(2) }
        sub value($attr) { $attr.get_value(self) }

        "{event}[{map { ":{name $_}<{value $_}>" }, self.^attributes}]"
    }
}

class Hanoi::DiskMoved does Event {
    has $.size;
    has $.source;
    has $.target;
}

class Hanoi::AchievementUnlocked does Event {
}

class Hanoi::AchievementLocked does Event {
}

class Hanoi::DiskRemoved does Event {
    has $.size;
    has $.source;
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

class X::Hanoi::CoveredDisk is Exception {
    has $.disk;
    has @.covered_by;

    method message($_:) {
        sub last_and(@things) {
            map { "{'and ' if $_ == @things.end}@things[$_]" }, ^@things
        }
        my $disklist = @.covered_by > 1
            ?? join ', ', last_and map { "the $_" }, @.covered_by
            !! "the @.covered_by[0]";
        "Cannot move the {.disk}: it is covered by $disklist"
    }
}

class X::Hanoi::ForbiddenDiskRemoval is Exception {
    has $.disk;

    method message($_:) {
        "Removing the {.disk} is forbidden"
    }
}

class X::Hanoi::DiskHasBeenRemoved is Exception {
    has $.disk;
    has $.action;

    method message($_:) {
        "Cannot {.action} the {.disk} because it has been removed"
    }
}

class Hanoi::Game {
    my @disks = map { "$_ disk" }, <tiny small medium large huge>;
    my %size_of = @disks Z 1..5;

    has %!state =
        left   => [reverse @disks],
        middle => [],
        right  => [],
    ;

    has $!achievement = 'locked';

    method move($source is copy, $target) {
        my @source_rod;
        if $source eq any @disks {
            my $disk = $source;
            for %!state -> ( :key($rod), :value(@disks) ) {
                if $disk eq any(@disks) {
                    sub smaller_disks {
                        grep { %size_of{$_} < %size_of{$disk} }, @disks;
                    }
                    die X::Hanoi::CoveredDisk.new(:$disk, :covered_by(smaller_disks))
                        unless @disks[*-1] eq $disk;
                    @source_rod := @disks;
                    $source = $rod;
                    last;
                }
            }
            die X::Hanoi::DiskHasBeenRemoved.new(:action<move>, :$disk)
                unless @source_rod;
        }
        else {
            die X::Hanoi::NoSuchRod.new(:rod<source>, :name($source))
                unless %!state.exists($source);
            @source_rod := %!state{$source};
        }
        die X::Hanoi::NoSuchRod.new(:rod<target>, :name($target))
            unless %!state.exists($target);
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
        my $size = $moved_disk.words[0];
        my @events = Hanoi::DiskMoved.new(:$size, :$source, :$target);
        if %!state<right> == @disks-1
           && $target eq 'right'
           && $!achievement eq 'locked' {
            @events.push(Hanoi::AchievementUnlocked.new);
        }
        if $size eq 'small' && $!achievement eq 'unlocked' {
            @events.push(Hanoi::AchievementLocked.new);
        }
        self!apply($_) for @events;
        return @events;
    }

    method remove($disk) {
        my $size = $disk.words[0];
        my $source;
        for %!state -> ( :key($rod), :value(@disks) ) {
            if $disk eq any(@disks) {
                sub smaller_disks {
                    grep { %size_of{$_} < %size_of{$disk} }, @disks;
                }
                die X::Hanoi::CoveredDisk.new(:$disk, :covered_by(smaller_disks))
                    unless @disks[*-1] eq $disk;
                $source = $rod;
                last;
            }
        }
        die X::Hanoi::DiskHasBeenRemoved.new(:action<remove>, :$disk)
            unless defined $source;
        die X::Hanoi::ForbiddenDiskRemoval.new(:$disk)
            unless $size eq 'tiny';
        my @events = Hanoi::DiskRemoved.new(:$size, :$source);
        self!apply($_) for @events;
        return @events;
    }

    # RAKUDO: private multimethods NYI
    method !apply(Event $_) {
        when Hanoi::DiskMoved {
            my @source_rod := %!state{.source};
            my @target_rod := %!state{.target};
            @target_rod.push( @source_rod.pop );
        }
        when Hanoi::AchievementUnlocked {
            $!achievement = 'unlocked';
        }
        when Hanoi::AchievementLocked {
            $!achievement = 'locked';
        }
        when Hanoi::DiskRemoved {
            my @source_rod := %!state{.source};
            @source_rod.pop;
        }
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
        my $game = Hanoi::Game.new();

        is $game.move('left', 'middle'),
           Hanoi::DiskMoved.new(:size<tiny>, :source<left>, :target<middle>),
           'moving a disk (+)';

        throws_exception
            { $game.move('left', 'middle') },
            X::Hanoi::LargerOnSmaller,
            'moving a disk (-) larger disk on smaller',
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
            'moving a disk (-) no such source rod',
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
            'moving a disk (-) no such target rod',
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
            'moving a disk (-) rod has no disks',
            {
                is .name, 'right', '.name attribute';
                is .message,
                   q[Cannot move from the right rod because there is no disk there],
                   '.message attribute';
            };
    }

    {
        my $game = Hanoi::Game.new();

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
                    unless $event ~~ Hanoi::DiskMoved;
                die "Unexpected extra events: @rest"
                    if @rest;
            }
        }, 'making all the moves to the end of the game works';

        {
            my ($source, $, $target) = @last_move;
            is $game.move($source, $target), (
                Hanoi::DiskMoved.new(:size<tiny>, :$source, :$target),
                Hanoi::AchievementUnlocked.new(),
            ), 'putting all disks on the right rod unlocks achievement';

            $game.move($target, $source);
            is $game.move($source, $target), (
                Hanoi::DiskMoved.new(:size<tiny>, :$source, :$target),
            ), 'moving things back and forth does not unlock achievement again';
        }

        {
            $game.move('right', 'middle');
            is $game.move(my $source = 'right', my $target = 'left'), (
                Hanoi::DiskMoved.new(:size<small>, :$source, :$target),
                Hanoi::AchievementLocked.new(),
            ), 'removing two disks from the right rod locks achievement';
        }
    }

    {
        my $game = Hanoi::Game.new();

        is $game.move('tiny disk', my $target = 'middle'),
           Hanoi::DiskMoved.new(:size<tiny>, :source<left>, :$target),
           'naming source disk instead of the rod (+)';
    }

    {
        my $game = Hanoi::Game.new();

        throws_exception
            { $game.move('large disk', 'right') },
            X::Hanoi::CoveredDisk,
            'naming source disk instead of the rod (-)',
            {
                is .disk, 'large disk', '.disk attribute';
                is .covered_by, ['medium disk', 'small disk', 'tiny disk'],
                    '.covered_by attribute';
                is .message,
                   'Cannot move the large disk: it is covered by '
                   ~ 'the medium disk, the small disk, and the tiny disk',
                   '.message attribute';
            };
    }

    {
        my $game = Hanoi::Game.new();

        throws_exception
            { $game.move('small disk', 'right') },
            X::Hanoi::CoveredDisk,
            'naming source disk instead of the rod (-) no and for one-item lists',
            {
                is .message,
                   'Cannot move the small disk: it is covered by the tiny disk',
                   '.message attribute';
            };
    }

    {
        my $game = Hanoi::Game.new();

        is $game.remove('tiny disk'),
           Hanoi::DiskRemoved.new(:size<tiny>, :source<left>),
           'removing a disk (+)';

        throws_exception
            { $game.remove('small disk') },
            X::Hanoi::ForbiddenDiskRemoval,
            'removing a disk (-) removing disk is forbidden',
            {
                is .disk, 'small disk', '.disk attribute';
                is .message,
                   'Removing the small disk is forbidden',
                   '.message attribute';
            };

        throws_exception
            { $game.remove('medium disk') },
            X::Hanoi::CoveredDisk,
            'removing a disk (-) the disk is covered',
            {
                is .disk, 'medium disk', '.disk attribute';
                is .covered_by, ['small disk'],
                    '.covered_by attribute';
            };

        $game.move('small disk', 'middle');
        throws_exception
            { $game.remove('medium disk') },
            X::Hanoi::ForbiddenDiskRemoval,
            'removing a disk (-) uncovered, removal is still forbidden',
            {
                is .disk, 'medium disk', '.disk attribute';
            };
    }

    {
        my $game = Hanoi::Game.new();

        $game.remove('tiny disk');

        throws_exception
            { $game.remove('tiny disk') },
            X::Hanoi::DiskHasBeenRemoved,
            'removing a disk (-) the disk had already been removed',
            {
                is .disk, 'tiny disk', '.disk attribute';
                is .action, 'remove', '.action attribute';
                is .message,
                   'Cannot remove the tiny disk because it has been removed',
                   '.message attribute';
            };

        throws_exception
            { $game.move('tiny disk', 'middle') },
            X::Hanoi::DiskHasBeenRemoved,
            'moving a disk (-) the disk had already been removed',
            {
                is .disk, 'tiny disk', '.disk attribute';
                is .action, 'move', '.action attribute';
                is .message,
                    'Cannot move the tiny disk because it has been removed',
                    '.message attribute';
            };
    }

    done;
}
