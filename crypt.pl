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

class Room {
    has $.name;
    has %.exits is rw;
    has $!visited = False;

    method connect(Direction $direction, Room $room) {
        my $opposite = opposite_direction($direction);
        self.exits{$direction} = $room;
        $room.exits{$opposite} = self;
    }

    method look {
        say "";
        say "[Description of room $.name]";
        say "There are exits ", join(" ", %.exits.keys);
    }

    method enter {
        say $.name;

        unless $!visited {
            self.look;
        }

        $!visited = True;
    }
}

my $clearing = Room.new( :name<Clearing> );
my $hill = Room.new( :name<Hill> );
my $chamber = Room.new( :name(<Chamber>) );
my $hall = Room.new( :name(<Hall>) );
my $cave = Room.new( :name(<Cave>) );
my $crypt = Room.new( :name(<Crypt>) );

$clearing.connect( 'east',      $hill     );
$hill.connect(     'south',     $chamber  );
$hill.connect(     'in',        $chamber  );
$chamber.connect(  'south',     $hall     );
$hall.connect(     'down',      $cave     );
$cave.connect(     'northwest', $crypt    );

$clearing.enter;
my $room = $clearing;
loop {
    say "";
    my $command = prompt "> ";

    given $command {
        when /^ \s* $/ {
            succeed;
        }

        when any(%abbr_directions.keys) {
            $command = %abbr_directions{$command};
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

        default {
            say "Sorry, I did not understand that.";
        }
    }
}
