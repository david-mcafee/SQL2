DROP TABLE IF EXISTS users, questions, question_follows, replies, question_likes;

CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname VARCHAR(255) NOT NULL,
  lname VARCHAR(255) NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  user_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  body TEXT NOT NULL,
  quesiton_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  parent_id INTEGER,

  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (parent_id) REFERENCES replies(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  question_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,

  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

INSERT INTO users (fname, lname)
VALUES
  ('Alex', 'Manning'), ('David', 'McAfee'), ('Keicy', 'Tolbert');

INSERT INTO questions(title, body, user_id)
VALUES
    ('How do I insert', 'I am super confused how to do this', SELECT id FROM users WHERE fname = 'Alex'),
    ('How do I create', 'I like to create tables', SELECT id FROM users WHERE fname = 'David'),
    ('Why am I in this example', 'I am not even part of AA', SELECT id FROM users WHERE fname = 'Keicy');

INSERT INTO question_follows (user_id, question_id)
VALUES
  (SELECT id FROM users WHERE fname = 'Alex', SELECT id FROM questions WHERE title like '%create%' ),
  (SELECT id FROM users WHERE fname = 'David', SELECT id FROM questions WHERE title like '%insert%' ),
  (SELECT id FROM users WHERE fname = 'Keicy', SELECT id FROM questions WHERE title like '%insert%' );

INSERT INTO replies (body, question_id, user_id, parent_id)
VALUES
  ("I think you do it like this...", SELECT id FROM questions WHERE title like '%insert%', SELECT id FROM users WHERE fname = 'David', NULL ),
  ("Wait what were you going to say", SELECT id FROM questions WHERE title like '%insert%', SELECT id FROM users WHERE fname = 'Alex', SELECT id FROM replies WHERE body = 'I think you do it like this...');

INSERT INTO question_likes (question_id, user_id)
VALUES
  (SELECT id FROM questions WHERE title like '%create%', SELECT id FROM users WHERE fname = 'David'),
  (SELECT id FROM questions WHERE title like '%create%', SELECT id FROM users WHERE fname = 'Keicy');
