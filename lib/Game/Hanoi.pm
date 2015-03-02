use Event;

class X::Hanoi is Exception {
}

class X::Hanoi::LargerOnSmaller is X::Hanoi {
    has $.larger;
    has $.smaller;

    method message {
        "Cannot put the $.larger on the $.smaller"
    }
}

class X::Hanoi::NoSuchRod is X::Hanoi {
    has $.rod;
    has $.name;

    method message {
        "No such $.rod rod '$.name'"
    }
}

class X::Hanoi::RodHasNoDisks is X::Hanoi {
    has $.name;

    method message {
        "Cannot move from the $.name rod because there is no disk there"
    }
}

class X::Hanoi::CoveredDisk is X::Hanoi {
    has $.disk;
    has @.covered_by;

    method message {
        sub last_and(@things) {
            map { "{'and ' if $_ == @things.end}@things[$_]" }, ^@things
        }
        my $disklist = @.covered_by > 1
            ?? join ', ', last_and map { "the $_" }, @.covered_by
            !! "the @.covered_by[0]";
        "Cannot move the $.disk: it is covered by $disklist"
    }
}

class X::Hanoi::ForbiddenDiskRemoval is X::Hanoi {
    has $.disk;

    method message {
        "Removing the $.disk is forbidden"
    }
}

class X::Hanoi::DiskHasBeenRemoved is X::Hanoi {
    has $.disk;
    has $.action;

    method message {
        "Cannot $.action the $.disk because it has been removed"
    }
}

class X::Hanoi::NoSuchDisk is X::Hanoi {
    has $.disk;
    has $.action;

    method message {
        "Cannot $.action a $.disk because there is no such disk"
    }
}

class X::Hanoi::DiskAlreadyOnARod is X::Hanoi {
    has $.disk;

    method message {
        "Cannot add the $.disk because it is already on a rod"
    }
}

class Game::Hanoi {
    my @disks = <tiny small medium large huge> X~ ' disk';
    my %size_of = @disks Z 1..5;

    has %!state =
        left   => [reverse @disks],
        middle => [],
        right  => [],
    ;

    has $!achievement = 'locked';

    class DiskMoved does Event {
        has $.disk;
        has $.source;
        has $.target;
    }

    class AchievementUnlocked does Event {
    }

    class AchievementLocked does Event {
    }

    class DiskRemoved does Event {
        has $.disk;
        has $.source;
    }

    class DiskAdded does Event {
        has $.disk;
        has $.target;
    }

    our sub print_hanoi_game(@all_events) {
        my %s =
            left   => [reverse @disks],
            middle => [],
            right  => [],
        ;
        for @all_events {
            when DiskMoved   { %s{.target}.push: %s{.source}.pop }
            when DiskRemoved { %s{.source}.pop }
            when DiskAdded   { %s{.target}.push: .disk }
        }

        my @rods = <left middle right>;
        say "";
        for reverse ^6 -> $line {
            my %disks =
                'none'        => '     |     ',
                'tiny disk'   => '     =     ',
                'small disk'  => '    ===    ',
                'medium disk' => '   =====   ',
                'large disk'  => '  =======  ',
                'huge disk'   => ' ========= ',
            ;

            sub disk($rod) {
                my $disk = %s{$rod}[$line] // 'none';
                %disks{ $disk };
            }

            say join '  ', map &disk, @rods;
        }
        say join '--', '-----------' xx @rods;
    }

    method move($source is copy, $target) {
        if $source eq any @disks {
            $source = self!rod_with_disk($source, 'move');
        }
        die X::Hanoi::NoSuchRod.new(:rod<source>, :name($source))
            unless %!state{$source}:exists;
        die X::Hanoi::NoSuchRod.new(:rod<target>, :name($target))
            unless %!state{$target}:exists;
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
        my @events
            = DiskMoved.new(:disk($moved_disk), :$source, :$target);
        if %!state<right> == @disks-1
           && $target eq 'right'
           && $!achievement eq 'locked' {
            @events.push(AchievementUnlocked.new);
        }
        if $moved_disk eq 'small disk' && $!achievement eq 'unlocked' {
            @events.push(AchievementLocked.new);
        }
        self!apply_and_return: @events;
    }

    method remove($disk) {
        die X::Hanoi::NoSuchDisk.new(:action<remove>, :$disk)
            unless $disk eq any(@disks);
        my $source = self!rod_with_disk($disk, 'remove');
        die X::Hanoi::ForbiddenDiskRemoval.new(:$disk)
            unless $disk eq 'tiny disk';
        my @events = DiskRemoved.new(:$disk, :$source);
        self!apply_and_return: @events;
    }

    method add($disk, $target) {
        die X::Hanoi::NoSuchDisk.new(:action<add>, :$disk)
            unless $disk eq any(@disks);
        die X::Hanoi::NoSuchRod.new(:rod<target>, :name($target))
            unless %!state{$target}:exists;
        die X::Hanoi::DiskAlreadyOnARod.new(:$disk)
            if grep { $disk eq any(@$_) }, %!state.values;
        my @events = DiskAdded.new(:$disk, :$target);
        if %!state<right> == @disks-1
           && $target eq 'right'
           && $!achievement eq 'locked' {
            @events.push(AchievementUnlocked.new);
        }
        self!apply_and_return: @events;
    }

    # The method will throw X::Hanoi::CoveredDisk if the disk is not topmost,
    # or X::Hanoi::DiskHasBeenRemoved if the disk isn't found on any rod.
    method !rod_with_disk($disk, $action) {
        for %!state -> (:key($rod), :value(@disks)) {
            if $disk eq any(@disks) {
                sub smaller_disks {
                    grep { %size_of{$_} < %size_of{$disk} }, @disks;
                }
                die X::Hanoi::CoveredDisk.new(:$disk, :covered_by(smaller_disks))
                    unless @disks[*-1] eq $disk;
                return $rod;
            }
        }
        die X::Hanoi::DiskHasBeenRemoved.new(:$disk, :$action);
    }

    method !apply_and_return(@events) {
        self!apply($_) for @events;
        return @events;
    }

    # RAKUDO: private multimethods NYI
    method !apply(Event $_) {
        when DiskMoved {
            my @source_rod := %!state{.source};
            my @target_rod := %!state{.target};
            @target_rod.push( @source_rod.pop );
        }
        when AchievementUnlocked {
            $!achievement = 'unlocked';
        }
        when AchievementLocked {
            $!achievement = 'locked';
        }
        when DiskRemoved {
            my @source_rod := %!state{.source};
            @source_rod.pop;
        }
        when DiskAdded {
            my @target_rod := %!state{.target};
            @target_rod.push(.disk);
        }
    }

    our sub CLI {
        my Game::Hanoi $game .= new;

        sub params($method) {
            $method.signature.params ==> grep { .positional && !.invocant } ==> map { .name.substr(1) }
        }
        my %commands = map { $^m.name => params($m) }, $game.^methods;
        my @all_events;

        print_hanoi_game(@all_events);
        say "";
        loop {
            my $command = prompt('> ');
            unless defined $command {
                say "";
                last;
            }
            given lc $command {
                when 'q' | 'quit' { last }
                when 'h' | 'help' {
                    say "Goal: get all the disks to the right rod.";
                    say "You can never place a larger disk on a smaller one.";
                    say "Available commands:";
                    for %commands.sort {
                        say "  {.key} {map { "<$_>" }, .value.list}";
                    }
                    say "  q[uit]";
                    say "  h[elp]";
                    say "  s[how]";
                    say "";
                    my @disks = <tiny small medium large huge> X~ ' disk';
                    my @rods = <left middle right>;
                    say "Disks: ", join ', ', @disks;
                    say "Rods: ", join ', ', @rods;
                }
                when 's' | 'show' { print_hanoi_game(@all_events) }

                sub munge   { $^s.subst(/' disk'»/, '_disk', :g) }
                sub unmunge { $^s.subst(/'_disk'»/, ' disk', :g) }
                my $verb = .&munge.words[0].&unmunge;
                my @args = .&munge.words[1..*]».&unmunge;
                when %commands{$verb}:exists {
                    my @req_args = %commands{$verb}.list;
                    when @args != @req_args {
                        say "You passed in {+@args} arguments, but $verb requires {+@req_args}.";
                        say "The arguments are {map { "<$_>" }, @req_args}.";
                        say "'help' for more help.";
                    }
                    my @events = $game."$verb"(|@args);
                    push @all_events, @events;
                    print_hanoi_game(@all_events);
                    for @events {
                        when AchievementUnlocked { say "Achievement unlocked!" }
                        when AchievementLocked { say "Achievement locked!" }
                    }
                    CATCH {
                        when X::Hanoi { say .message, '.' }
                    }
                }

                default {
                    say "Sorry, the game doesn't recognize that command. :/";
                    say "'help' if you're confused as well.";
                }
            }
            say "";
        }
    }
}
