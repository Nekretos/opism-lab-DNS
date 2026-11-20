#!/bin/bash
# DNS lab se-201-11: runs tasks 2-7 per the handout, logs every command and its output to lablog/
cd "$(dirname "$0")"
SID=se-201-11; Z=$SID.lab
ZF=stand/students/$SID/zone/$Z.zone
C="docker compose -f stand/compose.yaml"
L=lablog; mkdir -p $L
RELOAD="named-checkzone $Z /lab/zone/$Z.zone && rndc reload $Z"
CHECK="named-checkzone $Z /lab/zone/$Z.zone"

st(){ local cmd="$1" lbl="${2:-$1}"; echo "root@ns-$SID:/lab/zone# $lbl"; $C exec -T $SID bash -c "$cmd" 2>&1; echo; }
hst(){ echo "@codespace:/workspaces/opism-lab-DNS\$ $1"; bash -c "$1" 2>&1; echo; }
bump(){ python3 - "$ZF" <<'P'
import re,sys
p=sys.argv[1]; s=open(p).read()
s=re.sub(r'(\d{10})(\s*; serial)', lambda m: str(int(m.group(1))+1)+m.group(2), s, count=1)
open(p,'w').write(s)
P
grep -m1 'serial' "$ZF"; }
note(){ echo "### $*"; }

t2(){
st "dig -v"
st "dig @10.53.0.2 ns.$Z A +norec"
st "dig @10.53.0.3 ns.$Z A +norec"
st "dig @10.53.1.1 ns.$Z A +norec"
st "dig ns.$Z A +trace"
st "dig @10.53.0.3 $Z NS +norec"
st "dig @10.53.1.1 $Z NS +norec"
}

t3(){
note "zone-edit: додано записи з картки, serial +1"
cat >> "$ZF" <<EOF
www            IN A      10.53.0.80
status         IN CNAME  www
mail           IN A      10.53.0.80
@              IN MX     30 mail
@              IN TXT    "lab-token=c4d4a729"
lab       25   IN A      10.53.0.81
EOF
bump
st "$RELOAD" "zone-reload"
st "dig @10.53.1.1 www.$Z A +norec"
st "dig @10.53.1.1 status.$Z CNAME +norec"
st "dig @10.53.1.1 mail.$Z A +norec"
st "dig @10.53.1.1 $Z MX +norec"
st "dig @10.53.1.1 $Z TXT +norec"
st "dig @10.53.1.1 lab.$Z A +norec"
note "Порівняння резолвер / власний сервер"
st "dig status.$Z"
st "dig @10.53.1.1 status.$Z +norec"
st "dig $Z MX"
st "dig @10.53.1.1 $Z MX +norec"
note "Тимчасово додано '@ IN CNAME www'"
echo "@              IN CNAME  www" >> "$ZF"
st "$CHECK" "zone-check"
sed -i '$d' "$ZF"
note "Рядок видалено, перевірка:"
st "$CHECK" "zone-check"
}

t12(){
st "curl -sv 'http://www.$Z/search/reports?q=97&limit=uk#top'"
st "curl -sv 'http://status.$Z:80/reports/?q=%D0%BA%D0%B8%D1%97%D0%B2'"
st "curl -sv 'http://user:pass@lab.$Z/search#section-2'"
AUTH=$($C exec -T $SID curl -sv "http://user:pass@lab.$Z/search" 2>&1 | grep -i '^> Authorization' | awk '{print $NF}' | tr -d '\r')
st "echo '$AUTH' | base64 -d; echo"
st "curl -v --max-time 15 'https://www.$Z:4443/search/../reports'"
st "curl -s 'http://www.$Z/search/../reports'"
st "curl -s --path-as-is 'http://www.$Z/search/../reports'"
}

t4(){
st "dig www.$Z +noall +answer"
sleep 5
st "dig www.$Z +noall +answer"
note "Крок 3: zone-edit www -> 10.53.0.81, serial +1, БЕЗ zone-reload"
sed -i 's/^www\( *\)IN A      10.53.0.80/www\1IN A      10.53.0.81/' "$ZF"
grep '^www' "$ZF"; bump
st "dig @10.53.1.1 www.$Z +norec +short"
note "Крок 4"
while :; do
  out=$(st "date +%T; dig www.$Z +noall +answer"); echo "$out"
  R=$(echo "$out" | awk '$4=="A"{print $2; exit}')
  [ -n "$R" ] && [ "$R" -ge 30 ] && break
  note "R=$R < 30 с: чекаю спливання запису і повторюю крок 4"; sleep $(( ${R:-0} + 1 ))
done
note "Крок 5"
st "$RELOAD; date +%T" "zone-reload; date +%T"
st "dig @10.53.1.1 www.$Z +norec +short"
note "Крок 7: цикл спостереження"
st "while true; do a=\$(dig +short www.$Z); echo \"\$(date +%T) \$a\"; [ \"\$a\" = 10.53.0.81 ] && break; sleep 2; done" \
   "while true; do echo \"\$(date +%T) \$(dig +short www.$Z)\"; sleep 2; done"
st "curl http://www.$Z/"
}

t5(){
local N=$1
note "Крок 2: zone-edit додано '$N IN A 10.53.0.80', serial +1, БЕЗ zone-reload"
grep -q "^$N " "$ZF" || echo "$N      IN A      10.53.0.80" >> "$ZF"
bump
st "dig @10.53.1.1 $N.$Z +norec"
note "Крок 3"
st "date +%T; dig $N.$Z"
note "Крок 4"
st "$RELOAD; date +%T" "zone-reload; date +%T"
st "dig @10.53.1.1 $N.$Z +norec +short"
note "Крок 6"
st "while true; do s=\$(dig $N.$Z +noall +comments | grep -o 'status: [A-Z]*'); echo \"\$(date +%T) \$s\"; [ \"\$s\" = 'status: NOERROR' ] && break; sleep 2; done" \
   "while true; do echo \"\$(date +%T) \$(dig $N.$Z +noall +comments | grep -o 'status: [A-Z]*')\"; sleep 2; done"
}

t6(){
st 'A=y$RANDOM.'$Z'; echo $A; dig $A | grep "Query time"; dig $A | grep "Query time"'
st 'B=x$RANDOM.lab; echo $B; dig $B | grep "Query time"; dig $B | grep "Query time"'
st 'C=x$RANDOM.zz$RANDOM; echo $C; dig $C | grep "Query time"; dig $C | grep "Query time"'
note "Рядок D"
hst "date +%T; $C restart resolver-a"
sleep 5
st "date +%T; dig www.$Z | grep 'Query time'; dig www.$Z | grep 'Query time'"
note "Журнали"
hst "$C exec -T root tail -n 25 /var/log/named/queries.log"
hst "$C exec -T tld tail -n 25 /var/log/named/queries.log"
st "tail -n 25 /var/log/named/queries.log" "querylog"
note "curl time_namelookup після повторного перезапуску"
hst "$C restart resolver-a"
sleep 5
st "curl -so /dev/null -w '%{time_namelookup}\n' http://www.$Z/"
}

t7(){
st "dig @10.53.0.53 lab.$Z +noall +answer"
st "dig @10.53.0.54 lab.$Z +noall +answer"
st "rndc stop; date +%T" "named-stop; date +%T"
st "sleep 35; date +%T" "sleep 35; date +%T"
st "time dig @10.53.0.53 lab.$Z +tries=1 +timeout=30"
st "time dig @10.53.0.53 lab.$Z +tries=1 +timeout=30"
st "time dig @10.53.0.54 lab.$Z +tries=1 +timeout=30"
st "named -u bind -c /lab/named.conf; date +%T" "named-start; date +%T"
st "while true; do a=\$(dig @10.53.0.53 lab.$Z +short +tries=1 +timeout=3); echo \"\$(date +%T) \$a\"; [ -n \"\$a\" ] && break; sleep 2; done" \
   "while true; do echo \"\$(date +%T) \$(dig @10.53.0.53 lab.$Z +short +tries=1 +timeout=3)\"; sleep 2; done"
st "dig @10.53.1.1 $Z SOA +norec +short"
}

t2  2>&1 | tee $L/02-hierarchy.txt
t3  2>&1 | tee $L/03-zone.txt
t12 2>&1 | tee $L/12-uri-check.txt
t4  2>&1 | tee $L/04-ttl.txt
t5 new-kljby 2>&1 | tee $L/05-negative.txt
if awk '/Крок 6/{f=1} f && /^[0-9][0-9]:[0-9][0-9]:[0-9][0-9] /{print; exit}' $L/05-negative.txt | grep -q NOERROR; then
  t5 new2-kljby 2>&1 | tee $L/05b-negative-repeat.txt
fi
t6  2>&1 | tee $L/06-latency.txt
t7  2>&1 | tee $L/07-incident.txt
cp "$ZF" $L/final.zone
echo ALL_DONE
