use v6;
use Test;
use Adventure::Engine;

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
    my $engine = Adventure::Engine.new();

    my @rooms = <kitchen veranda>;
    is $engine.connect(@rooms, my $direction = 'south'),
        Adventure::TwoRoomsConnected.new(
            :@rooms,
            :$direction,
        ),
        'connecting two rooms (+)';
}

{
    my $engine = Adventure::Engine.new();

    my $direction = 'oops';
    throws_exception
        { $engine.connect(<boat lawn>, $direction) },
        X::Adventure::NoSuchDirection,
        'connecting two rooms (-) no such direction',
        {
            is .direction, $direction, '.direction attribute';
            is .message,
                "Cannot connect rooms because direction "
                    ~ "'$direction' does not exist",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    my @rooms = <first_floor second_floor>;
    is $engine.connect(@rooms, my $direction = 'up'),
        Adventure::TwoRoomsConnected.new(
            :@rooms,
            :$direction,
        ),
        'connecting two rooms vertically';
    $engine.place_player('first_floor');
    is $engine.walk('up')[0],
        Adventure::PlayerWalked.new(
            :to<second_floor>,
        ),
        'going up to the second floor';
}

{
    my $engine = Adventure::Engine.new();

    my @rooms = <outside inside>;
    is $engine.connect(@rooms, my $direction = 'southwest'),
        Adventure::TwoRoomsConnected.new(
            :@rooms,
            :$direction,
        ),
        'connecting outside and inside';
    is $engine.alias_direction('outside', 'in', 'southwest'),
        Adventure::DirectionAliased.new(
            :room<outside>,
            :direction<southwest>,
            :alias<in>,
        ),
        'aliasing "southwest" as "in"';
    is $engine.place_player('outside')[0],
        Adventure::PlayerWasPlaced.new(
            :in<outside>,
        ),
        'placing the player';
    is $engine.walk('in'),
        [
            Adventure::PlayerWalked.new(
                :to<inside>,
            ),
            Adventure::PlayerLooked.new(
                :room<inside>,
                :exits<northeast>,
            ),
        ],
        'going inside now means going southwest';
}

{
    my $engine = Adventure::Engine.new();

    my @rooms = <kitchen veranda>;
    $engine.connect(@rooms, my $direction = 'south');
    $engine.place_player('kitchen');
    $engine.walk('south');
    is $engine.walk('north'),
        Adventure::PlayerWalked.new(
            :to<kitchen>,
        ),
        'connecting two rooms creates a mutual connection';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('ball', 'street');
    $engine.place_player('street');
    is $engine.examine('ball'),
        Adventure::PlayerExamined.new(
            :thing<ball>,
        ),
        'examining an object (+)';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_player('street');
    throws_exception
        { $engine.examine('ball') },
        X::Adventure::NoSuchThingHere,
        'examining an object (-) no such object here',
        {
            is .thing, 'ball', '.thing attribute';
            is .message, "You see no ball here", '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('car', 'street');
    $engine.make_thing_openable('car');
    $engine.place_player('street');
    is $engine.open('car'),
        Adventure::PlayerOpened.new(
            :thing<car>,
        ),
        'opening an object (+)';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('ball', 'street');
    $engine.place_player('street');
    throws_exception
        { $engine.open('ball') },
        X::Adventure::ThingNotOpenable,
        'opening an object (-) it is not openable',
        {
            is .thing, 'ball', '.thing attribute';
            is .message, "You cannot open the ball", '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('car', 'street');
    $engine.make_thing_openable('car');
    $engine.place_player('street');
    $engine.open('car');
    throws_exception
        { $engine.open('car') },
        X::Adventure::ThingAlreadyOpen,
        'opening an object (-) it is already open',
        {
            is .thing, 'car', '.thing attribute';
            is .message, "The car is open", '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('box', 'street');
    $engine.make_thing_a_container('box');
    $engine.place_thing('doll', 'street');
    $engine.make_thing_carryable('doll');
    $engine.place_player('street');
    is $engine.put_thing_in('doll', 'box'),
        Adventure::PlayerPutIn.new(
            :thing<doll>,
            :in<box>,
        ),
        'putting a thing inside another (+)';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('brick', 'street');
    # don't make brick a container
    $engine.place_thing('doll', 'street');
    $engine.make_thing_carryable('doll');
    $engine.place_player('street');
    throws_exception
        { $engine.put_thing_in('doll', 'brick') },
        X::Adventure::CannotPutInNonContainer,
        'putting a thing inside another (-) it is not a container',
        {
            is .in, 'brick', '.in attribute';
            is .message,
                "You cannot put things in the brick",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('crate', 'street');
    $engine.make_thing_a_container('crate');
    $engine.make_thing_openable('crate');
    $engine.place_thing('doll', 'street');
    $engine.make_thing_carryable('doll');
    $engine.place_player('street');
    is $engine.put_thing_in('doll', 'crate'),
        [
            Adventure::PlayerOpened.new(
                :thing<crate>,
            ),
            Adventure::PlayerPutIn.new(
                :thing<doll>,
                :in<crate>,
            ),
        ],
        'putting a thing inside another (+) container was closed';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('box', 'street');
    $engine.make_thing_a_container('box');
    $engine.make_thing_carryable('box');
    $engine.place_player('street');
    throws_exception
        { $engine.put_thing_in('box', 'box') },
        X::Adventure::YoDawg,
        'putting a thing inside another (-) but it is the same thing',
        {
            is .relation, 'in', '.relation attribute';
            is .thing, 'box', '.thing attribute';
            is .message,
                "Yo dawg, I know you like a box so I put a box in your box",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('surface', 'street');
    $engine.make_thing_a_platform('surface');
    $engine.place_thing('doll', 'street');
    $engine.make_thing_carryable('doll');
    $engine.place_player('street');
    is $engine.put_thing_on('doll', 'surface'),
        Adventure::PlayerPutOn.new(
            :thing<doll>,
            :on<surface>,
        ),
        'putting a thing on another (+)';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('hole', 'street');
    # don't make hole a platform
    $engine.place_thing('doll', 'street');
    $engine.make_thing_carryable('doll');
    $engine.place_player('street');
    throws_exception
        { $engine.put_thing_on('doll', 'hole') },
        X::Adventure::CannotPutOnNonPlatform,
        'putting a thing on another (-) it is not a platform',
        {
            is .on, 'hole', '.on attribute';
            is .message,
                "You cannot put things on the hole",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('surface', 'street');
    $engine.make_thing_a_platform('surface');
    $engine.make_thing_carryable('surface');
    $engine.place_player('street');
    throws_exception
        { $engine.put_thing_on('surface', 'surface') },
        X::Adventure::YoDawg,
        'putting a thing on another (-) but it is the same thing',
        {
            is .relation, 'on', '.relation attribute';
            is .thing, 'surface', '.thing attribute';
            is .message,
                "Yo dawg, I know you like a surface so I put a surface on your surface",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('book', 'library');
    $engine.make_thing_readable('book');
    $engine.place_player('library');
    is $engine.read('book'),
        Adventure::PlayerRead.new(
            :thing<book>,
        ),
        'reading a thing (+)';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('ball', 'library');
    # don't make ball readable
    $engine.place_player('library');
    throws_exception
        { $engine.read('ball') },
        X::Adventure::ThingNotReadable,
        'reading a thing (-) it is not readable',
        {
            is .thing, 'ball', '.thing attribute';
            is .message,
                "There is nothing to read on the ball",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('flask', 'chamber');
    $engine.hide_thing('flask');
    $engine.place_player('chamber');
    throws_exception
        { $engine.examine('flask') },
        X::Adventure::NoSuchThingHere,
        'examining a hidden thing (-) cannot because it is hidden';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('flask', 'chamber');
    $engine.make_thing_openable('flask');
    $engine.hide_thing('flask');
    $engine.place_player('chamber');
    throws_exception
        { $engine.open('flask') },
        X::Adventure::NoSuchThingHere,
        'opening a hidden thing (-) cannot because it is hidden';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('flask', 'chamber');
    $engine.make_thing_openable('flask');
    $engine.place_player('bedroom');
    throws_exception
        { $engine.open('flask') },
        X::Adventure::NoSuchThingHere,
        'opening a thing (-) cannot because it is in another room';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('door', 'hill');
    $engine.place_thing('grass', 'hill');
    $engine.make_thing_openable('door');
    $engine.hide_thing('door');
    $engine.on_examine('grass', { $engine.unhide_thing('door') });
    $engine.place_player('hill');
    $engine.examine('grass');
    is $engine.open('door'),
        Adventure::PlayerOpened.new(
            :thing<door>,
        ),
        'opening a thing (+) unhidden by a callback';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('box', 'saloon');
    $engine.make_thing_carryable('box');
    $engine.place_player('saloon');
    is $engine.take('box'),
        Adventure::PlayerTook.new(
            :thing<box>,
        ),
        'taking a thing (+)';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('table', 'saloon');
    # don't make table carryable
    $engine.place_player('saloon');
    throws_exception
        { $engine.take('table') },
        X::Adventure::ThingNotCarryable,
        'taking a thing (-) it is not carryable',
        {
            is .action, 'take', '.action attribute';
            is .thing, 'table', '.thing attribute';
            is .message,
                "You cannot take the table",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('box', 'street');
    $engine.make_thing_a_container('box');
    $engine.place_thing('doll', 'street');
    # don't make doll carryable
    $engine.place_player('street');
    throws_exception
        { $engine.put_thing_in('doll', 'box') },
        X::Adventure::ThingNotCarryable,
        'putting a thing inside another (-) not carryable',
        {
            is .action, 'put', '.action attribute';
            is .thing, 'doll', '.thing attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('surface', 'street');
    $engine.make_thing_a_platform('surface');
    $engine.place_thing('doll', 'street');
    # don't make doll carryable
    $engine.place_player('street');
    throws_exception
        { $engine.put_thing_on('doll', 'surface') },
        X::Adventure::ThingNotCarryable,
        'putting a thing on another (-) not carryable',
        {
            is .action, 'put', '.action attribute';
            is .thing, 'doll', '.thing attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('cup', 'porch');
    $engine.make_thing_carryable('cup');
    $engine.place_player('porch');
    $engine.take('cup');
    throws_exception
        { $engine.take('cup') },
        X::Adventure::PlayerAlreadyCarries,
        'taking a thing (-) player already has',
        {
            is .thing, 'cup', '.thing attribute';
            is .message, "You already have the cup",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('cup', 'porch');
    $engine.make_thing_carryable('cup');
    $engine.place_player('porch');
    $engine.take('cup');
    is $engine.drop('cup'),
        Adventure::PlayerDropped.new(
            :thing<cup>,
        ),
        'dropping a thing (+)';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('cup', 'porch');
    $engine.make_thing_carryable('cup');
    $engine.place_player('porch');
    throws_exception
        { $engine.drop('cup') },
        X::Adventure::PlayerDoesNotHave,
        'dropping a thing (-) player does not have it',
        {
            is .thing, 'cup', '.thing attribute';
            is .message, "You are not carrying the cup",
                '.message attribute';
        };
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('box', 'saloon');
    $engine.make_thing_carryable('box');
    $engine.place_player('saloon');
    $engine.take('box');
    $engine.drop('box');
    is $engine.take('box'),
        Adventure::PlayerTook.new(
            :thing<box>,
        ),
        'taking a thing (+) take, drop, take';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('dog', 'street');
    $engine.place_player('street');
    is $engine.look(),
        Adventure::PlayerLooked.new(
            :room<street>,
            :things<dog>,
        ),
        'looking at the room, explicit thing';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('fog', 'street');
    $engine.make_thing_implicit('fog');
    $engine.place_player('street');
    is $engine.look(),
        Adventure::PlayerLooked.new(
            :room<street>,
        ),
        'looking at the room, implicit thing';
}

{
    my $engine = Adventure::Engine.new();

    $engine.finish();
    throws_exception
        { $engine.walk('west') },
        X::Adventure::GameOver,
        'cannot do things once the game has finished';
}

{
    my $engine = Adventure::Engine.new();

    my @rooms = <kitchen veranda>;
    $engine.connect(@rooms, my $direction = 'south');
    $engine.place_player('kitchen');
    $engine.light_fuse(3, 'end_game', { $engine.finish });
    $engine.walk('south');
    $engine.walk('north');
    is $engine.walk('south'),
        [
            Adventure::PlayerWalked.new(
                :to<veranda>,
            ),
            Adventure::GameFinished.new(
            ),
        ],
        'counting down to a hook auto-activating';
}

{
    my $engine = Adventure::Engine.new();

    my @rooms = <kitchen veranda>;
    $engine.connect(@rooms, my $direction = 'south');
    $engine.place_player('kitchen');
    $engine.light_fuse(3, 'end_game', { $engine.finish });
    $engine.walk('south');
    $engine.walk('north');
    $engine.put_out_fuse('end_game');
    is $engine.walk('south'),
        Adventure::PlayerWalked.new(
            :to<veranda>,
        ),
        'putting out a fuse so it does not activate';
}

{
    my $engine = Adventure::Engine.new();

    $engine.place_thing('box', 'saloon');
    $engine.make_thing_carryable('box');
    $engine.place_player('saloon');
    $engine.take('box');
    is $engine.examine('box'),
        Adventure::PlayerExamined.new(
            :thing<box>,
        ),
        'examining a thing (+) in inventory';
}

done;
