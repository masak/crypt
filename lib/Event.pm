role Event {
    method Str {
        sub name($attr) { $attr.name.substr(2) }
        sub value($attr) { $attr.get_value(self) }
        sub attrpair($attr) { ":{name $attr}<{value $attr}>" }

        sprintf '%s[%s]', self.^name, ~map &attrpair, self.^attributes;
    }
}
