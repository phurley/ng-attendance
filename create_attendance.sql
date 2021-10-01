DROP TABLE IF EXISTS users CASCADE;
CREATE TABLE users (
  id serial PRIMARY KEY,
  email varchar NOT NULL UNIQUE CHECK(TRIM(email) <> ''),
  name varchar NOT NULL CHECK (TRIM(name) <> ''),
  student_number varchar UNIQUE CHECK (TRIM(student_number) <> ''),
  admin boolean NOT NULL DEFAULT false,
  mentor boolean NOT NULL DEFAULT false
);

INSERT INTO users (email, name, admin, mentor) VALUES ('phurley@gmail.com', 'Patrick Hurley', true, true);
INSERT INTO users (email, name, student_number) VALUES ('shane.hurley@gmail.com', 'Shane Hurley', '12345');

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

INSERT INTO meetings (user_id) SELECT ID FROM users WHERE email = 'phurley@gmail.com';
INSERT INTO meetings (user_id) SELECT ID FROM users WHERE email = 'shane.hurley@gmail.com';

