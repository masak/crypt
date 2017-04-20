use v6;
use Test;
use Game::Crypt;

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

sub game_from_chamber {
    my $game = Game::Crypt.new();

    $game.open('car');
    $game.take('flashlight');
    $game.walk('east');
    $game.take('leaves');
    $game.examine('bushes');
    $game.open('door');
    $game.walk('in');
    return $game;
}

sub game_from_hall {
    my $game = game_from_chamber();

    $game.put_thing_in('leaves', 'basket'),
    $game.walk('south');
    return $game;
}

sub game_after_hanoi_is_solved {
    my $game = game_from_hall();

    multi hanoi_moves($source, $, $target, 1) { { :$source, :$target }.item }
    multi hanoi_moves($source, $helper, $target, $n) {
        flat
            hanoi_moves($source, $target, $helper, $n-1),
            hanoi_moves($source, $helper, $target, 1),
            hanoi_moves($helper, $source, $target, $n-1);
    }

    $game.use('flashlight');
    $game.move(.<source>, .<target>)
        for hanoi_moves('left', 'middle', 'right', 5);
    return $game;
}

sub game_after_putting_out_the_fire {
    my $game = game_after_hanoi_is_solved();

    $game.take('helmet');
    $game.walk('north');
    $game.walk('north');
    $game.put_thing_in('water', 'helmet');
    $game.walk('south');
    $game.walk('south');
    $game.walk('down');
    $game.put_thing_in('water', 'fire');
    return $game;
}

sub game_from_crypt {
    my $game = game_after_putting_out_the_fire();

    $game.walk('northwest');
    return $game;
}

{
    my $game = Game::Crypt.new();

    is $game.look(),
        Adventure::PlayerLooked.new(
            :room<clearing>,
            :exits<east>,
            :things<car>,
        ),
        'looking at the room';
}

{
    my $game = Game::Crypt.new();

    is $game.walk('east'),
        [
            Adventure::PlayerWalked.new(
                :to<hill>,
            ),
            Adventure::PlayerLooked.new(
                :room<hill>,
                :exits<west>,
                :things<brook>,
            ),
        ],
        'walking (+)';
}

{
    my $game = Game::Crypt.new();

    throws_exception
        { $game.walk('south') },
        X::Adventure::NoExitThere,
        'walking (-) in a direction without an exit',
        {
            is .direction, 'south', '.direction attribute';
            is .message,
                "Cannot walk south because there is no exit there",
                '.message attribute';
        };
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    throws_exception
        { $game.walk('east') },
        X::Adventure::NoExitThere,
        'the player actually moves to the next room';
}

{
    my $game = Game::Crypt.new();

    is $game.open('car'),
        [
            Adventure::PlayerOpened.new(
                :thing<car>,
            ),
            Adventure::ContentsRevealed.new(
                :container<car>,
                :contents<flashlight rope>,
            ),
        ],
        'opening the car';
}

{
    my $game = Game::Crypt.new();

    $game.open('car');
    is $game.look(),
        Adventure::PlayerLooked.new(
            :room<clearing>,
            :exits<east>,
            :things(car => <flashlight rope>),
        ),
        'looking inside the car';
}

{
    my $game = Game::Crypt.new();

    $game.open('car');
    is $game.take('flashlight'),
        Adventure::PlayerTook.new(
            :thing<flashlight>,
        ),
        'taking the flashlight from the car (+)';
}

{
    my $game = Game::Crypt.new();

    $game.open('car');
    is $game.take('rope'),
        Adventure::PlayerTook.new(
            :thing<rope>,
        ),
        'taking the rope from the car (+)';
}

{
    my $game = Game::Crypt.new();

    throws_exception
        { $game.take('flashlight') },
        X::Adventure::NoSuchThingHere,
        'taking the flashlight from the car (-) car not open';
}

{
    my $game = Game::Crypt.new();

    $game.open('car');
    is $game.examine('flashlight'),
        Adventure::PlayerExamined.new(
            :thing<flashlight>,
        ),
        'examining the flashlight in the car';
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    $game.examine('grass');
    is $game.open('door')[0],
        Adventure::PlayerOpened.new(
            :thing<door>,
        ),
        'opening the door (+) having examined the grass';
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    throws_exception
        { $game.open('door') },
        X::Adventure::NoSuchThingHere,
        'opening the door (-) without examining the grass';
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    $game.examine('bushes');
    is $game.open('door')[0],
        Adventure::PlayerOpened.new(
            :thing<door>,
        ),
        'opening the door (+) bushes work too';
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    $game.examine('bushes');
    $game.open('door');
    is $game.walk('in'),
        [
            Adventure::PlayerWalked.new(
                :to<chamber>,
            ),
            Adventure::PlayerLooked.new(
                :room<chamber>,
                :exits<north>,
                :things<basket sign>,
            ),
        ],
        'walking into the hill (+) after opening the door';
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    is $game.take('leaves'),
        Adventure::PlayerTook.new(
            :thing<leaves>,
        ),
        'taking the leaves';
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    $game.take('leaves');
    $game.walk('west');
    is $game.put_thing_in('leaves', 'car'),
        [
            Adventure::PlayerOpened.new(
                :thing<car>,
            ),
            Adventure::PlayerPutIn.new(
                :thing<leaves>,
                :in<car>,
            ),
            Adventure::GameRemarked.new(
                :remark<car-full-of-leaves>,
            ),
        ],
        'putting the leaves in the car';
}

{
    my $game = game_from_chamber();

    is $game.put_thing_in('leaves', 'basket'),
        [
            Adventure::PlayerPutIn.new(
                :thing<leaves>,
                :in<basket>,
            ),
            Adventure::TwoRoomsConnected.new(
                :rooms<chamber hall>,
                :direction<south>,
            ),
            Adventure::GameRemarked.new(
                :remark<passageway-opens-up>,
            ),
        ],
        'putting the leaves in the basket';
}

{
    my $game = game_from_chamber();

    is $game.read('sign'),
        Adventure::PlayerRead.new(
            :thing<sign>,
        ),
        'reading the sign';
}

{
    my $game = game_from_hall();

    is $game.look(),
        Adventure::PlayerLookedAtDarkness.new(
        ),
        'looking without the flashlight switched on';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    is $game.look(),
        Adventure::PlayerLooked.new(
            :room<hall>,
            :exits<north>,
            :things<helmet>,
        ),
        'looking with the flashlight switched on';
}

{
    my $game = game_from_chamber();

    throws_exception
        { $game.move('left', 'middle') },
        X::Crypt::NoDisksHere,
        'moving disks in the right room (-)';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    is $game.move('left', 'middle'),
        Game::Hanoi::DiskMoved.new(
            :disk('tiny disk'),
            :source<left>,
            :target<middle>,
        ),
        'moving disks in the right room (+)';
}

{
    my $game = game_after_hanoi_is_solved();

    is $game.walk('down')[0],
        Adventure::PlayerWalked.new(
            :to<cave>,
        ),
        'can walk down after solving the hanoi game (+)';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    is $game.take('helmet'),
        Adventure::PlayerTook.new(
            :thing<helmet>,
        ),
        'taking the helmet (+)';
}

{
    my $game = game_from_hall();

    throws_exception
        { $game.take('helmet') },
        X::Adventure::PitchBlack,
        'taking the helmet (-) pitch black',
        {
            is .action, 'take', '.action attribute';
            is .message,
                "You cannot take anything, because it is pitch black",
                '.message attribute';
        };
}

{
    my $game = game_from_hall();

    throws_exception
        { $game.examine('helmet') },
        X::Adventure::PitchBlack,
        'examining the helmet (-) pitch black',
        {
            is .action, 'see', '.action attribute';
            is .message,
                "You cannot see anything, because it is pitch black",
                '.message attribute';
        };
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    $game.take('helmet');
    $game.walk('north');
    $game.walk('north');
    is $game.put_thing_in('water', 'helmet'),
        Adventure::PlayerPutIn.new(
            :thing<water>,
            :in<helmet>,
        ),
        'filling the helmet with water';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    $game.take('helmet');
    $game.walk('north');
    $game.walk('north');
    $game.put_thing_in('helmet', 'brook');
    is $game.take('helmet'),
        [
            Adventure::PlayerTook.new(
                :thing<helmet>,
            ),
            Adventure::ThingPlaced.new(
                :thing<water>,
                :room<contents:helmet>,
            ),
        ],
        'picking helmet up from brook fills it with water';
}

{
    my $game = Game::Crypt.new();

    $game.walk('east');
    is $game.take('water'),
        [
            Adventure::PlayerTook.new(
                :thing<water>,
            ),
            Adventure::GameRemarked.new(
                :remark<bare-hands-carry-water>,
            ),
            Adventure::PlayerDropped.new(
                :thing<water>,
            ),
        ],
        'picking up water with your bare hands fails';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    $game.take('helmet');
    $game.walk('north');
    $game.walk('north');
    $game.put_thing_in('water', 'helmet');
    $game.walk('west');
    is $game.put_thing_in('water', 'car'),
        [
            Adventure::PlayerPutIn.new(
                :thing<water>,
                :in<car>,
            ),
            Adventure::GameRemarked.new(
                :remark<car-is-now-wet>,
            ),
            Adventure::ThingPlaced.new(
                :thing<water>,
                :room<hill>,
            ),
        ],
        'putting water into the car';
}

{
    my $game = game_after_hanoi_is_solved();

    $game.take('helmet');
    $game.walk('north');
    $game.walk('north');
    $game.put_thing_in('water', 'helmet');
    $game.walk('south');
    $game.walk('south');
    $game.walk('down');
    is $game.put_thing_in('water', 'fire'),
        [
            Adventure::PlayerPutIn.new(
                :thing<water>,
                :in<fire>,
            ),
            Adventure::GameRemarked.new(
                :remark<fire-dies>,
            ),
            Adventure::ThingHidden.new(
                :thing<fire>,
            ),
        ],
        'putting out the fire with water';
}

{
    my $game = game_after_putting_out_the_fire();

    is $game.walk('northwest')[0],
        Adventure::PlayerWalked.new(
            :to<crypt>,
        ),
        'after water is gone, can walk into crypt';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    $game.take('helmet');
    $game.walk('north');
    $game.walk('north');
    $game.put_thing_in('water', 'helmet');
    is $game.drop('water'),
        Adventure::PlayerDropped.new(
            :thing<water>,
        ),
        'dropping water in the helmet';
}

{
    my $game = game_from_crypt();

    is $game.take('butterfly'),
        [
            Adventure::PlayerTook.new(
                :thing<butterfly>,
            ),
            Adventure::GameRemarked.new(
                :remark<alarm-starts>,
            ),
        ],
        'taking the butterfly triggers an alarm';
}

{
    my $game = game_from_crypt();

    $game.take('butterfly');
    $game.walk('southeast');
    $game.walk('up');
    is $game.walk('north'),
        [
            Adventure::PlayerWalked.new(
                :to<chamber>,
            ),
            Adventure::GameRemarked.new(
                :remark<cavern-collapses>,
            ),
            Adventure::GameFinished.new(
            ),
        ],
        'not getting out in time before the cavern collapses';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    is $game.take('tiny disk'),
        [
            Adventure::PlayerTook.new(
                :thing('tiny disk'),
            ),
            Game::Hanoi::DiskRemoved.new(
                :disk('tiny disk'),
                :source<left>,
            ),
        ],
        'can take the tiny disk from the hanoi game';
}

{
    my $game = game_after_putting_out_the_fire();

    $game.walk('up');
    $game.take('tiny disk');
    $game.walk('down');
    $game.walk('northwest');
    $game.take('butterfly');
    $game.put_thing_on('tiny disk', 'pedestal');
    $game.walk('southeast');
    $game.walk('up');
    $game.walk('north');
    is $game.walk('north'),
        [
            Adventure::GameRemarked.new(
                :remark<made-it-out-with-treasure>,
            ),
            Adventure::GameFinished.new(
            ),
        ],
        'making it out alive with the treasure';
}

{
    my $game = Game::Crypt.new();

    is $game.walk('e'),
        [
            Adventure::PlayerWalked.new(
                :to<hill>,
            ),
            Adventure::PlayerLooked.new(
                :room<hill>,
                :exits<west>,
                :things<brook>,
            ),
        ],
        'walking (+) abbreviated directions';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    $game.take('tiny disk');
    is $game.put_thing_on('tiny disk', 'middle rod'),
        [
            Adventure::PlayerPutOn.new(
                :thing('tiny disk'),
                :on('middle rod'),
            ),
            Game::Hanoi::DiskAdded.new(
                :disk('tiny disk'),
                :target<middle>,
            ),
        ],
        'can put tiny disk back after taking it';
}

{
    my $game = game_after_hanoi_is_solved();

    $game.take('tiny disk');
    $game.move('right', 'middle');
    $game.move('middle', 'right');
    is $game.put_thing_on('tiny disk', 'right rod'),
        [
            Adventure::PlayerPutOn.new(
                :thing('tiny disk'),
                :on('right rod'),
            ),
            Game::Hanoi::DiskAdded.new(
                :disk('tiny disk'),
                :target('right'),
            ),
            Game::Hanoi::AchievementUnlocked.new(
            ),
            Adventure::GameRemarked.new(
                :remark<floor-reveals-hole>,
            ),
            Adventure::TwoRoomsConnected.new(
                :rooms<hall cave>,
                :direction<down>,
            ),
        ],
        'can unlock the game by putting the tiny rod back';
}

{
    my $game = game_from_hall();

    $game.use('flashlight');
    $game.take('tiny disk');
    $game.put_thing_on('tiny disk', 'right rod');
    is $game.take('tiny disk'),
        [
            Adventure::PlayerTook.new(
                :thing('tiny disk'),
            ),
            Game::Hanoi::DiskRemoved.new(
                :disk<tiny disk>,
                :source<right>,
            ),
        ],
        'can take the tiny disk, put it back, and take it again';
}

done;
