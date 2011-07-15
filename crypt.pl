use v6;

say "CRYPT";
say "=====";
say "";

say "You've heard there's supposed to be an ancient hidden crypt in these";
say "woods. One containing a priceless treasure. Well, there's only one way";
say "to find out...";
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

role Implicit {
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

role Platform {
    has Thing @.supports is rw;

    method add(Str $name) {
        @.supports.push($name);
    }

    method remove(Str $name) {
        @.supports = exclude(@.supports, $name);
    }

    method list_platform_supports($containphrase, $indent = 1) {
        for %things{@.supports} -> Thing $thing {
            say '  ' x $indent,
                sprintf $thing.containphrase // $containphrase, $thing.name;
            if player_can_see_inside($thing) && $thing.contents {
                say '  ' x $indent, "The $thing.name() contains:";
                $thing.list_container_contents("A %s.", $indent + 1);
            }
        }
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
                next if $thing ~~ Implicit;
                say sprintf $thing.herephrase // $herephrase, $thing.name;
                if player_can_see_inside($thing) && $thing.contents {
                    say "The $thing.name() contains:";
                    $thing.list_container_contents("A %s.");
                }
                if $thing ~~ Platform && $thing.supports {
                    say "On the $thing.name() you see:";
                    $thing.list_platform_supports("A %s.");
                }
            }
        }
    }

    method list_container_contents($containphrase, $indent = 1) {
        for %things{@.contents} -> Thing $thing {
            say '  ' x $indent,
                sprintf $thing.containphrase // $containphrase, $thing.name;
            if player_can_see_inside($thing) && $thing.contents {
                say '  ' x $indent, "The $thing.name() contains:";
                $thing.list_container_contents("A %s.", $indent + 1);
            }
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

class Brook does Thing does Container {
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
        if %things<doom>.activated {
            say "An alarm is sounding.";
        }
    }
}

class Hill does Room {
    method on_examine {
        %things<door>.show;
    }

    method on_enter {
        if inventory_contains 'butterfly' {
            say "Congratulations! You found the treasure and got out with it ",
                "alive!";
            say "Thank you for playing.";
            exit;
        }
    }
}

class Chamber does Room {
}

class Cave does Room does Darkness {
    method on_try_exit($direction) {
        if $direction eq "northwest" && player_can_see(%things<fire>) {
            say "You try to walk past the fire, but it's too hot!";
            return False;
        }
        return True;
    }
}

class Crypt does Room does Darkness {
}

my $inventory = Inventory.new();

role Takable {
    method put($new_receiver) {
        my $old_receiver = current_container_of($.name);
        $old_receiver.remove($.name);
        self.?on_remove_from($old_receiver);

        $new_receiver.add($.name);
        self.?on_put($new_receiver);
    }

    method take {
        if inventory_contains($.name) {
            say "You are already holding the $.name";
            return;
        }
        say "You take the $.name.";
        self.put($inventory);
    }

    method drop {
        unless inventory_contains($.name) {
            say "You are not holding the $.name";
            return;
        }
        say "You drop the $.name on the ground.";
        self.put($room);
    }
}

role Heavy {
    method on_remove_from($_) {
        when Platform {
            unless grep Heavy, %things<pedestal>.supports {
                say "An alarm starts sounding in the whole cavern.";
                %things<doom>.activate;
            }
        }
    }

    method on_put($_) {
        when Platform {
            say "The alarm stops.";
            %things<doom>.inactivate;
        }
    }
}

class Disk does Thing does Takable does Heavy {
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
        say "There are rods stuck in the floor with disks on them, ",
            "like this:";
        self.show_disks;
        say "";
        for %things{@.contents} -> Thing $thing {
            next if $thing ~~ Disk;
            if player_can_see($thing) {
                say sprintf $thing.herephrase // $herephrase, $thing.name;
            }
        }
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

        %things{"$adjective disk"}.put($room);
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

class Fire does Thing does Container {
}

class Leaves does Thing does Implicit does Takable {
    method on_put(Container $_) {
        when Car {
            say "Great. Now your car is full of leaves.";
        }
        when Basket {
            say "The ground rumbles and shakes a bit.";
            say "A passageway opens up to the south, into the caverns.";
            %rooms<chamber>.connect('south', %rooms<hall>);
        }
        when Fire {
            say "The leaves burn up within seconds.";
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

class Helmet does Thing does Implicit does Container does Takable {
    method on_remove_from(Container $_) {
        when Brook {
            %things<water>.put(self);
        }
    }
}

class Water does Thing does Implicit does Takable {
    method on_put($_) {
        when Inventory {
            say "Your bare hands aren't very good at carrying water.";
            self.drop;
        }
        when Fire {
            say "The fire wanes and dies.";
            $room.remove("fire");
        }
    }
}

class Pedestal does Thing does Platform {
}

class Butterfly does Thing does Takable does Heavy {
}

class Doom {
    has Bool $.activated = False;
    has Int $!time_left;

    method activate {
        $!activated = True;
        $!time_left = 4;
    }

    method inactivate {
        $!activated = False;
    }

    method tick {
        if $!activated {
            $!time_left--;
            unless $!time_left {
                say "The alarm starts sounding louder.";
                say "The whole cavern shakes, and falls in on itself.";
                say "You die.";
                say "Thank you for playing.";
                exit;
            }
        }
    }
}

sub current_container_of(Str $name) {
    return $room      if $name eq $room.name.lc;
    return $room      if $name eq any $room.contents;
    return $inventory if $name eq any $inventory.contents;
    for %things{$room.contents, $inventory.contents} -> $thing {
        return $thing if $name eq any $thing.?contents;
        return $thing if $name eq any $thing.?supports;
    }
    return Nil;
}

sub room_contains(Str $name) {
    return current_container_of($name).?name eq any $room.name, $room.contents;
}

sub inventory_contains(Str $name) {
    return True if $name eq any $inventory.contents;
    return True if $name eq any map { .contents.flat },
                                grep { player_can_see_inside($_) },
                                %things{$inventory.contents};
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

    my $fire = %things<fire>;
    my $fire_is_here = player_can_see($fire);
    return True if $fire_is_here;

    return False;
}

my %things =
    car        => Car.new(:name<car>, :contents<flashlight rope>,
                          :herephrase("Your %s is parked here.")),
    flashlight => Flashlight.new(:name<flashlight>),
    rope       => Rope.new(:name<rope>),
    door       => Door.new(:name<door>),
    leaves     => Leaves.new(:name<leaves>,
                    :containphrase("69,105 %s.")),
    brook      => Brook.new(:name<brook>,
                    :herephrase("A small brook runs through the forest.")),
    water      => Water.new(:name<water>, :containphrase("Some %s.")),
    sign       => Thing.new(:name<sign>),
    basket     => Basket.new(:name<basket>),
    "tiny disk"   => Disk.new(:name("tiny disk"),   :size(1)),
    "small disk"  => Disk.new(:name("small disk"),  :size(2)),
    "middle disk" => Disk.new(:name("middle disk"), :size(3)),
    "large disk"  => Disk.new(:name("large disk"),  :size(4)),
    "huge disk"   => Disk.new(:name("huge disk"),   :size(5)),
    fire       => Fire.new(:name<fire>),
    helmet     => Helmet.new(:name<helmet>),
    pedestal   => Pedestal.new(:name<pedestal>, :supports<butterfly>),
    butterfly  => Butterfly.new(:name<butterfly>),
    doom       => Doom.new(),
;

my %rooms =
    clearing => Room.new( :name<Clearing>, :contents<car> ),
    hill     => Hill.new( :name<Hill>, :contents<door leaves brook water>,
                          :in<south> ),
    chamber  => Chamber.new( :name(<Chamber>), :contents<sign basket>,
                             :out<north> ),
    hall     => Hall.new( :name(<Hall>),
                          :contents(<helmet>, map { "$_ disk" },
                                    <tiny small middle large huge>)),
    cave     => Cave.new( :name(<Cave>), :contents<fire> ),
    crypt    => Crypt.new( :name(<Crypt>), :contents<pedestal> ),
;
%things.push(%rooms);

%rooms<clearing>.connect('east', %rooms<hill>);
%rooms<cave>.connect('northwest', %rooms<crypt>);

my %synonyms =
    "x"        => "examine",
    "look"     => "examine",
    "pick"     => "take",
    "get"      => "take",
    "retrieve" => "take",
    "retreive" => "take",  # might as well
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

        when "help"|"h"|"?" {
            say "Here are some (made-up) examples of commands you can use:";
            say "";
            say "look (l)                             | ",
                "take banana";
            say "examine banana (x banana)            | ",
                "drop banana";
            say "[go] north/south/east/west (n/s/e/w) | ",
                "put banana in bag";
        }

        when /^ :s go (\w+) $/
             && $0 eq any @directions, %abbr_directions.keys, <in out> {

            $command = ~$0;
            proceed;
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
                my $succeeded = $room.?on_try_exit($direction) // True;
                if $succeeded {
                    $new_room.enter;
                }
                %things<doom>.tick;
            }
            else {
                say "Sorry, you can't go $direction from here.";
            }
        }

        when "look"|"l" {
            $room.look;
        }

        when /^ :s look in $<noun>=[\w+] $/ {
            my $thing = %things{$<noun>};

            unless $thing {
                say "I am unfamiliar with the noun '$<noun>'.";
                succeed;
            }
            unless player_can_see($thing) {
                say "You see no $<noun> here.";
                succeed;
            }

            unless player_can_see_inside($thing) {
                say "You can't see inside the $<noun>.";
                succeed;
            }

            say "The $thing.name() contains:";
            $thing.list_container_contents("A %s.");
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
                say "Type 'help' for suggestions.";
                succeed;
            }

            my $thing = %things{$<noun>.lc};
            unless $thing {
                say "I am unfamiliar with the noun '$<noun>'.";
                succeed;
            }
            unless player_can_see($thing) {
                say "You see no $<noun> here.";
                succeed;
            }

            unless $thing.can($verb) {
                say "You can't $<verb> the $<noun>.";
                succeed;
            }

            $thing."$verb"();
            %things<doom>.tick;
        }

        when /^ :s $<verb>=[\w+] [the]? $<noun1>=[\w+]
                $<prep>=[in||on] [the]? $<noun2>=[\w+] $/ {
            my $verb = $<verb>;
            if %synonyms{$verb} -> $synonym {
                $verb = $synonym;
            }

            unless $verb eq 'put' {
                say "Sorry, I did not understand that.";
                say "Type 'help' for suggestions.";
                succeed;
            }

            if $<noun1> eq "disk" && $room ~~ Hall {
                say "Which disk do you mean; the tiny disk, the small disk, ",
                    "the middle disk,";
                say "the large disk, or the huge disk?";
                succeed;
            }

            my $noun1 = $<noun1>;
            if $<noun1> eq "disk" && $room ~~ Crypt {
                $noun1 = "tiny disk";
            }

            my $thing = %things{$noun1.lc};
            unless $thing {
                say "I am unfamiliar with the noun '$noun1'.";
                succeed;
            }
            unless player_can_see($thing) {
                say "You see no $<noun1> here.";
                succeed;
            }

            my $receiver = %things{$<noun2>.lc};
            unless $receiver {
                say "I am unfamiliar with the noun '$<noun2>'.";
                succeed;
            }
            unless player_can_see($receiver) {
                say "You see no $<noun2> here.";
                succeed;
            }

            unless $thing ~~ Takable {
                say "You can't move the $noun1.";
                succeed;
            }

            if $<prep> eq "in" {
                unless $receiver ~~ Container {
                    say "You can't put things in the $<noun2>.";
                    succeed;
                }
                unless player_can_see_inside($receiver) {
                    $receiver.open;
                }
                say "You put the $noun1 in the $<noun2>.";
            }
            elsif $<prep> eq "on" {
                unless $receiver ~~ Platform {
                    say "You can't put things on the $<noun2>.";
                    succeed;
                }
                say "You put the $noun1 on the $<noun2>.";
            }
            $thing.put($receiver);
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
            say "Type 'help' for suggestions.";
        }
    }
}
