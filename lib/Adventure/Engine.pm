use Event;

class Adventure::PlayerWalked does Event {
    has $.to;
}

class Adventure::PlayerWasPlaced does Event {
    has $.in;
}

class Adventure::PlayerLooked does Event {
    has $.room;
    has @.exits;
    has @.things;
}

class Adventure::TwoRoomsConnected does Event {
    has @.rooms;
    has $.direction;
}

class Adventure::TwoRoomsDisconnected does Event {
    has @.rooms;
    has $.direction;
}

class Adventure::DirectionAliased does Event {
    has $.room;
    has $.direction;
    has $.alias;
}

class Adventure::PlayerExamined does Event {
    has $.thing;
}

class Adventure::ThingPlaced does Event {
    has $.thing;
    has $.room;
}

class Adventure::PlayerOpened does Event {
    has $.thing;
}

class Adventure::PlayerPutIn does Event {
    has $.thing;
    has $.in;
}

class Adventure::ThingMadeAContainer does Event {
    has $.thing;
}

class Adventure::PlayerPutOn does Event {
    has $.thing;
    has $.on;
}

class Adventure::ThingMadeAPlatform does Event {
    has $.thing;
}

class Adventure::PlayerRead does Event {
    has $.thing;
}

class Adventure::ThingMadeReadable does Event {
    has $.thing;
}

class Adventure::ThingHidden does Event {
    has $.thing;
}

class Adventure::ThingUnhidden does Event {
    has $.thing;
}

class Adventure::PlayerTook does Event {
    has $.thing;
}

class Adventure::ThingMadeCarryable does Event {
    has $.thing;
}

class Adventure::PlayerDropped does Event {
    has $.thing;
}

class Adventure::ThingMadeImplicit does Event {
    has $.thing;
}

class Adventure::ContentsRevealed does Event {
    has $.container;
    has @.contents;
}

class Adventure::GameRemarked does Event {
    has $.remark;
}

class Adventure::PlayerLookedAtDarkness does Event {
}

class Adventure::RoomMadeDark does Event {
    has $.room;
}

class Adventure::PlayerUsed does Event {
    has $.thing;
}

class Adventure::ThingMadeALightSource does Event {
    has $.thing;
}

class Adventure::LightSourceSwitchedOn does Event {
    has $.thing;
}

class Adventure::GameFinished does Event {
}

class Adventure::PlayerCheckedInventory does Event {
    has @.things;
}

class X::Adventure is Exception {
}

class X::Adventure::NoSuchDirection is X::Adventure {
    has $.action;
    has $.direction;

    method message {
        "Cannot $.action because direction '$.direction' does not exist"
    }
}

class X::Adventure::NoExitThere is X::Adventure {
    has $.direction;

    method message {
        "Cannot walk $.direction because there is no exit there"
    }
}

class X::Adventure::PlayerNowhere is X::Adventure {
    method message {
        "Cannot move because the player isn't anywhere"
    }
}

class X::Adventure::NoSuchThingHere is X::Adventure {
    has $.thing;

    method message {
        "You see no $.thing here"
    }
}

class X::Adventure::ThingNotOpenable is X::Adventure {
    has $.thing;

    method message {
        "You cannot open the $.thing"
    }
}

class X::Adventure::ThingAlreadyOpen is X::Adventure {
    has $.thing;

    method message {
        "The $.thing is open"
    }
}

class X::Adventure::CannotPutInNonContainer is X::Adventure {
    has $.in;

    method message {
        "You cannot put things in the $.in"
    }
}

class X::Adventure::YoDawg is X::Adventure {
    has $.relation;
    has $.thing;

    method message {
        "Yo dawg, I know you like a $.thing so I put a $.thing $.relation your $.thing"
    }
}

class X::Adventure::CannotPutOnNonPlatform is X::Adventure {
    has $.on;

    method message {
        "You cannot put things on the $.on"
    }
}

class X::Adventure::ThingNotReadable is X::Adventure {
    has $.thing;

    method message {
        "There is nothing to read on the $.thing"
    }
}

class X::Adventure::ThingNotCarryable is X::Adventure {
    has $.action;
    has $.thing;

    method message {
        "You cannot $.action the $.thing"
    }
}

class X::Adventure::PlayerAlreadyCarries is X::Adventure {
    has $.thing;

    method message {
        "You already have the $.thing"
    }
}

class X::Adventure::PlayerDoesNotHave is X::Adventure {
    has $.thing;

    method message {
        "You are not carrying the $.thing"
    }
}

class X::Adventure::PitchBlack is X::Adventure {
    has $.action;

    method message {
        "You cannot $.action anything, because it is pitch black"
    }
}

class X::Adventure::GameOver is X::Adventure {
    method message {
        "The game has already ended"
    }
}

class Adventure::Engine {
    my @possible_directions = <
        north south east west
        northeast northwest southeast southwest
        up down
    >;

    has @!events;
    has $!player_location;
    has %!exits;
    has %!exit_aliases;
    has %!seen_room;
    has %!try_exit_hooks;
    has %!thing_rooms;
    has %!openable_things;
    has %!open_things;
    has %!containers;
    has %!platforms;
    has %!readable_things;
    has %!hidden_things;
    has %!examine_hooks;
    has %!carryable_things;
    has %!implicit_things;
    has %!open_hooks;
    has %!put_hooks;
    has %!dark_rooms;
    has %!light_sources;
    has %!things_shining;
    has %!remove_from_hooks;
    has %!take_hooks;
    has $!game_finished;
    has %!tick_hooks;

    method connect(@rooms, $direction) {
        die X::Adventure::NoSuchDirection.new(:action('connect rooms'), :$direction)
            unless $direction eq any(@possible_directions);

        my @events = Adventure::TwoRoomsConnected.new(:@rooms, :$direction);
        self!apply_and_return: @events;
    }

    method disconnect(@rooms, $direction) {
        die X::Adventure::NoSuchDirection.new(:action('disconnect rooms'), :$direction)
            unless $direction eq any(@possible_directions);

        my @events = Adventure::TwoRoomsDisconnected.new(:@rooms, :$direction);
        self!apply_and_return: @events;
    }

    method !contents_of($thing) {
        return %!thing_rooms.grep({.value eq "contents:$thing"})>>.key;
    }

    method !explicit_things_at($location) {
        sub here_visible_and_explicit($_) {
            %!thing_rooms{$_} eq $location
                && !%!hidden_things{$_}
                && ($location ~~ /^contents':'/ || !%!implicit_things{$_})
        }

        return unless $location;
        return gather for %!thing_rooms.keys -> $thing {
            next unless here_visible_and_explicit($thing);
            if (!%!openable_things{$thing} || %!open_things{$thing})
                && self!contents_of($thing) {
                take $thing => self!explicit_things_at("contents:$thing");
            }
            else {
                take $thing;
            }
        }
    }

    method thing_is_in($sought, $location) {
        return unless $location;
        return False
            if %!hidden_things{$sought};
        for %!thing_rooms.keys -> $thing {
            next unless %!thing_rooms{$thing} eq $location;
            return True
                if $thing eq $sought;
            return True
                if %!containers{$thing}
                && (!%!openable_things{$thing} || %!open_things{$thing})
                && self.thing_is_in($sought, "contents:$thing");
            return True
                if %!platforms{$thing}
                && self.thing_is_in($sought, "contents:$thing");
        }
        return False;
    }

    method thing_in_room_or_inventory($thing, $room) {
        self.thing_is_in($thing, $room)
        || self.thing_is_in($thing, 'player inventory');
    }

    method !shining_thing_here($room) {
        for %!things_shining.kv -> $thing, $shining {
            next unless $shining;
            return True if self.thing_in_room_or_inventory($thing, $room);
        }
        return False;
    }

    method !tick() {
        my @events;
        for %!tick_hooks.kv -> $name, %props {
            if --%props<ticks> == 0 {
                @events.push(%props<hook>());
            }
        }
        return @events;
    }

    my %abbr_directions = <
        n  north
        s  south
        e  east
        w  west
        ne northeast
        nw northwest
        se southeast
        sw southwest
        u  up
        d  down
    >;

    method walk($direction) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        my $actual_direction =
            %!exit_aliases{$!player_location}{$direction}
            // %abbr_directions{$direction}
            // $direction;

        die X::Adventure::NoSuchDirection.new(:action('walk that way'), :$direction)
            unless $actual_direction eq any(@possible_directions);

        my $to = %!exits{$!player_location}{$actual_direction};

        die X::Adventure::NoExitThere.new(:$direction)
            unless defined $to;

        my @events;
        my $walk = True;
        if %!try_exit_hooks{$!player_location}{$actual_direction} -> &hook {
            @events.push(&hook());
            $walk = @events.pop;
        }

        if $walk {
            @events.push(Adventure::PlayerWalked.new(:$to));
            unless %!seen_room{$to}++ {
                my $pitch_black = %!dark_rooms{$to}
                    && !self!shining_thing_here($to);

                if $pitch_black {
                    @events.push(Adventure::PlayerLookedAtDarkness.new());
                }
                else {
                    @events.push(Adventure::PlayerLooked.new(
                        :room($to),
                        :exits((%!exits{$to} // ()).keys),
                        :things(self!explicit_things_at($to)),
                    ));
                }
            }
            @events.push(self!tick);
        }
        self!apply_and_return: @events;
    }

    method look() {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        my $pitch_black = %!dark_rooms{$!player_location}
            && !self!shining_thing_here($!player_location);

        my @events = $pitch_black
            ?? Adventure::PlayerLookedAtDarkness.new()
            !! Adventure::PlayerLooked.new(
                   :room($!player_location),
                   :exits((%!exits{$!player_location} // ()).keys),
                   :things(self!explicit_things_at($!player_location)),
               );
        self!apply_and_return: @events;
    }

    method place_player($in) {
        my @events = Adventure::PlayerWasPlaced.new(:$in);
        unless %!seen_room{$in}++ {
            @events.push(Adventure::PlayerLooked.new(
                :room($in),
                :exits((%!exits{$in} // ()).keys),
                :things(self!explicit_things_at($in)),
            ));
        }
        self!apply_and_return: @events;
    }

    method alias_direction($room, $alias, $direction) {
        my @events = Adventure::DirectionAliased.new(
            :$room, :$alias, :$direction
        );
        self!apply_and_return: @events;
    }

    method place_thing($thing, $room) {
        my @events = Adventure::ThingPlaced.new(
            :$thing, :$room
        );
        self!apply_and_return: @events;
    }

    method examine($thing) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        my $pitch_black = %!dark_rooms{$!player_location}
            && !self!shining_thing_here($!player_location);

        die X::Adventure::PitchBlack.new(:action<see>)
            if $pitch_black;

        die X::Adventure::NoSuchThingHere.new(:$thing)
            unless self.thing_in_room_or_inventory($thing, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$thing};

        my @events = Adventure::PlayerExamined.new(
            :$thing
        );
        if %!examine_hooks{$thing} -> &hook {
            @events.push(&hook());
        }

        self!apply_and_return: @events;
    }

    method inventory() {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        my $thing = 'player inventory';
        my @events = Adventure::PlayerCheckedInventory.new(
            :things(self!explicit_things_at('player inventory'))
        );
        if %!examine_hooks{$thing} -> &hook {
            @events.push(&hook());
        }

        self!apply_and_return: @events;
    }

    method make_thing_openable($thing) {
        %!openable_things{$thing} = True;
    }

    method open($thing) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        die X::Adventure::NoSuchThingHere.new(:$thing)
            unless self.thing_in_room_or_inventory($thing, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$thing};

        die X::Adventure::ThingNotOpenable.new(:$thing)
            unless %!openable_things{$thing};

        die X::Adventure::ThingAlreadyOpen.new(:$thing)
            if %!open_things{$thing};

        my @events = Adventure::PlayerOpened.new(:$thing);
        my @contents = self!contents_of($thing);
        if @contents {
            @events.push(
                Adventure::ContentsRevealed.new(
                    :container($thing), :@contents
                )
            );
        }
        if %!open_hooks{$thing} -> &hook {
            @events.push(&hook());
        }
        @events.push(self!tick);
        self!apply_and_return: @events;
    }

    method make_thing_a_container($thing) {
        my @events = Adventure::ThingMadeAContainer.new(:$thing);
        self!apply_and_return: @events;
    }

    method put_thing_in($thing, $in) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        die X::Adventure::NoSuchThingHere.new(:$thing)
            unless self.thing_in_room_or_inventory($thing, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$thing};

        die X::Adventure::NoSuchThingHere.new(:thing($in))
            unless self.thing_in_room_or_inventory($in, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$in};

        die X::Adventure::ThingNotCarryable.new(:action<put>, :$thing)
            unless %!carryable_things{$thing};

        die X::Adventure::CannotPutInNonContainer.new(:$in)
            unless %!containers{$in};

        die X::Adventure::YoDawg.new(:relation<in>, :thing($in))
            if $thing eq $in;

        my @events;

        if %!openable_things{$in} && !%!open_things{$in} {
            @events.push(Adventure::PlayerOpened.new(:thing($in)));
        }
        @events.push(Adventure::PlayerPutIn.new(:$thing, :$in));
        if %!put_hooks{$in} -> &hook {
            @events.push($_) when Event for &hook($thing);
        }
        @events.push(self!tick);

        self!apply_and_return: @events;
    }

    method make_thing_a_platform($thing) {
        my @events = Adventure::ThingMadeAPlatform.new(:$thing);
        self!apply_and_return: @events;
    }

    method put_thing_on($thing, $on) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        die X::Adventure::NoSuchThingHere.new(:$thing)
            unless self.thing_in_room_or_inventory($thing, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$thing};

        die X::Adventure::NoSuchThingHere.new(:thing($on))
            unless self.thing_in_room_or_inventory($on, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$on};

        die X::Adventure::ThingNotCarryable.new(:action<put>, :$thing)
            unless %!carryable_things{$thing};

        die X::Adventure::CannotPutOnNonPlatform.new(:$on)
            unless %!platforms{$on};

        die X::Adventure::YoDawg.new(:relation<on>, :thing($on))
            if $thing eq $on;

        my @events = Adventure::PlayerPutOn.new(:$thing, :$on);
        if %!put_hooks{$on} -> &hook {
            @events.push($_) when Event for &hook($thing);
        }
        @events.push(self!tick);
        self!apply_and_return: @events;
    }

    method make_thing_readable($thing) {
        my @events = Adventure::ThingMadeReadable.new(:$thing);
        self!apply_and_return: @events;
    }

    method read($thing) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        die X::Adventure::NoSuchThingHere.new(:$thing)
            unless self.thing_in_room_or_inventory($thing, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$thing};

        die X::Adventure::ThingNotReadable.new(:$thing)
            unless %!readable_things{$thing};

        Adventure::PlayerRead.new(:$thing), self!tick;
    }

    method hide_thing($thing) {
        my @events = Adventure::ThingHidden.new(:$thing);
        self!apply_and_return: @events;
    }

    method unhide_thing($thing) {
        my @events = Adventure::ThingUnhidden.new(:$thing);
        self!apply_and_return: @events;
    }

    method make_thing_carryable($thing) {
        my @events = Adventure::ThingMadeCarryable.new(:$thing);
        self!apply_and_return: @events;
    }

    method take($thing) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        die X::Adventure::PlayerAlreadyCarries.new(:$thing)
            if (%!thing_rooms{$thing} // '') eq 'player inventory';

        my $pitch_black = %!dark_rooms{$!player_location}
            && !self!shining_thing_here($!player_location);

        die X::Adventure::PitchBlack.new(:action<take>)
            if $pitch_black;

        die X::Adventure::NoSuchThingHere.new(:$thing)
            unless self.thing_is_in($thing, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$thing};

        die X::Adventure::ThingNotCarryable.new(:action<take>, :$thing)
            unless %!carryable_things{$thing};

        my @events;
        for %!remove_from_hooks.kv -> $container, &hook {
            if self.thing_is_in($thing, "contents:$container") {
                @events.push($_) when Event for &hook($thing);
            }
        }
        # XXX: Need to apply this event early so that hooks can drop the thing.
        self!apply(Adventure::PlayerTook.new(:$thing));
        if %!take_hooks{$thing} -> &hook {
            @events.push($_) when Event for &hook();
        }
        @events.push(self!tick);
        self!apply($_) for @events;
        return Adventure::PlayerTook.new(:$thing), @events;
    }

    method drop($thing) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        die X::Adventure::PlayerDoesNotHave.new(:$thing)
            unless self.thing_is_in($thing, 'player inventory');

        die X::Adventure::PlayerDoesNotHave.new(:$thing)
            if %!hidden_things{$thing};

        my @events = Adventure::PlayerDropped.new(:$thing);
        @events.push(self!tick);
        self!apply_and_return: @events;
    }

    method remark($remark) {
        my @events = Adventure::GameRemarked.new(:$remark);
        self!apply_and_return: @events;
    }

    method make_thing_implicit($thing) {
        my @events = Adventure::ThingMadeImplicit.new(:$thing);
        self!apply_and_return: @events;
    }

    method make_room_dark($room) {
        my @events = Adventure::RoomMadeDark.new(:$room);
        self!apply_and_return: @events;
    }

    method use($thing) {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        die X::Adventure::PlayerNowhere.new()
            unless defined $!player_location;

        die X::Adventure::NoSuchThingHere.new(:$thing)
            unless self.thing_in_room_or_inventory($thing, $!player_location);

        die X::Adventure::NoSuchThingHere.new(:$thing)
            if %!hidden_things{$thing};

        my @events = Adventure::PlayerUsed.new(:$thing);
        if %!light_sources{$thing} {
            @events.push(Adventure::LightSourceSwitchedOn.new(:$thing));
        }
        @events.push(self!tick);
        self!apply_and_return: @events;
    }

    method make_thing_a_light_source($thing) {
        my @events = Adventure::ThingMadeALightSource.new(:$thing);
        self!apply_and_return: @events;
    }

    method finish() {
        die X::Adventure::GameOver.new()
            if $!game_finished;

        my @events = Adventure::GameFinished.new();
        self!apply_and_return: @events;
    }

    method on_try_exit($room, $direction, &hook) {
        %!try_exit_hooks{$room}{$direction} = &hook;
    }

    method on_examine($thing, &hook) {
        %!examine_hooks{$thing} = &hook;
    }

    method on_open($thing, &hook) {
        %!open_hooks{$thing} = &hook;
    }

    method on_put($thing, &hook) {
        %!put_hooks{$thing} = &hook;
    }

    method on_remove_from($thing, &hook) {
        %!remove_from_hooks{$thing} = &hook;
    }

    method on_take($thing, &hook) {
        %!take_hooks{$thing} = &hook;
    }

    method light_fuse($n, $name, &hook) {
        %!tick_hooks{$name} = { :ticks($n), :&hook };
    }

    method put_out_fuse($name) {
        %!tick_hooks.delete($name);
    }

    my class Save {
        has @.events;
    }

    method save {
        return Save.new(:@!events);
    }

    method restore(Save $save) {
        my $new-engine = Adventure::Engine.new();
        $new-engine!apply($_) for $save.events.list;
        return $new-engine;
    }

    sub opposite($direction) {
        my %opposites =
            'north'     => 'south',
            'east'      => 'west',
            'northeast' => 'southwest',
            'northwest' => 'southeast',
            'up'        => 'down',
        ;

        %opposites.push( %opposites.invert );

        %opposites{$direction};
    }

    method !apply_and_return(@events) {
        self!apply($_) for @events;
        return @events;
    }

    # RAKUDO: private multimethods NYI
    method !apply(Event $_) {
        push @!events, $_;
        when Adventure::TwoRoomsConnected {
            my ($room1, $room2) = .rooms.list;
            my $direction = .direction;
            %!exits{$room1}{$direction} = $room2;
            %!exits{$room2}{opposite $direction} = $room1;
        }
        when Adventure::TwoRoomsDisconnected {
            my ($room1, $room2) = .rooms.list;
            my $direction = .direction;
            %!exits{$room1}.delete($direction);
            %!exits{$room2}.delete(opposite $direction);
        }
        when Adventure::PlayerWalked {
            $!player_location = .to;
        }
        when Adventure::PlayerWasPlaced {
            $!player_location = .in;
        }
        when Adventure::DirectionAliased {
            %!exit_aliases{.room}{.alias} = .direction;
        }
        when Adventure::ThingPlaced {
            %!thing_rooms{.thing} = .room;
        }
        when Adventure::PlayerOpened {
            %!open_things{.thing} = True;
        }
        when Adventure::ThingMadeAContainer {
            %!containers{.thing} = True;
        }
        when Adventure::ThingMadeAPlatform {
            %!platforms{.thing} = True;
        }
        when Adventure::ThingMadeReadable {
            %!readable_things{.thing} = True;
        }
        when Adventure::ThingHidden {
            %!hidden_things{.thing} = True;
        }
        when Adventure::ThingUnhidden {
            %!hidden_things{.thing} = False;
        }
        when Adventure::ThingMadeCarryable {
            %!carryable_things{.thing} = True;
        }
        when Adventure::PlayerTook {
            %!thing_rooms{.thing} = 'player inventory';
        }
        when Adventure::PlayerDropped {
            %!thing_rooms{.thing} = $!player_location;
        }
        when Adventure::ThingMadeImplicit {
            %!implicit_things{.thing} = True;
        }
        when Adventure::RoomMadeDark {
            %!dark_rooms{.room} = True;
        }
        when Adventure::ThingMadeALightSource {
            %!light_sources{.thing} = True;
        }
        when Adventure::LightSourceSwitchedOn {
            %!things_shining{.thing} = True;
        }
        when Adventure::PlayerPutIn {
            %!thing_rooms{.thing} = "contents:{.in}";
        }
        when Adventure::PlayerPutOn {
            %!thing_rooms{.thing} = "contents:{.on}";
        }
        when Adventure::GameFinished {
            $!game_finished = True;
        }
    }
}
