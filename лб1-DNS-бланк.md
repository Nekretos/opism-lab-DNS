<!--
Бланк звіту до лабораторної роботи «DNS».
Скопіювати цей файл у власний публічний репозиторій звіту як README.md і заповнити.
Коментарі такого вигляду в GitHub не відображаються; видаляти їх не обов'язково.
Вивід команд вставляти текстом у блоки коду, а не знімками екрана.
Порожні поля не допускаються: якщо щось не вдалося, записати, що саме і чому.
-->

# Лабораторна робота №1. DNS

| Поле | Значення |
|---|---|
| ПІБ | Тіщенко Микола Сергійович |
| Група | ЗКБЗІ 21 |
| Ідентифікатор (`sNN`) | `se-201-11` |
| Дата виконання | 20.11.2026 |
| Середовище | GitHub Codespaces (форк `Nekretos/opism-lab-DNS`) |
| Версія `dig` | `DiG 9.18.39-0ubuntu0.24.04.9-Ubuntu` |

> Час у виводах — UTC (годинник codespace), за Києвом це +2 год. Команди завдань 2–7 виконано послідовно скриптом `lab.sh` (лежить у форку стенда). 
Скрипт запускає кожну команду методички всередині контейнера `se-201-11` і пише вивід у `lablog/`. Псевдоніми `zone-reload`, `zone-check`, `named-stop` 
і `named-start` у скрипті розгорнуто у відповідні команди `named-checkzone` / `rndc` / `named`. Цикли спостереження зупиняються автоматично на першому рядку з новим результатом.

## Параметри варіанта

| Параметр | Значення |
|---|---|
| `$TTL`, с | 45 |
| TTL запису SOA, с | 15 |
| Поле `minimum` SOA, с | 90 |
| Псевдонім (CNAME на `www`) | `status` |
| Другий хост і його TTL, с | `lab`, 25 |
| Пріоритет MX | 30 |
| Токен TXT | `c4d4a729` |
| Ім'я для завдання 5 | `new-kljby` |

## Завдання 1. Складові URI

URI з картки:

1. `http://www.se-201-11.lab/search/reports?q=97&limit=uk#top`
2. `http://status.se-201-11.lab:80/reports/?q=%D0%BA%D0%B8%D1%97%D0%B2`
3. `http://user:pass@lab.se-201-11.lab/search#section-2`
4. `https://www.se-201-11.lab:4443/search/../reports`
5. `mailto:admin@se-201-11.lab?subject=search`

### 1.1. Розбір

| № | scheme | userinfo | host | port | path | query | fragment |
|---|---|---|---|---|---|---|---|
| 1 | `http` | — | `www.se-201-11.lab` | 80 (за замовч.) | `/search/reports` | `q=97&limit=uk` | `top` |
| 2 | `http` | — | `status.se-201-11.lab` | 80 | `/reports/` | `q=%D0%BA%D0%B8%D1%97%D0%B2` | — |
| 3 | `http` | `user:pass` | `lab.se-201-11.lab` | 80 (за замовч.) | `/search` | — | `section-2` |
| 4 | `https` | — | `www.se-201-11.lab` | 4443 | `/search/../reports` | — | — |
| 5 | `mailto` | — | — | — | `admin@se-201-11.lab` | `subject=search` | — |

| № | Ім'я, що запитується в DNS | Заголовок `Host` | Ціль запиту (request target) |
|---|---|---|---|
| 1 | `www.se-201-11.lab` | `www.se-201-11.lab` | `/search/reports?q=97&limit=uk` |
| 2 | `status.se-201-11.lab` (CNAME → `www.se-201-11.lab`) | `status.se-201-11.lab:80` | `/reports/?q=%D0%BA%D0%B8%D1%97%D0%B2` |
| 3 | `lab.se-201-11.lab` | `lab.se-201-11.lab` | `/search` |
| 4 | `www.se-201-11.lab` | `www.se-201-11.lab:4443` | `/reports` (після вилучення сегментів `..` за RFC 3986, п. 5.2.4) |
| 5 | сам URI запиту в DNS не створює; поштовий клієнт запитав би MX для `se-201-11.lab` | — (не HTTP) | — (не HTTP) |

Фрагмент (`#top`, `#section-2`) обробляє лише клієнт, на сервер він не надсилається. Тому його немає ні в `Host`, ні в цілі запиту.

Декодоване значення параметра URI 2: `q=київ`. Байти UTF-8: `D0 BA` = к, `D0 B8` = и, `D1 97` = ї, `D0 B2` = в.

Чому URI 5 не має складової host, хоча містить символ `@`: за RFC 3986 складова authority (а з нею userinfo і host) існує лише тоді, коли після `scheme:` іде `//`. У `mailto:` цих слешів немає, тож усе до `?` є path. За RFC 6068 це поштова адреса `admin@se-201-11.lab`, де `@` належить самій адресі й не відділяє userinfo від host.

### 1.2. Перевірка (після завдання 3)

```text
root@ns-se-201-11:/lab/zone# curl -sv 'http://www.se-201-11.lab/search/reports?q=97&limit=uk#top'
* IPv4: 10.53.0.80
* Connected to www.se-201-11.lab (10.53.0.80) port 80
> GET /search/reports?q=97&limit=uk HTTP/1.1
> Host: www.se-201-11.lab
server: web-a
Host: www.se-201-11.lab
request URI: /search/reports?q=97&limit=uk
path: /search/reports
query: q=97&limit=uk

root@ns-se-201-11:/lab/zone# curl -sv 'http://status.se-201-11.lab:80/reports/?q=%D0%BA%D0%B8%D1%97%D0%B2'
* IPv4: 10.53.0.80
* Connected to status.se-201-11.lab (10.53.0.80) port 80
> GET /reports/?q=%D0%BA%D0%B8%D1%97%D0%B2 HTTP/1.1
> Host: status.se-201-11.lab
server: web-a
Host: status.se-201-11.lab
request URI: /reports/?q=%D0%BA%D0%B8%D1%97%D0%B2
path: /reports/
query: q=%D0%BA%D0%B8%D1%97%D0%B2

root@ns-se-201-11:/lab/zone# curl -sv 'http://user:pass@lab.se-201-11.lab/search#section-2'
* IPv4: 10.53.0.81
* Connected to lab.se-201-11.lab (10.53.0.81) port 80
* Server auth using Basic with user 'user'
> GET /search HTTP/1.1
> Host: lab.se-201-11.lab
> Authorization: Basic dXNlcjpwYXNz
server: web-b
Host: lab.se-201-11.lab
request URI: /search
path: /search
query: 
```

Значення заголовка `Authorization` і результат декодування:

```text
> Authorization: Basic dXNlcjpwYXNz
root@ns-se-201-11:/lab/zone# echo 'dXNlcjpwYXNz' | base64 -d; echo
user:pass
```

URI 4: етап, на якому запит не вдається (пошук імені / TCP / TLS), і рядки виводу, що це підтверджують:

```text
root@ns-se-201-11:/lab/zone# curl -v --max-time 15 'https://www.se-201-11.lab:4443/search/../reports'
* Host www.se-201-11.lab:4443 was resolved.
* IPv4: 10.53.0.80
*   Trying 10.53.0.80:4443...
* connect to 10.53.0.80 port 4443 from 10.53.1.1 port 40568 failed: Connection refused
* Failed to connect to www.se-201-11.lab port 4443 after 1 ms: Couldn't connect to server
curl: (7) Failed to connect to www.se-201-11.lab port 4443 after 1 ms: Couldn't connect to server
```

Запит не вдається на етапі **TCP**. Ім'я розв'язалося (`was resolved`, `IPv4: 10.53.0.80`), а спроба з'єднання з портом 4443 отримала `Connection refused`: на вебсервері цей порт ніхто не слухає. До TLS справа не дійшла, рядків рукостискання (`TLS handshake`) у виводі немає.

```text
root@ns-se-201-11:/lab/zone# curl -s 'http://www.se-201-11.lab/search/../reports'
request URI: /reports
path: /reports
root@ns-se-201-11:/lab/zone# curl -s --path-as-is 'http://www.se-201-11.lab/search/../reports'
request URI: /search/../reports
path: /reports
```

| Запит | `request URI`, отриманий сервером | `path`, отриманий сервером |
|---|---|---|
| звичайний | `/reports` | `/reports` |
| `--path-as-is` | `/search/../reports` | `/reports` |

Розбіжності між URI та тим, що отримав сервер, і їх пояснення:

- **Фрагменти** `#top` і `#section-2` до сервера не дійшли. Фрагмент — клієнтська частина URI, у HTTP-запит він не входить.
- **URI 2:** у таблиці 1.1 я очікував `Host: status.se-201-11.lab:80`, а curl надіслав `Host: status.se-201-11.lab`. Порт 80 для `http` стандартний, а RFC 9110 дозволяє не вказувати порт за замовчуванням, тому curl його опустив. Параметр `query` прийшов у percent-кодуванні, без декодування.
- **URI 2 і DNS:** ім'я `status` — це CNAME на `www`. Тому з'єднання пішло на ту саму адресу 10.53.0.80 (web-a), але в `Host` лишилося ім'я з URI, а не ціль CNAME.
- **URI 3:** userinfo `user:pass` у запит як частина URI не потрапив. curl перетворив його на заголовок `Authorization: Basic` (base64 від `user:pass`), а `Host` містить лише ім'я хоста. Запит обслужив web-b, бо `lab` → 10.53.0.81.
- **URI 4 / `--path-as-is`:** без параметра curl сам вилучив сегмент `..` (RFC 3986, п. 5.2.4) і надіслав `/reports`. З `--path-as-is` сервер отримав сирий `/search/../reports`, але nginx нормалізував шлях, і `path` (`$uri`) у обох випадках `/reports`.

## Завдання 2. Проходження ієрархії вручну

```text
root@ns-se-201-11:/lab/zone# dig @10.53.0.2 ns.se-201-11.lab A +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 25273
;; flags: qr; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2
;; AUTHORITY SECTION:
lab.			172800	IN	NS	ns1.nic.lab.
;; ADDITIONAL SECTION:
ns1.nic.lab.		172800	IN	A	10.53.0.3
;; Query time: 79 msec
;; SERVER: 10.53.0.2#53(10.53.0.2) (UDP)

root@ns-se-201-11:/lab/zone# dig @10.53.0.3 ns.se-201-11.lab A +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 43369
;; flags: qr; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2
;; AUTHORITY SECTION:
se-201-11.lab.		3600	IN	NS	ns.se-201-11.lab.
;; ADDITIONAL SECTION:
ns.se-201-11.lab.	3600	IN	A	10.53.1.1
;; Query time: 80 msec
;; SERVER: 10.53.0.3#53(10.53.0.3) (UDP)

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 ns.se-201-11.lab A +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 9347
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 1
;; ANSWER SECTION:
ns.se-201-11.lab.	45	IN	A	10.53.1.1
;; AUTHORITY SECTION:
se-201-11.lab.		45	IN	NS	ns.se-201-11.lab.
;; Query time: 0 msec
;; SERVER: 10.53.1.1#53(10.53.1.1) (UDP)
```

| Сервер | status | flags | ANSWER | AUTHORITY | ADDITIONAL |
|---|---|---|---|---|---|
| 10.53.0.2 | NOERROR | `qr` | 0 | 1: `lab. NS ns1.nic.lab.` | 2: `ns1.nic.lab. A 10.53.0.3` + OPT (EDNS) |
| 10.53.0.3 | NOERROR | `qr` | 0 | 1: `se-201-11.lab. NS ns.se-201-11.lab.` | 2: `ns.se-201-11.lab. A 10.53.1.1` + OPT |
| 10.53.1.1 | NOERROR | `qr aa` | 1: `ns.se-201-11.lab. A 10.53.1.1` | 1: `se-201-11.lab. NS ns.se-201-11.lab.` | 1: лише OPT |

Вивід `dig ns.se-201-11.lab A +trace`:

```text
root@ns-se-201-11:/lab/zone# dig ns.se-201-11.lab A +trace
.			86290	IN	NS	a.root-servers.net.
;; Received 59 bytes from 10.53.0.53#53(10.53.0.53) in 1 ms

lab.			172800	IN	NS	ns1.nic.lab.
;; Received 117 bytes from 10.53.0.2#53(a.root-servers.net) in 80 ms

se-201-11.lab.		3600	IN	NS	ns.se-201-11.lab.
;; Received 103 bytes from 10.53.0.3#53(ns1.nic.lab) in 40 ms

ns.se-201-11.lab.	45	IN	A	10.53.1.1
se-201-11.lab.		45	IN	NS	ns.se-201-11.lab.
;; Received 103 bytes from 10.53.1.1#53(ns.se-201-11.lab) in 1 ms
```

Ланцюжок `+trace` збігається з ручним: резолвер (лише список кореневих серверів) → root 10.53.0.2 (відсилання на `lab.`) → TLD 10.53.0.3 (відсилання на `se-201-11.lab.`) → власний сервер 10.53.1.1 (відповідь). Час кроків (80 мс, 40 мс, 1 мс) збігається з `Query time` ручних запитів.

```text
root@ns-se-201-11:/lab/zone# dig @10.53.0.3 se-201-11.lab NS +norec
;; flags: qr; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 2
;; AUTHORITY SECTION:
se-201-11.lab.		3600	IN	NS	ns.se-201-11.lab.
;; ADDITIONAL SECTION:
ns.se-201-11.lab.	3600	IN	A	10.53.1.1

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 se-201-11.lab NS +norec
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 2
;; ANSWER SECTION:
se-201-11.lab.		45	IN	NS	ns.se-201-11.lab.
;; ADDITIONAL SECTION:
ns.se-201-11.lab.	45	IN	A	10.53.1.1
```

| Запит | TTL запису NS | Прапорець `aa` | Секція, у якій міститься NS |
|---|---|---|---|
| `dig @10.53.0.3 se-201-11.lab NS +norec` | 3600 | немає | AUTHORITY |
| `dig @10.53.1.1 se-201-11.lab NS +norec` | 45 | є | ANSWER |

1. Які відповіді є відсиланнями і за якими ознаками це визначено?

   Відсилання (referral) — це відповіді root (10.53.0.2) і TLD (10.53.0.3). Ознаки: `status: NOERROR`, але `ANSWER: 0`; у прапорцях немає `aa`; в AUTHORITY лежить NS-запис для зони нижчого рівня (`lab.`, потім `se-201-11.lab.`), а не відповідь на запитане ім'я. Сервер ніби каже: «не знаю, спитай ось цього». Відповідь 10.53.1.1 кінцева: прапорець `aa` і запис A у ANSWER.

2. Для чого у відповіді TLD присутній запис у секції ADDITIONAL і що сталося б, якби його не було?

   `ns.se-201-11.lab. A 10.53.1.1` — це glue-запис. Ім'я сервера зони `ns.se-201-11.lab` лежить усередині самої зони `se-201-11.lab`. Щоб дізнатися його адресу, довелося б спитати сервер зони, адреса якого невідома. Без glue резолвер потрапив би в замкнене коло, і ім'я не розв'язалося б (SERVFAIL).

3. Яка з двох копій запису NS є авторитативною і чому?

   Авторитативна копія з власного сервера 10.53.1.1: відповідь має прапорець `aa`, NS лежить у ANSWER, TTL 45 узято з `$TTL` файлу зони. Копія на TLD (TTL 3600, без `aa`, у AUTHORITY) — це лише делегування в батьківській зоні `lab.`. Батьківська зона не є власником даних дочірньої, тому вона не авторитативна для NS-набору `se-201-11.lab`.

## Завдання 3. Заповнення власної зони

Додані записи (нижче рядка `; ---- add records ...`), serial збільшено до `2026112002`:

```text
www            IN A      10.53.0.80
status         IN CNAME  www
mail           IN A      10.53.0.80
@              IN MX     30 mail
@              IN TXT    "lab-token=c4d4a729"
lab       25   IN A      10.53.0.81
```

Вивід `zone-reload`:

```text
root@ns-se-201-11:/lab/zone# zone-reload
zone se-201-11.lab/IN: loaded serial 2026112002
OK
zone reload queued
```

<!-- Шість запитів до 10.53.1.1 з +norec, по одному на кожен рядок таблиці картки. -->

```text
root@ns-se-201-11:/lab/zone# dig @10.53.1.1 www.se-201-11.lab A +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49379
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2
www.se-201-11.lab.	45	IN	A	10.53.0.80

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 status.se-201-11.lab CNAME +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 65382
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2
status.se-201-11.lab.	45	IN	CNAME	www.se-201-11.lab.

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 mail.se-201-11.lab A +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 27534
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2
mail.se-201-11.lab.	45	IN	A	10.53.0.80

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 se-201-11.lab MX +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 55960
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 3
se-201-11.lab.		45	IN	MX	30 mail.se-201-11.lab.

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 se-201-11.lab TXT +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 37713
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2
se-201-11.lab.		45	IN	TXT	"lab-token=c4d4a729"

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 lab.se-201-11.lab A +norec
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 26411
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 2
lab.se-201-11.lab.	25	IN	A	10.53.0.81
```

| Запис | status | Прапорець `aa` | Значення в ANSWER | TTL | Відповідає картці (так/ні) |
|---|---|---|---|---|---|
| `www` A | NOERROR | є | `10.53.0.80` | 45 | так |
| псевдонім CNAME | NOERROR | є | `www.se-201-11.lab.` | 45 | так |
| `mail` A | NOERROR | є | `10.53.0.80` | 45 | так |
| `@` MX | NOERROR | є | `30 mail.se-201-11.lab.` | 45 | так |
| `@` TXT | NOERROR | є | `"lab-token=c4d4a729"` | 45 | так |
| другий хост A | NOERROR | є | `10.53.0.81` | 25 | так |

Порівняння відповідей резолвера та власного сервера:

```text
root@ns-se-201-11:/lab/zone# dig status.se-201-11.lab
;; flags: qr rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 0, ADDITIONAL: 1
;; ANSWER SECTION:
status.se-201-11.lab.	45	IN	CNAME	www.se-201-11.lab.
www.se-201-11.lab.	45	IN	A	10.53.0.80
;; SERVER: 10.53.0.53#53(10.53.0.53) (UDP)

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 status.se-201-11.lab +norec
;; flags: qr aa; QUERY: 1, ANSWER: 2, AUTHORITY: 1, ADDITIONAL: 2
;; ANSWER SECTION:
status.se-201-11.lab.	45	IN	CNAME	www.se-201-11.lab.
www.se-201-11.lab.	45	IN	A	10.53.0.80
;; AUTHORITY SECTION:
se-201-11.lab.		45	IN	NS	ns.se-201-11.lab.
;; ADDITIONAL SECTION:
ns.se-201-11.lab.	45	IN	A	10.53.1.1

root@ns-se-201-11:/lab/zone# dig se-201-11.lab MX
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; ANSWER SECTION:
se-201-11.lab.		45	IN	MX	30 mail.se-201-11.lab.
;; SERVER: 10.53.0.53#53(10.53.0.53) (UDP)

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 se-201-11.lab MX +norec
;; flags: qr aa; QUERY: 1, ANSWER: 1, AUTHORITY: 1, ADDITIONAL: 3
;; ANSWER SECTION:
se-201-11.lab.		45	IN	MX	30 mail.se-201-11.lab.
;; AUTHORITY SECTION:
se-201-11.lab.		45	IN	NS	ns.se-201-11.lab.
;; ADDITIONAL SECTION:
mail.se-201-11.lab.	45	IN	A	10.53.0.80
ns.se-201-11.lab.	45	IN	A	10.53.1.1
```

| Запит | flags | ANSWER (кількість, типи) | AUTHORITY (кількість, типи) | ADDITIONAL (кількість, типи) | TTL |
|---|---|---|---|---|---|
| псевдонім через resolver-a | `qr rd ra` | 2: CNAME, A | 0 | 1: лише OPT | 45 / 45 |
| псевдонім через 10.53.1.1 | `qr aa` | 2: CNAME, A | 1: NS | 2: A (`ns`), OPT | 45 / 45 / 45 |
| MX через resolver-a | `qr rd ra` | 1: MX | 0 | 1: лише OPT | 45 |
| MX через 10.53.1.1 | `qr aa` | 1: MX | 1: NS | 3: A (`mail`), A (`ns`), OPT | 45 |

> `dig` зараховує до ADDITIONAL і псевдозапис OPT (EDNS), тому «1» у резолвера означає, що справжніх записів там немає.

Пояснення відмінностей:

- **Прапорці.** Авторитативний сервер ставить `aa`: він власник даних. Резолвер не авторитативний, тому `aa` немає, зате є `ra` (рекурсія доступна) і `rd` (рекурсію запитав клієнт; з `+norec` `rd` немає).
- **Секції AUTHORITY і ADDITIONAL.** Авторитативний сервер додає NS своєї зони та адреси (`ns`, а для MX ще й `mail`) як допоміжні дані. Unbound за замовчуванням віддає мінімальну відповідь, лише ANSWER, бо клієнту-стабу делегування не потрібне.
- **TTL.** Усі значення 45 з `$TTL`. У резолвера TTL дорівнює 45, бо запис щойно потрапив у кеш; при повторних запитах він зменшується (див. завдання 4).

Повідомлення `zone-check` після тимчасового додавання `@ IN CNAME www`:

```text
root@ns-se-201-11:/lab/zone# zone-check
dns_master_load: /lab/zone/se-201-11.lab.zone:21: se-201-11.lab: CNAME and other data
zone se-201-11.lab/IN: loading from master file /lab/zone/se-201-11.lab.zone failed: CNAME and other data
zone se-201-11.lab/IN: not loaded due to errors.
```

Рядок одразу видалено, повторний `zone-check`: `zone se-201-11.lab/IN: loaded serial 2026112002 OK`.

1. Який TTL має кожен запис зони і звідки це значення взято?

   | Запис | TTL, с | Джерело |
   |---|---|---|
   | `@ SOA` | 15 | явно в рядку SOA |
   | `@ NS`, `ns A`, `www A`, `status CNAME`, `mail A`, `@ MX`, `@ TXT`, `new-kljby A` | 45 | директива `$TTL 45` (TTL у рядку не вказано) |
   | `lab A` | 25 | явно в рядку (`lab 25 IN A`), як вимагає картка |

2. Скільки записів містить секція ANSWER у відповіді на запит псевдоніма і чому?

   Два: `status CNAME www.se-201-11.lab.` і `www A 10.53.0.80`. Запитано тип A, а для `status` існує лише CNAME. Сервер повертає CNAME і, оскільки ціль (`www`) лежить у тій самій зоні, одразу додає її запис A, щоб клієнт не робив другого запиту. Резолвер теж іде за ланцюжком CNAME до кінцевої адреси. Якщо запитати саме тип CNAME, у ANSWER буде один запис (див. таблицю вище).

3. Чому запис CNAME неможливо розмістити для імені `@`?

   CNAME означає, що це ім'я — повний псевдонім іншого, і жодних інших записів у нього бути не може (RFC 1034, п. 3.6.2; RFC 2181, п. 10.1). Вершина зони `@` зобов'язана мати SOA і NS, тож CNAME там завжди конфліктує з іншими даними. Саме це й показав `zone-check`: `CNAME and other data`, зона не завантажується.

## Завдання 4. TTL і видимість змін

Два запити з інтервалом 5 с:

```text
root@ns-se-201-11:/lab/zone# dig www.se-201-11.lab +noall +answer
www.se-201-11.lab.	43	IN	A	10.53.0.80

root@ns-se-201-11:/lab/zone# dig www.se-201-11.lab +noall +answer
www.se-201-11.lab.	38	IN	A	10.53.0.80
```

TTL у кеші резолвера зменшився з 43 до 38 за 5 с і менший за `$TTL` = 45: це залишок часу життя запису в кеші, а не значення з файлу зони. Запис потрапив у кеш раніше, під час завдання 1.2.

**Прогноз** (записати до вимірювання). Формула часу появи нової адреси через залишок R, найбільша можлива затримка:

- `t_нова = t_зміни + R`, затримка `Δt = R`: резолвер віддає кешовану стару адресу, доки не спливе залишок R, і лише потім питає авторитативний сервер знову.
- Найбільша можлива затримка: `Δt_max = TTL = 45 с`, якщо запис закешовано саме в момент зміни.
- З урахуванням циклу спостереження з кроком 2 с нову адресу буде помічено в межах `R … R + 2 с`.

Перевірка, що сервер до `zone-reload` повертає стару адресу:

```text
www            IN A      10.53.0.81      <- рядок у файлі зони після zone-edit, serial 2026112003
root@ns-se-201-11:/lab/zone# dig @10.53.1.1 www.se-201-11.lab +norec +short
10.53.0.80
```

Залишок R і час (крок 4), час `zone-reload` (крок 5), перевірка на сервері (крок 6):

```text
root@ns-se-201-11:/lab/zone# date +%T; dig www.se-201-11.lab +noall +answer
13:48:20
www.se-201-11.lab.	38	IN	A	10.53.0.80

root@ns-se-201-11:/lab/zone# zone-reload; date +%T
zone se-201-11.lab/IN: loaded serial 2026112003
OK
zone reload queued
13:48:20

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 www.se-201-11.lab +norec +short
10.53.0.81
```

Очікуваний час появи нової адреси (підставити R у формулу): R = 38 с (≥ 30 с, повтор кроку 4 не потрібен), `t_нова = 13:48:20 + 38 с = 13:48:58`.

Вивід циклу спостереження (перші два рядки, два останні рядки зі старою адресою, рядок з новою адресою):

```text
root@ns-se-201-11:/lab/zone# while true; do echo "$(date +%T) $(dig +short www.se-201-11.lab)"; sleep 2; done
13:48:21 10.53.0.80
13:48:23 10.53.0.80
...
13:48:55 10.53.0.80
13:48:57 10.53.0.80
13:48:59 10.53.0.81
```

Рядок `server:` з відповіді `curl`:

```text
root@ns-se-201-11:/lab/zone# curl http://www.se-201-11.lab/
server: web-b
Host: www.se-201-11.lab
```

| Час зміни | Очікуваний час | Спостережений час | Виміряна затримка, с | Прогноз, с |
|---|---|---|---|---|
| 13:48:20 | 13:48:58 | 13:48:59 | 39 | 38 |

1. Чим пояснюється розбіжність між прогнозом і виміряним значенням?

   Розбіжність 1 с, і вона в межах точності методу. (а) Цикл опитує раз на 2 с: о 13:48:57 запис ще жив (залишок ≈ 1 с), а наступна перевірка відбулася лише о 13:48:59. (б) `dig` показує TTL цілими секундами, тож реальний залишок міг бути 38,x с. (в) Після спливання запису резолвер ще має сходити до авторитативного сервера, це кілька мілісекунд. За журналом власного сервера новий запит від 10.53.0.53 прийшов о 13:48:59.588.

2. Якою була б найбільша можлива затримка для цього запису і за яких умов?

   45 с, тобто повний `$TTL`: якщо резолвер закешував запис безпосередньо перед `zone-reload`. Якщо між клієнтом і авторитативним сервером кілька рівнів кешу (резолвер провайдера, локальний кеш ОС, браузер), затримки можуть накладатися, а клієнти, що порушують TTL, тримають запис ще довше.

3. Як слід діяти, щоб перенести сервіс на нову адресу, якщо TTL запису становить 86 400 с?

   Заздалегідь, щонайменше за 86 400 с до переїзду, знизити TTL запису, наприклад до 60–300 с, і дочекатися, поки старе довге значення спливе в усіх кешах. Потім змінити адресу: тепер вона пошириться за хвилини. Деякий час тримати сервіс на обох адресах, перевірити журнали старого сервера, що трафік пішов, і лише тоді повернути TTL до великого значення.

## Завдання 5. Негативне кешування

**Прогноз** (записати до вимірювання). Формула за RFC 2308 і розраховане значення:

`TTL_neg = min(TTL запису SOA, SOA.minimum) = min(15, 90) = 15 с` (RFC 2308, п. 5). Отже, після створення запису resolver-a ще до 15 с відповідатиме NXDOMAIN; з циклом із кроком 2 с — 15…17 с.

Перевірка, що сервер до `zone-reload` повертає `NXDOMAIN`:

```text
new-kljby      IN A      10.53.0.80     <- додано zone-edit, serial 2026112004, zone-reload не виконано
root@ns-se-201-11:/lab/zone# dig @10.53.1.1 new-kljby.se-201-11.lab +norec
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 29364
;; flags: qr aa; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; AUTHORITY SECTION:
se-201-11.lab.		15	IN	SOA	ns.se-201-11.lab. admin.se-201-11.lab. 2026112003 3600 600 86400 90
```

Запит через resolver-a (крок 3), час `zone-reload` (крок 4), перевірка на сервері (крок 5):

```text
root@ns-se-201-11:/lab/zone# date +%T; dig new-kljby.se-201-11.lab
13:49:00
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 13225
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; AUTHORITY SECTION:
se-201-11.lab.		14	IN	SOA	ns.se-201-11.lab. admin.se-201-11.lab. 2026112003 3600 600 86400 90
;; SERVER: 10.53.0.53#53(10.53.0.53) (UDP)

root@ns-se-201-11:/lab/zone# zone-reload; date +%T
zone se-201-11.lab/IN: loaded serial 2026112004
OK
zone reload queued
13:49:00

root@ns-se-201-11:/lab/zone# dig @10.53.1.1 new-kljby.se-201-11.lab +norec +short
10.53.0.80
```

Вивід циклу спостереження (перші два рядки, останній рядок з `NXDOMAIN`, перший рядок з `NOERROR`):

```text
root@ns-se-201-11:/lab/zone# while true; do echo "$(date +%T) $(dig new-kljby.se-201-11.lab +noall +comments | grep -o 'status: [A-Z]*')"; sleep 2; done
13:49:00 status: NXDOMAIN
13:49:02 status: NXDOMAIN
...
13:49:14 status: NXDOMAIN
13:49:16 status: NOERROR
```

| Негативну відповідь закешовано | Запис створено | Ім'я резолвиться через resolver-a | Виміряно, с | Прогноз, с |
|---|---|---|---|---|
| 13:49:00 | 13:49:00 | 13:49:16 | 16 | 15 |

Повтор з іншим ім'ям не знадобився: перший рядок циклу показав `NXDOMAIN`.

1. Чому тривалість негативного кешування визначається записом SOA, а не записом, який запитували?

   Запитаного запису немає, тож немає й TTL, який можна було б узяти. Єдині дані, що їх сервер повертає разом із NXDOMAIN, — запис SOA зони в секції AUTHORITY. RFC 2308 визначає час кешування «відсутності» через нього: власник зони сам задає, як довго резолвери можуть пам'ятати, що імені немає.

2. Чи збігається TTL запису SOA в секції AUTHORITY з TTL запису SOA у файлі зони? Поясніть.

   Майже так. Авторитативний сервер повернув SOA з TTL 15, що дорівнює TTL SOA у файлі зони. За RFC 2308 сервер ставить у негативній відповіді `min(TTL SOA, minimum) = min(15, 90) = 15`. Тут це збігається з TTL SOA лише тому, що 15 < 90; якби TTL SOA був більшим за minimum, у відповіді стояв би minimum. Резолвер показав 14: це залишок у його кеші, на момент виводу вже минула частина секунди.

3. Скрипт розгортання перевіряє ім'я сервісу до створення запису, а потім одразу після. Що він побачить і як це виправити?

   Обидва рази він отримає NXDOMAIN. Перша перевірка закешувала негативну відповідь у резолвері на `min(TTL SOA, minimum)` секунд, тут 15 с, а в реальних зонах це часто 300–3600 с. Тому друга перевірка теж «не бачить» щойно створений запис, і розгортання помилково завершиться невдачею. Як виправити:
   - перевіряти запис безпосередньо на авторитативному сервері (`dig @ns +norec`), а не через резолвер;
   - не запитувати ім'я до створення;
   - повторювати перевірку з очікуванням, довшим за негативний TTL;
   - за потреби зменшити `minimum` / TTL SOA.

## Завдання 6. Затримка пошуку імені

**Прогноз** (записати до вимірювання). До яких серверів звернеться resolver-a:

| Ім'я | Перший запит | Повторний запит |
|---|---|---|
| A: нове ім'я у власній зоні | лише власний сервер 10.53.1.1 (делегування `lab.` і `se-201-11.lab.` уже в кеші) | жодного, негативна відповідь з кешу |
| B: нове ім'я в зоні `lab.` | лише TLD 10.53.0.3 (NS для `lab.` у кеші) | жодного, кеш |
| C: ім'я в неіснуючому TLD | лише root 10.53.0.2 (його NS у кеші, а такого TLD немає) | жодного, кеш |
| D: `www.se-201-11.lab` після перезапуску резолвера | root (priming `. NS` + запит), TLD, власний сервер | жодного, кеш |

Вивід вимірювань:

```text
root@ns-se-201-11:/lab/zone# A=y$RANDOM.se-201-11.lab; echo $A; dig $A | grep "Query time"; dig $A | grep "Query time"
y6725.se-201-11.lab
;; Query time: 1 msec
;; Query time: 0 msec

root@ns-se-201-11:/lab/zone# B=x$RANDOM.lab; echo $B; dig $B | grep "Query time"; dig $B | grep "Query time"
x7939.lab
;; Query time: 40 msec
;; Query time: 1 msec

root@ns-se-201-11:/lab/zone# C=x$RANDOM.zz$RANDOM; echo $C; dig $C | grep "Query time"; dig $C | grep "Query time"
x20713.zz31727
;; Query time: 80 msec
;; Query time: 0 msec

@codespace:/workspaces/opism-lab-DNS$ date +%T; docker compose -f stand/compose.yaml restart resolver-a
13:49:17
 Container dnslab-resolver-a-1 Restarting
 Container dnslab-resolver-a-1 Started
root@ns-se-201-11:/lab/zone# date +%T; dig www.se-201-11.lab | grep 'Query time'; dig www.se-201-11.lab | grep 'Query time'
13:49:22
;; Query time: 402 msec
;; Query time: 1 msec
```

Перезапуск resolver-a тут передбачений методичкою (рядок D, очищення кешу), а не пов'язаний із зіпсованим експериментом.

| Ім'я | Перший запит, мс | Повторний, мс | Сервери, до яких звернувся резолвер (за журналами) |
|---|---|---|---|
| A | 1 | 0 | власний сервер: `13:49:16.816 ... (y6725.se-201-11.lab)` |
| B | 40 | 1 | TLD: `13:49:16.964 ... (x7939.lab)` |
| C | 80 | 0 | root: `13:49:17.158 ... (x20713.zz31727)` |
| D | 402 | 1 | root ×3 (`. NS`, `a.root-servers.net A`, `www...`), TLD, власний сервер |

Значення `time_namelookup` з `curl` після перезапуску резолвера: `0.403604` с ≈ 404 мс, що збігається з першим запитом рядка D.

Фрагменти журналів запитів root, TLD і власного сервера для рядка D:

```text
# root (10.53.0.2)
20-Nov-2026 13:49:22.877 client @0x7128f806ac88 10.53.0.53#20644 (.): query: . IN NS -E(0)DC (10.53.0.2)
20-Nov-2026 13:49:22.957 client @0x7128f00051f8 10.53.0.53#32826 (a.root-servers.net): query: a.root-servers.net IN A -E(0)DC (10.53.0.2)
20-Nov-2026 13:49:23.038 client @0x7128f00051f8 10.53.0.53#15386 (www.se-201-11.lab): query: www.se-201-11.lab IN A -E(0)DC (10.53.0.2)
# TLD (10.53.0.3)
20-Nov-2026 13:49:23.158 client @0x770b900060c8 10.53.0.53#13225 (www.se-201-11.lab): query: www.se-201-11.lab IN A -E(0)DC (10.53.0.3)
# власний сервер (querylog)
20-Nov-2026 13:49:23.199 client @0x7fb38c06ac68 10.53.0.53#37406 (www.se-201-11.lab): query: www.se-201-11.lab IN A -E(0)DC (10.53.1.1)
```

1. Яку затримку вносить кожен із серверів root, TLD і власний сервер? Покажіть, з яких рядків таблиці це випливає.

   | Сервер | Затримка | Звідки випливає |
   |---|---|---|
   | root | ≈ 80 мс | рядок C: резолвер звернувся лише до root, 80 мс; той самий крок у `+trace` завдання 2 — 80 мс |
   | TLD | ≈ 40 мс | рядок B: лише TLD, 40 мс |
   | власний сервер | ≈ 0–1 мс | рядок A: лише власний сервер, 1 мс |

   Рядок D — сума звернень: 3 запити до root (≈ 3 × 80 = 240 мс) + TLD (40 мс) + власний (≈ 1 мс) ≈ 281 мс. Інтервали в журналах це підтверджують: 22.877 → 22.957 → 23.038 (по 80 мс між запитами до root). Виміряні 402 мс більші за суму приблизно на 120 мс (див. «Висновки»). Повторні запити (0–1 мс) показують, що кеш прибирає затримку повністю.

2. Чому в рядку A перший запит не проходить через root і TLD, хоча ім'я нове?

   Резолвер кешує не лише відповіді, а й делегування: NS-записи `lab.` (TTL 172800) і `se-201-11.lab.` (TTL 3600 з TLD) разом із glue, отримані в попередніх завданнях. Найближчий відомий предок для `y6725.se-201-11.lab` — зона `se-201-11.lab`, і її сервер (10.53.1.1) резолвер уже знає. Тому він питає одразу його, а нове ім'я лише означає, що в кеші немає самої відповіді.

3. Вебсторінка завантажує ресурси з п'яти різних доменів. Як це впливає на час першого відкриття сторінки?

   Для кожного домену з холодним кешем потрібен окремий пошук імені, на нашому стенді до ≈ 0,4 с (рядок D), у реальній мережі — від десятків до сотень мілісекунд. Браузер розв'язує імена частково паралельно, але кожен ресурс чекає на свій DNS-запит перед TCP/TLS-з'єднанням, тож перше відкриття помітно сповільнюється, а для ресурсів у критичному шляху затримки накладаються. Повторні відкриття швидкі завдяки кешу. Як зменшити затримку: менше сторонніх доменів, `dns-prefetch` / `preconnect`, домени з довшим TTL.

## Завдання 7. Інцидент: зупинка власного сервера

**Прогноз** (записати до вимірювання). Що поверне кожен резолвер після зупинки сервера та спливання TTL і скільки часу займе відповідь:

- **resolver-a** (звичайний): запис `lab` (TTL 25 с) спливе, а авторитативний сервер не відповідає. Резолвер кілька разів повторить запит до 10.53.1.1 і поверне `SERVFAIL`. Очікувана тривалість — кілька секунд: повтори обмежені `infra-cache-max-rtt` 3 с, тож навряд чи вийде за `+timeout=30`. Другий запит має бути швидшим, бо сервер уже позначено як недоступний.
- **resolver-b** (serve-stale, RFC 8767): спробує оновити запис, не дочекається відповіді за `serve-expired-client-timeout` = 1,8 с і поверне прострочений запис `lab.se-201-11.lab A 10.53.0.81` зі `status: NOERROR` і TTL 30 с. Тривалість ≈ 1,8 с.

Кешування запису в обох резолверах (крок 2) і час зупинки сервера (крок 3):

```text
root@ns-se-201-11:/lab/zone# dig @10.53.0.53 lab.se-201-11.lab +noall +answer
lab.se-201-11.lab.	25	IN	A	10.53.0.81

root@ns-se-201-11:/lab/zone# dig @10.53.0.54 lab.se-201-11.lab +noall +answer
lab.se-201-11.lab.	25	IN	A	10.53.0.81

root@ns-se-201-11:/lab/zone# named-stop; date +%T
13:49:30

root@ns-se-201-11:/lab/zone# sleep 35; date +%T
13:50:05
```

Запити із заміром часу (крок 5):

```text
root@ns-se-201-11:/lab/zone# time dig @10.53.0.53 lab.se-201-11.lab +tries=1 +timeout=30
;; communications error to 10.53.0.53#53: timed out
;; no servers could be reached
real	0m30.050s

root@ns-se-201-11:/lab/zone# time dig @10.53.0.53 lab.se-201-11.lab +tries=1 +timeout=30
;; communications error to 10.53.0.53#53: timed out
;; no servers could be reached
real	0m30.053s

root@ns-se-201-11:/lab/zone# time dig @10.53.0.54 lab.se-201-11.lab +tries=1 +timeout=30
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 4769
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
;; ANSWER SECTION:
lab.se-201-11.lab.	30	IN	A	10.53.0.81
;; Query time: 1800 msec
;; SERVER: 10.53.0.54#53(10.53.0.54) (UDP)
;; WHEN: Fri Nov 20 13:51:07 UTC 2026
real	0m1.823s
```

| Запит | status або тайм-аут | ANSWER, TTL | `real` |
|---|---|---|---|
| resolver-a, перший | тайм-аут (відповіді немає) | — | 30,050 с |
| resolver-a, другий | тайм-аут (відповіді немає) | — | 30,053 с |
| resolver-b | NOERROR | `lab.se-201-11.lab A 10.53.0.81`, TTL 30 | 1,823 с |

Час `named-start` і вивід циклу спостереження до першої успішної відповіді (крок 6):

```text
root@ns-se-201-11:/lab/zone# named-start; date +%T
13:51:07

root@ns-se-201-11:/lab/zone# while true; do echo "$(date +%T) $(dig @10.53.0.53 lab.se-201-11.lab +short +tries=1 +timeout=3)"; sleep 2; done
13:51:07 
13:51:09 
13:51:11 
13:51:13 
13:51:15 
13:51:17 
13:51:19 
13:51:21 
13:51:24 
13:51:26 
13:51:28 
13:51:30 
13:51:32 
13:51:34 
13:51:36 
13:51:38 10.53.0.81
```

Перевірка після завдання (`dig @10.53.1.1 se-201-11.lab SOA +norec +short`):

```text
root@ns-se-201-11:/lab/zone# dig @10.53.1.1 se-201-11.lab SOA +norec +short
ns.se-201-11.lab. admin.se-201-11.lab. 2026112004 3600 600 86400 90
```

### Постмортем

1. **Що сталося:** о 13:49:30 зупинено авторитативний сервер `se-201-11.lab` (10.53.1.1), і зона 97 с не мала жодного робочого сервера: NS-запис лише один, резервного немає.
2. **Вплив на клієнтів resolver-a і resolver-b:** клієнти resolver-a після спливання TTL (25 с) взагалі не отримували відповіді, кожен запит висів 30 с до тайм-ауту клієнта, ще 31 с після запуску сервера — порожні відповіді. Клієнти resolver-b отримували стару адресу 10.53.0.81 за 1,8 с і працювали далі.
3. **Хронологія з виміряним часом:** 13:49:30 зупинка → ≈13:49:55 спливання TTL у кешах → 13:50:05 resolver-a: тайм-аут 30 с, двічі (до 13:51:05) → 13:51:07 resolver-b: застаріла відповідь за 1,823 с → 13:51:07 `named-start` → 13:51:38 resolver-a знову відповідає (через 31 с після запуску). Загалом недоступність для resolver-a ≈ 1 хв 43 с від спливання TTL.
4. **Чому кеш допоміг або не допоміг:** у resolver-a кеш не допоміг, бо запис жив лише 25 с, а після спливання звичайний резолвер прострочених даних не віддає. До того ж він запам'ятав сервер як недоступний і ще ≈ 30 с після запуску не питав його знову. У resolver-b допоміг serve-stale (RFC 8767): прострочений запис віддано замість помилки.
5. **Що слід змінити:** додати другий авторитативний сервер у іншій мережі (два NS-записи, вторинний через AXFR), поставити моніторинг доступності 10.53.1.1 з алертом, увімкнути serve-stale на резолверах, якими користуються клієнти, і не тримати критичні записи на дуже короткому TTL без резервування.

1. Який TTL мав запис у відповіді resolver-b і навіщо такий TTL?

   30 с, а не 25 з зони. Це TTL для прострочених відповідей (`serve-expired-reply-ttl` за замовчуванням 30 с у Unbound; RFC 8767 рекомендує 30 с). Він короткий навмисно: клієнт не повинен надовго кешувати дані, свіжість яких не підтверджено, і має невдовзі спитати знову, коли авторитативний сервер, можливо, вже повернеться.

2. Порівняйте результат і тривалість двох запитів до resolver-a. Якщо вони різняться, сформулюйте гіпотезу щодо причини; якщо ні, поясніть, що робить резолвер протягом цього часу.

   Обидва запити однакові: відповіді немає, `dig` чекав 30,05 с і здався (`timed out`), прогноз щодо швидкого SERVFAIL не справдився. Пояснення: весь цей час резолвер намагається розв'язати ім'я сам — повторно надсилає запит до 10.53.1.1 зі зростаючим інтервалом очікування (до 3 с, `infra-cache-max-rtt`) і перевіряє, чи немає іншого сервера для зони. Свого ліміту спроб він не вичерпав за 30 с, тому клієнт не отримав навіть SERVFAIL. Другий запит прийшов, коли сервер ще не був остаточно позначений як «мертвий» в infra-кеші, і цикл спроб почався знову. У кроці 6 запити вже поверталися миттєво з порожньою відповіддю: на той момент сервер був позначений недоступним, і резолвер одразу віддавав SERVFAIL.

3. Чому після `named-start` ім'я через resolver-a зарезолвилося не одразу?

   Unbound запам'ятовує стан кожного авторитативного сервера в infra-кеші. Після серії тайм-аутів 10.53.1.1 позначено як недоступний на `infra-host-ttl` = 60 с. До спливання цієї позначки резолвер одразу повертає SERVFAIL, не питаючи сервер, тому `named-start` о 13:51:07 він «не помітив». Позначку поставлено під час кроку 5, коли сервер не відповів на серію повторів; після її спливання резолвер знову спробував 10.53.1.1 і о 13:51:38 отримав відповідь (через 31 с після запуску).

4. У якій ситуації serve-stale шкодить, а не допомагає? Пов'яжіть відповідь із завданням 4.

   Коли запис навмисно змінили, а старі дані вже неправильні. У завданні 4 `www` переїхав з 10.53.0.80 на 10.53.0.81. Якби під час такого переїзду авторитативний сервер став недоступним, resolver-b ще до `serve-expired-ttl` = 3600 с віддавав би стару адресу. Клієнти йшли б на старий, можливо, вже вимкнений або чужий сервер, і плановий перенос, розрахований на TTL 45 с, розтягнувся б на годину. Крім того, serve-stale приховує відмову авторитативного сервера від користувачів і моніторингу, тож проблему помічають пізніше.

## Фінальний файл зони

<!-- Повний вміст stand/students/sNN/zone/sNN.lab.zone після завершення роботи. -->

```text
; Zone se-201-11.lab — starting version.
; After every change: increase the serial, then run  zone-reload
$TTL 45
@     15 IN SOA ns.se-201-11.lab. admin.se-201-11.lab. (
            2026112004 ; serial
            3600       ; refresh
            600        ; retry
            86400      ; expire
            90         ; minimum
        )
@     IN NS ns.se-201-11.lab.
ns    IN A  10.53.1.1

; ---- add records from your variant card below this line ----
www            IN A      10.53.0.81
status         IN CNAME  www
mail           IN A      10.53.0.80
@              IN MX     30 mail
@              IN TXT    "lab-token=c4d4a729"
lab       25   IN A      10.53.0.81
new-kljby      IN A      10.53.0.80
```

## Висновки

**Що виявилося несподіваним.** Результат, який не збігся з очікуванням, і рядок виводу, де це видно:

Я очікував, що звичайний резолвер після зупинки авторитативного сервера швидко поверне `SERVFAIL`, а він не відповів узагалі: обидва запити закінчилися тайм-аутом клієнта (`;; communications error to 10.53.0.53#53: timed out`, `real 0m30.050s` і `real 0m30.053s`). З погляду користувача «сервер імен мовчить» гірше за явну помилку: застосунок 30 с чекає, замість одразу показати проблему. Водночас resolver-b з serve-stale відповів за 1,8 с (`Query time: 1800 msec`) і ще й з TTL 30 замість 25. Друге спостереження: навіть після `named-start` resolver-a ще 31 с не бачив сервер (рядки `13:51:07` … `13:51:36` без адреси), тобто відновлення сервера не означає миттєвого відновлення для клієнтів.

**Яке питання залишилося без відповіді.** Що саме не вдалося пояснити; до якого рядка виводу це стосується; що вже перевірено (RFC, документація, додатковий експеримент на стенді) і що з'ясувати не вдалося:

Рядок D завдання 6: `;; Query time: 402 msec` (і `time_namelookup` 0.403604). За затримками окремих серверів (root 80 мс з рядка C, TLD 40 мс з рядка B, власний ≈ 1 мс з рядка A) і за журналами (три запити до root о 22.877, 22.957, 23.038, один до TLD о 23.158, один до власного сервера о 23.199) виходить ≈ 281–320 мс, а не 402. Перевірено: журнали root, TLD і власного сервера — інших запитів від 10.53.0.53 у цей момент немає; повторний вимір через `curl` дав те саме значення (≈ 404 мс), тож це не випадковість. Не з'ясовано, на що йдуть зайві ≈ 80–120 мс. Гіпотези: (а) між 13:49:22 і 22.877 Unbound ще не готовий після перезапуску або виконує внутрішню ініціалізацію; (б) затримка netem застосовується до вихідного трафіку root і TLD так, що позначки часу в журналах зсунуті відносно моменту відправлення запиту. Щоб перевірити, треба записати трафік `tcpdump` на resolver-a під час рядка D і порівняти позначки часу пакетів із журналами.

## Декларація використання ШІ

Використовувалися інструменти ШІ: так

<!-- Якщо так, заповнити таблицю: один рядок на кожне звернення, що вплинуло на звіт. Промпт наводити дослівно. -->

| № | Інструмент | Промпт (дослівно) | Що використано у звіті і що змінено самостійно |
|---|---|---|---|
| 1 | Claude (Anthropic), модель Claude Opus 5.5 | «Допоможи мені розібрати методичку та репозиторій стенда, створити форк та правильно все записати, згідно лабораторної, там де це ти можеш зробити. Стенд і все інше я створю сам» | Розбір методички, допомога в створенні стенда, форка та правиильному виконанні завдань згідно наданого файлу. Створення стенду та іншої ручної роботи лежить на користувачеві. |
| 2 | Claude (Anthropic), модель Claude Opus 5.5 | «Допоможи в написанні інших завдань та детально поясни чому ти так зробив, без лишньої води та по суті, щоб я міг зрозуміти» | Допомога в написанні інших завдань та детальне пояснення рішень. |
