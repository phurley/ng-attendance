DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
  id serial PRIMARY KEY,
  email varchar NOT NULL UNIQUE CHECK(TRIM(email) <> ''),
  name varchar NOT NULL UNIQUE CHECK (TRIM(name) <> ''),
  student_number varchar UNIQUE CHECK (TRIM(student_number) <> ''),
  admin boolean NOT NULL DEFAULT false,
  mentor boolean NOT NULL DEFAULT false
);

DROP TABLE IF EXISTS meetings;
CREATE TABLE meetings (
    id serial PRIMARY KEY,
    user_id int NOT NULL,
    at DATE NOT NULL DEFAULT current_date,
    UNIQUE (user_id, at),
    CONSTRAINT fk_user
       FOREIGN KEY(user_id)
           REFERENCES users(id)
           ON DELETE CASCADE
);
CREATE INDEX ON meetings (at);
