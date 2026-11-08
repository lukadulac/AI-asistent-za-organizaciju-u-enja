-- =====================================================================
-- AI asistent za organizaciju učenja — šema baze
-- MySQL 8.4, InnoDB, utf8mb4
-- Konvencije: id INT UNSIGNED AUTO_INCREMENT, sva vremena DATETIME u UTC,
-- sva trajanja u MINUTIMA.
-- Tabelu za admin sesije pravi express-mysql-session sam, nije ovde.
-- =====================================================================

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS study_planner
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE study_planner;

-- ---------------------------------------------------------------------
-- Korisnici i autentifikacija
-- ---------------------------------------------------------------------

CREATE TABLE users (
  id                INT UNSIGNED NOT NULL AUTO_INCREMENT,
  email             VARCHAR(255) NOT NULL,
  password_hash     CHAR(60)     NOT NULL,              -- bcrypt
  first_name        VARCHAR(100) NOT NULL,
  last_name         VARCHAR(100) NOT NULL,
  role              ENUM('user','admin') NOT NULL DEFAULT 'user',
  email_verified_at DATETIME     NULL,                  -- NULL dok nalog nije aktiviran
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Jednokratni tokeni za aktivaciju naloga (24 h) i reset lozinke (30 min)
CREATE TABLE email_tokens (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     INT UNSIGNED NOT NULL,
  type        ENUM('activation','password_reset') NOT NULL,
  token_hash  CHAR(64)     NOT NULL,                    -- SHA-256 tokena
  expires_at  DATETIME     NOT NULL,
  used_at     DATETIME     NULL,                        -- postavlja se pri upotrebi
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_email_tokens_hash (token_hash),
  CONSTRAINT fk_email_tokens_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Refresh tokeni (30 dana); odjava i promena lozinke postavljaju revoked_at
CREATE TABLE refresh_tokens (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     INT UNSIGNED NOT NULL,
  token_hash  CHAR(64)     NOT NULL,
  device_info VARCHAR(255) NULL,                        -- iz User-Agent zaglavlja
  expires_at  DATETIME     NOT NULL,
  revoked_at  DATETIME     NULL,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refresh_tokens_hash (token_hash),
  CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Predmeti i obaveze
-- ---------------------------------------------------------------------

CREATE TABLE subjects (
  id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id INT UNSIGNED NOT NULL,
  name    VARCHAR(100) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_subjects_user_name (user_id, name),
  CONSTRAINT fk_subjects_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE tasks (
  id                INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  user_id           INT UNSIGNED      NOT NULL,
  subject_id        INT UNSIGNED      NOT NULL,
  title             VARCHAR(150)      NOT NULL,
  description       TEXT              NULL,             -- max 1000 znakova (validacija na serveru)
  due_date          DATE              NOT NULL,
  priority          ENUM('low','medium','high') NOT NULL,
  estimated_minutes SMALLINT UNSIGNED NOT NULL,
  status            ENUM('todo','done') NOT NULL DEFAULT 'todo',
  completed_at      DATETIME          NULL,
  reminder_at       DATETIME          NULL,             -- dodatna funkcionalnost: podsetnici
  created_at        DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        DATETIME          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  -- pokriva filtriranje po statusu i roku; služi i kao indeks za FK user_id
  KEY idx_tasks_user_status_due (user_id, status, due_date),
  CONSTRAINT chk_tasks_estimated_minutes CHECK (estimated_minutes > 0),
  CONSTRAINT fk_tasks_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_tasks_subject FOREIGN KEY (subject_id)
    REFERENCES subjects (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Planovi učenja
-- ---------------------------------------------------------------------

CREATE TABLE plans (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      INT UNSIGNED NOT NULL,
  name         VARCHAR(150) NOT NULL,
  period_start DATE         NOT NULL,
  period_end   DATE         NOT NULL,
  ai_summary   TEXT         NULL,                       -- kratak opis i upozorenja iz AI predloga
  is_feasible  BOOLEAN      NOT NULL,                   -- false ako vreme nije bilo dovoljno
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT chk_plans_period CHECK (period_end >= period_start),
  CONSTRAINT fk_plans_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Raspoloživo vreme po danu u okviru planac
CREATE TABLE plan_availability (
  plan_id           INT UNSIGNED      NOT NULL,
  day               DATE              NOT NULL,
  available_minutes SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (plan_id, day),
  CONSTRAINT chk_plan_availability_minutes CHECK (available_minutes BETWEEN 0 AND 960),
  CONSTRAINT fk_plan_availability_plan FOREIGN KEY (plan_id)
    REFERENCES plans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Aktivnosti plana po danima. Brisanje obaveze ne briše plan:
-- aktivnost zadržava belešku, a task_id postaje NULL.
-- activity_date mora biti unutar perioda plana (provera na serveru).
CREATE TABLE plan_activities (
  id               INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  plan_id          INT UNSIGNED      NOT NULL,
  task_id          INT UNSIGNED      NULL,
  activity_date    DATE              NOT NULL,
  duration_minutes SMALLINT UNSIGNED NOT NULL,
  note             VARCHAR(255)      NULL,
  sort_order       TINYINT UNSIGNED  NOT NULL DEFAULT 0, -- redosled u danu
  PRIMARY KEY (id),
  KEY idx_plan_activities_plan_date (plan_id, activity_date, sort_order),
  CONSTRAINT chk_plan_activities_duration CHECK (duration_minutes > 0),
  CONSTRAINT fk_plan_activities_plan FOREIGN KEY (plan_id)
    REFERENCES plans (id) ON DELETE CASCADE,
  CONSTRAINT fk_plan_activities_task FOREIGN KEY (task_id)
    REFERENCES tasks (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Evidencija pristupa (admin pregled)
-- ---------------------------------------------------------------------

CREATE TABLE access_logs (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id     INT UNSIGNED    NULL,                     -- NULL za gosta
  channel     ENUM('web','api') NOT NULL,
  method      VARCHAR(10)     NOT NULL,
  path        VARCHAR(255)    NOT NULL,
  ip          VARCHAR(45)     NOT NULL,                 -- IPv4 i IPv6
  user_agent  VARCHAR(512)    NULL,                     -- sirovo zaglavlje
  device_type VARCHAR(50)     NULL,                     -- iz ua-parser-js
  os          VARCHAR(50)     NULL,
  browser     VARCHAR(50)     NULL,
  country     VARCHAR(100)    NULL,                     -- iz spoljnog IP API-ja
  city        VARCHAR(100)    NULL,
  isp         VARCHAR(100)    NULL,
  created_at  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_access_logs_created_at (created_at),
  CONSTRAINT fk_access_logs_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Keš odgovora spoljnog IP API-ja; osvežava se posle 7 dana
CREATE TABLE ip_lookups (
  ip         VARCHAR(45) NOT NULL,
  data       JSON        NOT NULL,                      -- ceo odgovor spoljnog API-ja
  fetched_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (ip)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- Dodatna funkcionalnost: fokus (Pomodoro) sesije
-- ---------------------------------------------------------------------

CREATE TABLE focus_sessions (
  id               INT UNSIGNED      NOT NULL AUTO_INCREMENT,
  user_id          INT UNSIGNED      NOT NULL,
  task_id          INT UNSIGNED      NULL,
  started_at       DATETIME          NOT NULL,
  duration_minutes SMALLINT UNSIGNED NOT NULL,          -- stvarno odrađeno vreme
  completed        BOOLEAN           NOT NULL DEFAULT FALSE, -- ceo interval ili prekinut
  PRIMARY KEY (id),
  KEY idx_focus_sessions_user_started (user_id, started_at),
  CONSTRAINT fk_focus_sessions_user FOREIGN KEY (user_id)
    REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_focus_sessions_task FOREIGN KEY (task_id)
    REFERENCES tasks (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
