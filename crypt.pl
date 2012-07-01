use Test;

role Event {
    method Str {
        sub event() { self.^name }
        sub name($attr) { $attr.name.substr(2) }
        sub value($attr) { $attr.get_value(self) }

        "{event}[{map { ":{name $_}<{value $_}>" }, self.^attributes}]"
    }
}

class DiskMoved does Event {
    has $.size;
    has $.from;
    has $.to;
}

class HanoiGame {
    method move($from, $to) {
        DiskMoved.new(:size<tiny>, :$from, :$to);
    }
}

multi MAIN('test', 'hanoi') {
    my $game = HanoiGame.new();

    is $game.move('left', 'middle'),
       DiskMoved.new(:size<tiny>, :from<left>, :to<middle>),
       'legal move (+)';

    done;
}
