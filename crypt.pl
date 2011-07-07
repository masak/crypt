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
    has Str $!name;
    has Bool $!hidden;

    method there_is {
        "There is a $!name here.";
    }
}

role Showable {
    has Bool $.is_visible;

    method show {
        unless $!is_visible {
            $!is_visible = True;
            self.on_show;
        }
    }
}

class Car does Thing {
    method there_is {
        "Your $!name is here.";
    }
}

role Openable {
    has Bool $.is_open;

    method open {
        if $.is_open {
            say "The $!name is open.";
            return;
        }
        say "You open the $!name.";
        $!is_open = True;
        self.?on_open;
    }

    method close {
        unless $.is_open {
            say "The $!name is closed.";
            return;
        }
        say "You close the $!name.";
        $!is_open = False;
        self.?on_close;
    }
}

my $hill;
my $chamber;

class Door does Thing does Showable does Openable {
    method on_examine {
        self.show;
    }

    method on_show {
        say "There's a door here, under the thick grass!";
    }

    method on_open {
        say "You can see into the hill now!";
        $hill.connect(     'south',     $chamber  );
    }

    method on_close {
        $hill.disconnect('south');
    }
}

my $car = Car.new(:name("car"));
my $door = Door.new(:name("door"), :is_visible(False));

class Room {
    has Str $!name;
    has Direction %.exits is rw;
    has Direction $.in;
    has Direction $.out;
    has Bool $!visited = False;
    has Thing @.contents is rw;

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
        for @.contents -> $thing {
            if $thing !~~ Showable || $thing.is_visible {
                say $thing.there_is;
            }
        }
        given %.exits {
            when 1 {
                say "There is an exit to the {.keys}.";
            }
            when 2 {
                say "There are exits to the {.keys.join(" and the ")}.";
            }
            when 3 {
                say "There are exits to the ", .keys[0..*-2].join(", "),
                    "and the {.keys[*-1]}.";
            }
        }
    }

    method enter {
        say $!name;

        unless $!visited {
            say "";
            self.look;
        }

        $!visited = True;
    }
}

my $clearing = Room.new( :name<Clearing>, :contents($car) );
$hill = Room.new( :name<Hill>, :contents($door), :in<south> );
$chamber = Room.new( :name(<Chamber>), :out<north> );
my $hall = Room.new( :name(<Hall>) );
my $cave = Room.new( :name(<Cave>) );
my $crypt = Room.new( :name(<Crypt>) );

$clearing.connect( 'east',      $hill     );

# The following lines will be dynamically applied by solved puzzles.
#
# $chamber.connect(  'south',     $hall     );
# $hall.connect(     'down',      $cave     );
# $cave.connect(     'northwest', $crypt    );

$clearing.enter;
my $room = $clearing;
loop {
    say "";
    my $command = prompt "> ";

    given $command {
        when !.defined || *.lc eq "q" | "quit" {
            say "";
            if "y"|"yes" eq prompt "Really quit (Y/N)? " {
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
                $room = $new_room;
            }
            else {
                say "Sorry, you can't go $direction from here.";
            }
        }

        when 'look'|'l' {
            $room.look;
        }

        when 'examine hill'|'examine the hill' {
            $door.show;
        }

        when 'open door'|'open the door' {
            if $room === $hill && $door.is_visible {
                $door.open;
            }
            else {
                say "You see no door here.";
            }
        }

        when 'close door'|'close the door' {
            if $room === $hill && $door.is_visible {
                $door.close;
            }
            else {
                say "You see no door here.";
            }
        }

        default {
            say "Sorry, I did not understand that.";
        }
    }
}
