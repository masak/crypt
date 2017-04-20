use Adventure::Engine;
use Game::Hanoi;

class X::Crypt is Exception {
}

class X::Crypt::NoDisksHere is X::Crypt {
}

class Game::Crypt {
    has $!engine;
    has $!hanoi;
    has $!player_location;

    submethod BUILD() {
        $!engine = Adventure::Engine.new();

        given $!engine {
            # Rooms
            .connect: <clearing hill>, 'east';
            .alias_direction: 'hill', 'in', 'south';
            .alias_direction: 'chamber', 'out', 'north';
            .on_try_exit: 'chamber', 'north', {
                if .thing_is_in('butterfly', 'player inventory') {
                    .remark('made-it-out-with-treasure'),
                    .finish(),
                    False;
                }
                else {
                    True;
                }
            };
            .alias_direction: 'chamber', 'in', 'south';
            .alias_direction: 'hall', 'out', 'north';
            .connect: <cave crypt>, 'northwest';
            .on_try_exit: 'cave', 'northwest', {
                if .thing_is_in('fire', 'cave') {
                    .remark('walk-past-fire-too-hot'),
                    False;
                }
                else {
                    True;
                }
            };
            .make_room_dark: 'hall';
            .make_room_dark: 'cave';
            .make_room_dark: 'crypt';

            # Things in clearing
            .place_thing: 'car', 'clearing';
            .place_thing: 'flashlight', 'contents:car';
            .make_thing_carryable: 'flashlight';
            .make_thing_a_light_source: 'flashlight';
            .place_thing: 'rope', 'contents:car';
            .make_thing_carryable: 'rope';
            .make_thing_openable: 'car';
            .make_thing_a_container: 'car';
            .on_put:
                'car',
                -> $_ {
                    when 'leaves' { $!engine.remark: 'car-full-of-leaves' }
                    when 'water' {
                        $!engine.remark('car-is-now-wet'),
                        $!engine.place_thing('water', 'hill');
                    }
                };

            # Things on hill
            .place_thing: 'grass', 'hill';
            .make_thing_implicit: 'grass';
            .place_thing: 'bushes', 'hill';
            .make_thing_implicit: 'bushes';
            .place_thing: 'door', 'hill';
            .make_thing_openable: 'door';
            .hide_thing: 'door';
            .on_examine: 'grass',
                { .unhide_thing('door'), .remark('door-under-grass') };
            .on_examine: 'bushes',
                { .unhide_thing('door'), .remark('door-under-grass') };
            .on_open: 'door', { .connect(<hill chamber>, 'south') };
            .place_thing: 'trees', 'hill';
            .make_thing_implicit: 'trees';
            .place_thing: 'leaves', 'hill';
            .make_thing_implicit: 'leaves';
            .make_thing_carryable: 'leaves';
            .place_thing: 'brook', 'hill';
            .make_thing_a_container: 'brook';
            .on_remove_from: 'brook',
                -> $_ {
                    when 'helmet' {
                        $!engine.place_thing('water', 'contents:helmet');
                    }
                };
            .place_thing: 'water', 'hill';
            .on_take: 'water',
                {
                    $!engine.remark('bare-hands-carry-water'),
                    $!engine.drop('water');
                };
            .make_thing_implicit: 'water';
            .make_thing_carryable: 'water';

            # Things in chamber
            .place_thing: 'basket', 'chamber';
            .make_thing_a_container: 'basket';
            .place_thing: 'sign', 'chamber';
            .make_thing_readable: 'sign';
            .on_put:
                'basket',
                -> $_ {
                    when 'leaves' {
                        $!engine.connect(<chamber hall>, 'south'),
                        $!engine.remark('passageway-opens-up');
                    }
                };

            # Things in hall
            .place_thing: 'helmet', 'hall';
            .make_thing_carryable: 'helmet';
            .make_thing_a_container: 'helmet';
            .place_thing: 'hanoi', 'hall';
            .make_thing_implicit: 'hanoi';
            .make_thing_a_container: 'hanoi';
            for <left middle right> X~ ' rod' -> $rod {
                .place_thing: $rod, 'contents:hanoi';
                .make_thing_a_platform: $rod;
                .on_put: $rod,
                    -> $_ {
                        when 'tiny disk' {
                            my @events = $!hanoi.add: $_, $rod.words[0];
                            for @events {
                                when Game::Hanoi::AchievementUnlocked {
                                    push @events,
                                        $!engine.remark('floor-reveals-hole'),
                                        $!engine.connect(<hall cave>, 'down');
                                }
                            }
                            @events;
                        }
                    };
            }
            for <tiny small medium large huge> X~ ' disk' -> $disk {
                .place_thing: $disk, 'contents:left rod';
            }
            .make_thing_carryable: 'tiny disk';
            .on_take: 'tiny disk', { $!hanoi.remove: 'tiny disk' };

            # Things in cave
            .place_thing: 'fire', 'cave';
            .make_thing_a_container: 'fire';
            .on_put:
                'fire',
                -> $_ {
                    when 'water' {
                        $!engine.remark('fire-dies'),
                        $!engine.hide_thing('fire');
                    }
                };

            # Things in crypt
            .place_thing: 'pedestal', 'crypt';
            .make_thing_a_platform: 'pedestal';
            .on_put:
                'pedestal',
                -> $_ {
                    when 'butterfly' | 'tiny disk' {
                        # XXX: Need to change signature of .put_out_fuse to
                        # accept a closure, to be run if there was a fuse to
                        # put out.
                        $!engine.put_out_fuse('cavern-collapse'),
                        $!engine.remark('alarm-stops');
                    }
                };
            .on_remove_from:
                'pedestal',
                -> $_ {
                    when 'butterfly' | 'tiny disk' {
                        # XXX: Should be 3, will fix when getting sagas
                        $!engine.light_fuse(4, 'cavern-collapse', {
                            $!engine.remark('cavern-collapses'),
                            $!engine.finish();
                        }),
                        $!engine.remark('alarm-starts');
                    }
                };
            .place_thing: 'butterfly', 'contents:pedestal';
            .make_thing_carryable: 'butterfly';

            .place_player: $!player_location = 'clearing';
        }

        $!hanoi = Game::Hanoi.new();
    }

    method look {
        return $!engine.look;
    }

    method !update_local_state(@events) {
        for @events {
            when Adventure::PlayerWalked { $!player_location = .to }
            when Adventure::PlayerWasPlaced { $!player_location = .in }
        }
    }

    method walk($direction) {
        my @events = $!engine.walk($direction);
        self!update_local_state(@events);
        @events;
    }

    method open($thing) {
        return $!engine.open($thing);
    }

    method examine($thing) {
        return $!engine.examine($thing);
    }

    method inventory() {
        return $!engine.inventory();
    }

    method take($thing) {
        return $!engine.take($thing);
    }

    method drop($thing) {
        return $!engine.drop($thing);
    }

    method put_thing_in($thing, $in) {
        return $!engine.put_thing_in($thing, $in);
    }

    method put_thing_on($thing, $on) {
        return $!engine.put_thing_on($thing, $on);
    }

    method read($thing) {
        return $!engine.read($thing);
    }

    method use($thing) {
        return $!engine.use($thing);
    }

    method move($source, $target) {
        die X::Crypt::NoDisksHere.new
            unless $!player_location eq 'hall';

        my @events = $!hanoi.move($source, $target);
        for @events {
            when Game::Hanoi::AchievementUnlocked {
                @events.append:
                    $!engine.remark('floor-reveals-hole'),
                    $!engine.connect(<hall cave>, 'down');
            }
            when Game::Hanoi::AchievementLocked {
                @events.append:
                    $!engine.remark('floor-hides-hole'),
                    $!engine.disconnect(<hall cave>, 'down');
            }
        }
        return @events;
    }

    method save {
        $!engine.save;
    }

    method restore($save) {
        $!engine .= restore($save);
        return;
    }
}
