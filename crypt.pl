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
    has Str $.containphrase;

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

sub exclude(@l, $e) { grep { $_ !=== $e }, @l }

role Container {
    has Thing @.contents is rw;

    method add(Str $name) {
        @.contents.push($name);
    }

    method remove(Str $name) {
        @.contents = exclude(@.contents, $name);
    }

    method list_contents($herephrase) {
        for %things{@.contents} -> Thing $thing {
            if player_can_see($thing) {
                say sprintf $thing.herephrase // $herephrase, $thing.name;
                if player_can_see_inside($thing) && $thing.contents {
                    say "The $thing.name() contains:";
                    $thing.list_container_contents(
                        "A %s."
                    );
                }
            }
        }
    }

    method list_container_contents($containphrase, $indent = 1) {
        for %things{@.contents} -> Thing $thing {
            say '  ' x $indent,
                sprintf $thing.containphrase // $containphrase, $thing.name;
        }
    }

    method on_open {
        say "Opening the $.name reveals a {join " and a ", @.contents}.";
    }
}

class Inventory does Thing does Container {
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
}

class Basket does Thing does Container {
}

role Darkness {
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
        $other_room.exits.delete($opposite);
    }

    method describe {
        say "[Description of room $!name]";
        say "";
    }

    method list_exits {
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

    method look {
        if there_is_light() {
            self.describe;
            self.list_contents("There is a %s here.");
            self.list_exits;
        }
        else {
            say "It is pitch black.";
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

class Cave does Room does Darkness {
}

class Crypt does Room does Darkness {
}

my $inventory = Inventory.new();

role Takable {
    method put_in(Container $container) {
        current_container_of($.name).remove($.name);
        $container.add($.name);
        self.?on_put_in($container);
    }

    method take {
        if inventory_contains($.name) {
            say "You are already holding the $.name";
            return;
        }
        say "You take the $.name.";
        self.put_in($inventory);
    }

    method drop {
        unless inventory_contains($.name) {
            say "You are not holding the $.name";
            return;
        }
        say "You drop the $.name on the ground.";
        self.put_in($room);
    }
}

class Disk does Thing does Takable {
}

my $used_abbreviated_syntax = False;
class Hall does Room does Darkness {
    has @!disks =
        [5, 4, 3, 2, 1],
        [],
        [],
    ;
    has $!long_moves_made = 0;
    my @sizes = <. tiny small middle large huge>;
    my @rods  = <left middle right>;

    method list_contents($herephrase) {
        for %things{@.contents} -> Thing $thing {
            next if $thing ~~ Disk;
            if player_can_see($thing) {
                say sprintf $thing.herephrase // $herephrase, $thing.name;
            }
        }
        say "There are rods stuck in the floor with disks on them, ",
            "like this:";
        self.show_disks;
        say "";
    }

    method show_disks {
        say "";
        my $indent = "     ";
        my @c =
            "     |     ",
            "    ===    ",
            "   =====   ",
            "  =======  ",
            " ========= ",
            "===========",
        ;
        for reverse 0..5 -> $row {
            say $indent, join "  ", map { @c[@!disks[$_][$row] // 0] }, 0..2;
        }
        say $indent, "-" x 37;
        say $indent, join "  ", map { "     $_     " }, <A B C>;
    }

    sub inverse_index(@array, $value) {
        my $index = (first { .value eq $value }, @array.pairs).key;
        return $index;
    }

    method take_disk(Str $adjective) {
        my $size  = inverse_index(@sizes, $adjective);
        my $old_rod = first { $size == any @!disks[$_].list }, 0..2;

        if defined $old_rod {
            if @!disks[$old_rod][*-1] != $size {
                say "You can't take the $adjective disk, because it is under ",
                    (join " and ", map { "the @sizes[$_] disk" },
                     grep { $_ < $size }, @!disks[$old_rod].list), ".";
                return;
            }
            pop @!disks[$old_rod];
        }

        %things{"$adjective disk"}.take;

        if defined $old_rod {
            self.?on_move_disk($old_rod);
        }
    }

    method move_disk_to_rod(Str $adjective, Str $position) {
        my $size  = inverse_index(@sizes, $adjective);
        my $old_rod = first { $size == any @!disks[$_].list }, 0..2;

        if defined $old_rod && @!disks[$old_rod][*-1] != $size {
            say "You can't take the $adjective disk, because it is under ",
                (join " and ", map { "the @sizes[$_] disk" },
                 grep { $_ < $size }, @!disks[$old_rod].list), ".";
            return;
        }

        my $new_rod = inverse_index(@rods, $position);
        if @!disks[$new_rod] {
            if @!disks[$new_rod][*-1] == $size {
                say "The $adjective disk is already on the $position rod.";
                return;
            }
            elsif @!disks[$new_rod][*-1] < $size {
                say "A sense of dread fills you as you attempt to put a ",
                    "bigger disk on a smaller one.";
                return;
            }
        }

        if defined $old_rod {
            pop @!disks[$old_rod];
        }

        %things{"$adjective disk"}.put_in($room);
        push @!disks[$new_rod], $size;

        say "You put the $adjective disk on the $position rod.";
        self.show_disks;

        if defined $old_rod {
            $!long_moves_made++;
            if 3 <= $!long_moves_made < 5 && !$used_abbreviated_syntax {
                my $abbr = chr(ord("A") + $old_rod) ~ chr(ord("A") + $new_rod);
                say "(You can also write this move as $abbr)";
            }
        }

        self.?on_move_disk($old_rod);
    }

    method move_rod_to_rod(Int $old_rod, Int $new_rod) {
        unless @!disks[$old_rod] {
            say "The {@rods[$old_rod]} rod is empty.";
            return;
        }

        my $size = @!disks[$old_rod][*-1];
        if @!disks[$new_rod] {
            if @!disks[$new_rod][*-1] < $size {
                say "A sense of dread fills you as you attempt to put a ",
                    "bigger disk on a smaller one.";
                return;
            }
        }

        pop @!disks[$old_rod];
        push @!disks[$new_rod], $size;

        my $adjective = @sizes[$size];
        my $position  = @rods[$new_rod];

        say "You put the $adjective disk on the $position rod.";
        self.show_disks;

        self.?on_move_disk($old_rod);
    }

    method on_move_disk($old_rod) {
        if @!disks[2] == 5 {
            say "The whole floor tips, and reveals a hole beneath the wall.";
            %rooms<hall>.connect('down', %rooms<cave>);
        }

        if defined $old_rod && $old_rod == 2 && @!disks[2] == 3 {
            say "The whole floor tips back, hiding the hole again.";
            %rooms<hall>.disconnect('down');
        }
    }
}

class Leaves does Thing does Showable does Takable {
    method on_put_in(Container $_) {
        when Car {
            say "Great. Now your car is full of leaves.";
        }
        when Basket {
            say "The ground rumbles and shakes a bit.";
            say "A passageway opens up to the south, into the caverns.";
            %rooms<chamber>.connect('south', %rooms<hall>);
        }
    }
}

class Flashlight does Thing does Takable {
    has Bool $.is_on = False;

    method switch_on {
        if $.is_on {
            say "It's already switched on.";
        }
        $!is_on = True;
        say "You switch on the flashlight.";
    }

    method examine {
        self.Thing::examine;
        say "";
        say "The $.name is switched {$.is_on ?? "on" !! "off"}.";
    }
}

class Rope does Thing does Takable {
}

sub current_container_of(Str $name) {
    return $room      if $name eq $room.name.lc;
    return $room      if $name eq any $room.contents;
    return $inventory if $name eq any $inventory.contents;
    for %things{$room.contents} -> $thing {
        return $thing if $name eq any $thing.?contents;
    }
    die "Couldn't find the current container of $name";
}

sub room_contains(Str $name) {
    return True if $name eq $room.name.lc;
    return True if $name eq any $room.contents;
    return True if $name eq any map { .contents.flat },
                                grep { player_can_see_inside($_) },
                                %things{$room.contents};
    return False;
}

sub inventory_contains(Str $name) {
    return True if $name eq any($inventory.contents);
    return False;
}

sub player_can_see(Thing $thing) {
    my $thing_is_visible = $thing !~~ Showable || $thing.is_visible;

    return False unless $thing_is_visible;
    return False unless room_contains($thing.name.lc)
                        || inventory_contains($thing.name.lc);

    return True;
}

sub player_can_see_inside(Thing $thing) {
    my $thing_is_open = $thing ~~ Container
                        && ($thing !~~ Openable || $thing.is_open);

    return False unless $thing_is_open;
    return False unless player_can_see($thing);

    return True;
}

sub there_is_light() {
    my $there_is_sun = $room !~~ Darkness;
    return True if $there_is_sun;

    my $flashlight = %things<flashlight>;
    my $flashlight_is_here = player_can_see($flashlight);
    return True if $flashlight_is_here && $flashlight.is_on;
    return False;
}

my %things =
    car        => Car.new(:name<car>, :contents<flashlight rope>,
                          :herephrase("Your %s is parked here.")),
    flashlight => Flashlight.new(:name<flashlight>),
    rope       => Rope.new(:name<rope>),
    door       => Door.new(:name<door>),
    leaves     => Leaves.new(:name<leaves>,
                    :herephrase("Numerous leaves are adorning the trees."),
                    :containphrase("69,105 %s.")),
    brook      => Brook.new(:name<brook>,
                    :herephrase("A small brook runs through the forest.")),
    sign       => Thing.new(:name<sign>),
    basket     => Basket.new(:name<basket>),
    "tiny disk"   => Disk.new(:name("tiny disk"),   :size(1)),
    "small disk"  => Disk.new(:name("small disk"),  :size(2)),
    "middle disk" => Disk.new(:name("middle disk"), :size(3)),
    "large disk"  => Disk.new(:name("large disk"),  :size(4)),
    "huge disk"   => Disk.new(:name("huge disk"),   :size(5)),
;

my %rooms =
    clearing => Room.new( :name<Clearing>, :contents<car> ),
    hill     => Hill.new( :name<Hill>, :contents<door leaves brook>,
                          :in<south> ),
    chamber  => Chamber.new( :name(<Chamber>), :contents<sign basket>,
                             :out<north> ),
    hall     => Hall.new( :name(<Hall>),
                          :contents(map { "$_ disk" },
                                    <tiny small middle large huge>)),
    cave     => Cave.new( :name(<Cave>) ),
    crypt    => Crypt.new( :name(<Crypt>) ),
;
%things.push(%rooms);

%rooms<clearing>.connect('east', %rooms<hill>);
%rooms<cave>.connect('northwest', %rooms<crypt>);

my %synonyms =
    "x"     => "examine",
;

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
                $inventory.list_container_contents("A %s.");
            }
            else {
                say "You are empty-handed.";
            }
        }

        when /^ :s [turn on||switch on] $<noun>=[[flash]?light] $/ {
            my $flashlight = %things<flashlight>;
            unless player_can_see($flashlight) {
                say "You see no $<noun> here.";
                succeed;
            }

            my $was_dark = !there_is_light;
            $flashlight.switch_on;
            if $was_dark {
                say "";
                $room.look;
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

        when /^ :s $<verb>=[\w+] [the]? $<noun1>=[\w+]
                in [the]? $<noun2>=[\w+] $/ {
            my $verb = $<verb>;
            if %synonyms{$verb} -> $synonym {
                $verb = $synonym;
            }

            unless $verb eq 'put' {
                say "Sorry, I did not understand that.";
                succeed;
            }

            my $thing = %things{$<noun1>.lc};
            unless player_can_see($thing) {
                say "You see no $<noun1> here.";
                succeed;
            }

            my $container = %things{$<noun2>.lc};
            unless player_can_see($container) {
                say "You see no $<noun2> here.";
                succeed;
            }

            unless $thing ~~ Takable {
                say "You can't move the $<noun1>.";
                succeed;
            }

            unless player_can_see_inside($container) {
                $container.open;
            }

            say "You put the $<noun1> in the $<noun2>.";
            $thing.put_in($container);
        }

        when /^ :s [move|put|take] [the]? disk / {
            say "Which disk do you mean; the tiny disk, the small disk, ",
                "the middle disk,";
            say "the large disk, or the huge disk?";
        }

        when /^ :s take [the]?
                $<adjective>=[tiny||small||middle||large||huge] disk / {

            unless player_can_see(%things{"$<adjective> disk"}) {
                say "You see no $<adjective> disk here.";
                succeed;
            }
            if $room ~~ Hall {
                $room.take_disk(~$<adjective>);
            }
            else {
                %things{"$<adjective> disk"}.take;
            }
        }

        when /^ :s [move|put] [the]?
                $<adjective>=[tiny||small||middle||large||huge]
                disk [on|to] [the]?
                $<position>=[left||middle||right]
                rod $/ {

            unless player_can_see(%things{"$<adjective> disk"}) {
                say "You see no $<adjective> disk here.";
                succeed;
            }
            unless $room ~~ Hall {
                say "You see no rod here.";
                succeed;
            }

            $room.move_disk_to_rod(~$<adjective>, ~$<position>);
        }

        when /^ :s (<[abcABC]>)(<[abcABC]>) $/ {
            $used_abbreviated_syntax = True;

            unless $room ~~ Hall {
                say "That command only works in the Hall.";
                succeed;
            }

            my $old_rod = ord($0.lc) - ord("a");
            my $new_rod = ord($1.lc) - ord("a");
            if $old_rod == $new_rod {
                succeed;
            }

            $room.move_rod_to_rod($old_rod, $new_rod);
        }

        default {
            say "Sorry, I did not understand that.";
        }
    }
}
