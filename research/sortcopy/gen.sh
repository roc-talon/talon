#!/usr/bin/env bash
# Write one repro file: gen.sh <kind> <N> > file.roc
# Each of the N call sites sorts a list made from `rows` with List.sort_with.
#   named:    element U64 at each site, one named comparator (a pure duplicate)
#   inline:   element U64 at each site, the same comparator written inline at each site
#   distinct: element U64 at each site, a different comparator at each site
#   samesize: site i sorts records { a<i> : U64, b<i> : U64 } (new type, same layout)
#   types:    site i sorts tuples of i + 1 U64 (new type, new size)
kind=$1; n=$2
[ "$kind" = named ] && printf 'cmp = |x, y| x.order_relative_to(y)\n\n'
printf 'main! = |args| {\n\trows : List(U64)\n\trows = args.map(|s| s.count_utf8_bytes())\n\tvar $total = rows.len()\n'
for i in $(seq 1 "$n"); do
  case $kind in
    named) e="rows.append($i).sort_with(cmp).first() ?? 0" ;;
    inline) e="rows.append($i).sort_with(|x, y| x.order_relative_to(y)).first() ?? 0" ;;
    distinct) e="rows.append($i).sort_with(|x, y| (x % $((i + 1))).order_relative_to(y % $((i + 1)))).first() ?? 0" ;;
    samesize) e="rows.map(|x| { a$i: x, b$i: $i }).sort_with(|x, y| x.a$i.order_relative_to(y.a$i)).first().map_ok(|r| r.b$i) ?? 0" ;;
    types) t="x"; for j in $(seq 1 "$i"); do t="$t, x + $j"; done
      e="rows.map(|x| ($t)).sort_with(|x, y| x.0.order_relative_to(y.0)).first().map_ok(|r| r.1) ?? 0" ;;
  esac
  printf '\t$total = $total + (%s)\n' "$e"
done
printf '\techo!(Str.inspect($total))\n\tOk({})\n}\n'
