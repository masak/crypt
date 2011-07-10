use v6;

say "CRYPT";
say "=====";
say "";

say "You've heard there's supposed to be a hidden crypt in these woods.";
say "One containing a priceless treasure. Well, there's only one way to";
say "find out...";
say "";

my @directions = <
    north south east west
    northeast northwest southeast southwest
    up down in out
>;

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

subset Direction of Str where any(@directions);

sub opposite_direction(Direction $d) {
    my %opposites =
        'north'     => 'south',
        'east'      => 'west',
        'northeast' => 'southwest',
        'northwest' => 'southeast',
        'up'        => 'down',
        'in'        => 'out',
    ;

    %opposites.push( %opposites.invert );

    %opposites{$d};
}

role Thing {
    has Str $.name;
    has Str $!description = "[Description of $!name]";
    has Str $.herephrase;
    has Str $.carryphrase;

    method examine {
        say $!description;
        self.?on_examine;
    }
}

role Showable {
    has Bool $.is_visible = False;

    method show {
        unless $.is_visible {
            $!is_visible = True;
            self.?on_show;
        }
    }
}

role Openable {
    has Bool $.is_open;

    method open {
        if $.is_open {
            say "The $.name is open.";
            return;
        }
        say "You open the $.name.";
        $!is_open = True;
        self.?on_open;
    }

    method close {
        unless $.is_open {
            say "The $.name is closed.";
            return;
        }
        say "You close the $.name.";
        $!is_open = False;
        self.?on_close;
    }
}

role Container {
    has Thing @.contents is rw;

    method list_contents($herephrase, $indent = 0) {
        for %things{@.contents} -> Thing $thing {
            if player_can_see($thing) {
                say '  ' x $indent,
                    sprintf $thing.herephrase // $herephrase, $thing.name;
                if player_can_see_inside($thing) {
                    $thing.list_contents("A %s is in the $thing.name().",
                                         $indent + 1);
                }
            }
        }
    }

    method on_open {
        say "Opening the $.name reveals a {join " and a ", @.contents}.";
    }
}

class Inventory does Thing does Container {
    method list_contents($carryphrase, $indent = 1) {
        for %things{@.contents} -> Thing $thing {
            say '  ' x $indent,
                sprintf $thing.carryphrase // $carryphrase, $thing.name;
        }
    }
}

class Car does Thing does Openable does Container {
}

class Door does Thing does Showable does Openable {
    method on_examine {
        self.show;
    }

    method on_show {
        say "You discover a door in the hill, under the thick grass!";
    }

    method on_open {
        say "You can see into the hill now!";
        %rooms<hill>.connect('south', %rooms<chamber>);
    }

    method on_close {
        %rooms<hill>.disconnect('south');
    }
}

class Brook does Thing {
    method there_is {
        "A small brook is running through the forest.";
    }
}

class Basket does Thing does Container {
}

my $room;
role Room does Thing does Container {
    has Direction %.exits is rw;
    has Direction $.in;
    has Direction $.out;
    has Bool $!visited = False;

    method connect(Direction $direction, Room $other_room) {
        my $opposite = opposite_direction($direction);
        self.exits{$direction} = $other_room;
        $other_room.exits{$opposite} = self;
    }

    method disconnect(Direction $direction) {
        my $opposite = opposite_direction($direction);
        my $other_room = self.exits.delete($direction);
        $room.exits.delete($opposite);
    }

    method look {
        say "[Description of room $!name]";
        say "";
        self.list_contents("There is a %s here.");
        given %.exits {
            when 0 {
                say "There are no obvious exits from here.";
            }
            when 1 {
                say "You can go {.keys}.";
            }
            when 2 {
                say "You can go {.keys.join(" and ")}.";
            }
            default {
                say "You can go {.keys[0..*-2].join(", ")} and {.keys[*-1]}.";
            }
        }
    }

    method enter {
        say $!name;
        $room = self;

        unless $!visited {
            say "";
            self.look;
        }

        $!visited = True;
        self.?on_enter;
    }
}

class Hill does Room {
    method on_examine {
        %things<door>.show;
    }
}

class Chamber does Room {
    method on_enter {
        %things<leaves>.show;
    }
}

my $inventory = Inventory.new;

sub exclude(@l, $e) { grep { $_ !=== $e }, @l }

role Takable {
    method take {
        if inventory_contains($.name) {
            say "You already have the $.name";
            return;
        }
        say "You take the $.name.";
        push $inventory.contents, $.name;
        for $room, %things{$room.contents} -> $thing {
            next unless $thing ~~ Container;
            $thing.contents = exclude($thing.contents, $.name);
        }
    }

    method drop {
        unless inventory_contains($.name) {
            say "You don't have the $.name";
            return;
        }
        say "You drop the $.name on the ground.";
        push $room.contents, $.name;
        $inventory.contents = exclude($inventory.contents, $.name);
    }
}

class Leaves does Thing does Showable does Takable {
    method there_is {
        "There are numerous leaves on the trees.";
    }
}

class Flashlight does Thing does Takable {
}

class Rope does Thing does Takable {
}

sub room_contains(Str $name) {
    return True if $name eq $room.name.lc;
    return True if $name eq any($room.contents);
    return True if $name eq any map { .contents.flat },
                                grep Container, %things{$room.contents};
    return False;
}

sub inventory_contains(Str $name) {
    return True if $name eq any($inventory.contents);
    return False;
}

sub player_can_see(Thing $thing) {
    my $thing_is_visible = $thing !~~ Showable || $thing.is_visible;

    return False unless $thing_is_visible;
    return False unless room_contains($thing.name)
                        || inventory_contains($thing.name);

    return True;
}

sub player_can_see_inside(Thing $thing) {
    my $thing_is_open = $thing ~~ Container
                        && ($thing !~~ Openable || $thing.is_open);

    return False unless $thing_is_open;
    return False unless player_can_see($thing);

    return True;
}

my %things =
    car        => Car.new(:name<car>, :contents<flashlight rope>,
                          :herephrase("Your %s is parked here.")),
    flashlight => Flashlight.new(:name<flashlight>),
    rope       => Rope.new(:name<rope>),
    door       => Door.new(:name<door>),
    leaves     => Leaves.new(:name<leaves>,
                    :herephrase("Numerous %s are hanging off the trees."),
                    :carryphrase("69,105 %s.")),
    brook      => Brook.new(:name<brook>),
    sign       => Thing.new(:name<sign>),
    basket     => Basket.new(:name<basket>),
;

my %rooms =
    clearing => Room.new( :name<Clearing>, :contents<car> ),
    hill     => Hill.new( :name<Hill>, :contents<door leaves brook>,
                          :in<south> ),
    chamber  => Chamber.new( :name(<Chamber>), :contents<sign basket>,
                             :out<north> ),
    hall     => Room.new( :name(<Hall>) ),
    cave     => Room.new( :name(<Cave>) ),
    crypt    => Room.new( :name(<Crypt>) ),
;
%things.push(%rooms);

%rooms<clearing>.connect('east', %rooms<hill>);

my %synonyms =
    "x"     => "examine",
;

# The following lines will be dynamically applied by solved puzzles.
#
# $chamber.connect(  'south',     $hall     );
# $hall.connect(     'down',      $cave     );
# $cave.connect(     'northwest', $crypt    );

%rooms<clearing>.enter;

loop {
    say "";
    my $command = prompt "> ";

    given $command {
        when !.defined || .lc eq "q" | "quit" {
            say "";
            if "y"|"yes" eq lc prompt "Really quit (y/N)? " {
                say "Thanks for playing.";
                exit;
            }
        }

        when /^ \s* $/ {
            succeed;
        }

        when any(%abbr_directions.keys) {
            $command = %abbr_directions{$command};
            proceed;
        }

        when 'in' {
            if $room.in -> $real_direction {
                $command = $real_direction;
            }
            proceed;
        }

        when 'out' {
            if $room.out -> $real_direction {
                $command = $real_direction;
            }
            proceed;
        }

        when any(@directions) {
            my $direction = $command;
            if $room.exits{$direction} -> $new_room {
                $new_room.enter;
            }
            else {
                say "Sorry, you can't go $direction from here.";
            }
        }

        when "look"|"l" {
            $room.look;
        }

        when "inventory"|"i" {
            if $inventory.contents {
                say "You are carrying:";
                $inventory.list_contents("A %s.", 1);
            }
            else {
                say "You are empty-handed.";
            }
        }

        when /^ $<verb>=[\w+] <.ws> [the]? <.ws> $<noun>=[\w+] $/ {
            my $verb = $<verb>;
            if %synonyms{$verb} -> $synonym {
                $verb = $synonym;
            }

            unless $verb eq any <examine open close take drop> {
                say "Sorry, I don't understand the verb '$<verb>'.";
                succeed;
            }
            my $thing = %things{$<noun>.lc};
            unless player_can_see($thing) {
                say "You see no $<noun> here.";
                succeed;
            }

            unless $thing.can($verb) {
                say "You can't $<verb> the $<noun>.";
                succeed;
            }

            $thing."$verb"();
        }

        default {
            say "Sorry, I did not understand that.";
        }
    }
}
