use v6;
use Test;
use Hanoi::Game;

sub throws_exception(&code, $ex_type, $message, &followup = {;}) {
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

{
    my $game = Hanoi::Game.new();

    is $game.move('left', 'middle'),
       Hanoi::DiskMoved.new(
            :disk('tiny disk'),
            :source<left>,
            :target<middle>
       ),
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
            Hanoi::DiskMoved.new(:disk('tiny disk'), :$source, :$target),
            Hanoi::AchievementUnlocked.new(),
        ), 'putting all disks on the right rod unlocks achievement';

        $game.move($target, $source);
        is $game.move($source, $target), (
            Hanoi::DiskMoved.new(:disk('tiny disk'), :$source, :$target),
        ), 'moving things back and forth does not unlock achievement again';
    }

    {
        $game.move('right', 'middle');
        is $game.move(my $source = 'right', my $target = 'left'), (
            Hanoi::DiskMoved.new(:disk('small disk'), :$source, :$target),
            Hanoi::AchievementLocked.new(),
        ), 'removing two disks from the right rod locks achievement';
    }

    {
        $game.move('left', 'right');
        $game.remove('tiny disk');
        is $game.add(my $disk = 'tiny disk', my $target = 'right'), (
            Hanoi::DiskAdded.new(:$disk, :$target),
            Hanoi::AchievementUnlocked.new(),
        ), 'you can also unlock achievement by adding the disk';
    }
}

{
    my $game = Hanoi::Game.new();

    is $game.move('tiny disk', my $target = 'middle'),
       Hanoi::DiskMoved.new(:disk('tiny disk'), :source<left>, :$target),
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
       Hanoi::DiskRemoved.new(:disk('tiny disk'), :source<left>),
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

    throws_exception
        { $game.add('tiny disk', 'pineapple') },
        X::Hanoi::NoSuchRod,
        'moving a disk (-) the rod does not exist',
        {
            is .rod, 'target', '.rod attribute';
            is .name, 'pineapple', '.name attribute';
        };

    is $game.add('tiny disk', 'left'),
       Hanoi::DiskAdded.new(:disk('tiny disk'), :target<left>),
       'adding a disk (+)';

    throws_exception
        { $game.add('humongous disk', 'middle') },
        X::Hanoi::NoSuchDisk,
        'adding a disk (-) there is no such disk',
        {
            is .action, 'add', '.action attribute';
            is .disk, 'humongous disk', '.disk attribute';
            is .message,
                'Cannot add a humongous disk because there is no such disk',
                '.message attribute';
        };

    throws_exception
        { $game.add('tiny disk', 'right') },
        X::Hanoi::DiskAlreadyOnARod,
        'adding a disk (-) the disk is already on a rod',
        {
            is .disk, 'tiny disk', '.disk attribute';
            is .message,
                'Cannot add the tiny disk because it is already on a rod',
                '.message attribute';
        };
}

{
    my $game = Hanoi::Game.new();

    throws_exception
        { $game.remove('masakian disk') },
        X::Hanoi::NoSuchDisk,
        'removing a disk (-) the disk does not exist',
        {
            is .action, 'remove', '.action attribute';
            is .disk, 'masakian disk', '.disk attribute';
            is .message,
               'Cannot remove a masakian disk because there is no such disk',
               '.message attribute';
        };

}

done;
