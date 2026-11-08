# Docker: pokretanje baze

Lokalno okruženje čine dva kontejnera iz `docker-compose.yml`:

| Servis | Adresa | Namena |
|---|---|---|
| MySQL 8.4 | `localhost:3306` | baza `study_planner` |
| Mailpit | http://localhost:8025 (web), `localhost:1025` (SMTP) | hvata test mejlove |

Pristupni podaci za bazu:

| | |
|---|---|
| Host | `127.0.0.1` |
| Port | `3306` |
| Baza | `study_planner` |
| Korisnik / lozinka | `planner` / `planner` |
| Root lozinka | `root` |

Sve komande se kucaju u root-u projekta (gde je `docker-compose.yml`). Docker Desktop mora biti pokrenut.

## Prvo pokretanje

```bash
git clone git@github.com:lukadulac/AI-asistent-za-organizaciju-u-enja.git
cd AI-asistent-za-organizaciju-u-enja
docker compose up -d --wait
```

Prvi put se skidaju image-i (minut-dva). `--wait` čeka da baza bude spremna, uključujući izvršavanje SQL fajlova iz `database/`.

## Svakodnevne komande

| Komanda | Šta radi |
|---|---|
| `docker compose up -d --wait` | Pokreće bazu i Mailpit u pozadini |
| `docker compose ps` | Prikazuje status (treba da piše `healthy`) |
| `docker compose stop` | Gasi kontejnere, podaci ostaju |
| `docker compose down` | Briše kontejnere, podaci ostaju |
| `docker compose logs -f mysql` | Prati logove baze (izlaz: Ctrl+C) |

## Reset baze (posle izmene SQL fajlova)

SQL fajlovi iz `database/` (`01_schema.sql`, `02_seed.sql`, …) izvršavaju se **samo kad je baza prazna**. Posle svake izmene tih fajlova bazu treba resetovati:

```bash
docker compose down -v
docker compose up -d --wait
```

`-v` briše sve podatke iz baze. Lokalno je to u redu jer se sve ponovo pravi iz SQL fajlova. **Nikad na serveru.**

## Rad sa bazom iz terminala

```bash
# MySQL konzola
docker compose exec mysql mysql -uplanner -pplanner study_planner

# Jedan upit
docker compose exec mysql mysql -uplanner -pplanner study_planner -e "SHOW TABLES;"

# Struktura tabele
docker compose exec mysql mysql -uplanner -pplanner study_planner -e "DESCRIBE tasks;"

# Izvršavanje SQL fajla na postojećoj bazi (npr. migracije)
docker compose exec -T mysql mysql -uplanner -pplanner study_planner < database/03_primer.sql
```

## Tok rada u timu

1. Izmeni SQL fajl u `database/`.
2. `docker compose down -v && docker compose up -d --wait`
3. Proveri da sve radi, pa commit i push.
4. Kolega: `git pull`, pa `docker compose down -v && docker compose up -d --wait`.

Baza se ne deli preko gita. Svako ima svoju lokalnu bazu napravljenu iz istih SQL fajlova.

## Česti problemi

| Problem | Rešenje |
|---|---|
| `Cannot connect to the Docker daemon` | Pokreni Docker Desktop |
| `port 3306 is already allocated` | Lokalni MySQL radi: `brew services stop mysql`, ili promeni port u compose fajlu (`"3307:3306"`) |
| Izmena u SQL fajlu se ne vidi u bazi | Uradi reset (`down -v` pa `up -d --wait`) |
| Kontejner se gasi posle pokretanja | `docker compose logs mysql` pokazuje grešku u SQL-u, ispravi je pa reset |
| Workbench: `Could not connect` | Korisnik `planner` (ne `root` bez lozinke), host `127.0.0.1`, port `3306` |
