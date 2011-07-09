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

    method there_is {
        "There is a $!name here.";
    }

    method examine {
        say $!description;
        self.?on_examine;
    }
}

role Showable {
    has Bool $.is_visible = False;

    method show {
        unless $!is_visible {
            $!is_visible = True;
            self.?on_show;
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

class Leaves does Thing does Showable {
    method there_is {
        "There are numerous leaves on the trees.";
    }
}

class Brook does Thing {
    method there_is {
        "A small brook is running through the forest.";
    }
}

role Room does Thing {
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
        say "";
        for %things{@.contents} -> $thing {
            if $thing !~~ Showable || $thing.is_visible {
                say $thing.there_is;
            }
        }
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

        unless $!visited {
            say "";
            self.look;
        }

        $!visited = True;
    }
}

class Hill does Room {
    method on_examine {
        %things<door>.show;
    }
}

my %things =
    car    => Car.new(:name("car")),
    door   => Door.new(:name("door")),
    leaves => Leaves.new(:name("leaves")),
    brook  => Brook.new(:name("brook")),
;

my %rooms =
    clearing => Room.new( :name<Clearing>, :contents<car> ),
    hill     => Hill.new( :name<Hill>, :contents<door leaves brook>,
                          :in<south> ),
    chamber  => Room.new( :name(<Chamber>), :out<north> ),
    hall     => Room.new( :name(<Hall>) ),
    cave     => Room.new( :name(<Cave>) ),
    crypt    => Room.new( :name(<Crypt>) ),
;
%things.push(%rooms);

%rooms<clearing>.connect('east', %rooms<hill>);

# The following lines will be dynamically applied by solved puzzles.
#
# $chamber.connect(  'south',     $hall     );
# $hall.connect(     'down',      $cave     );
# $cave.connect(     'northwest', $crypt    );

%rooms<clearing>.enter;
my $room = %rooms<clearing>;
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

        when /^ $<verb>=[\w+] <.ws> [the]? <.ws> $<noun>=[\w+] $/ {
            unless $<verb> eq any <examine open close> {
                say "Sorry, I don't understand the verb '$<verb>'.";
                succeed;
            }
            my $thing = %things{$<noun>};
            my $is_present
                = $<noun>.lc eq any($room.name.lc, $room.contents.list);
            my $is_visible = $thing !~~ Showable || $thing.is_visible;
            unless $is_present && $is_visible {
                say "You see no $<noun> here.";
                succeed;
            }
            my $found_method;
            try {
                $thing."$<verb>"();
                $found_method = True;
            }
            unless $found_method {
                say "You can't $<verb> the $<noun>.";
            }
        }

        default {
            say "Sorry, I did not understand that.";
        }
    }
}
