require 'singleton'
require 'sqlite3'
require 'byebug'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class ModelBase
  TABLE_NAMES = {
    "User" => "users",
    "Question" => "questions",
    "QuestionLike" => "question_likes",
    "QuestionFollow" => "question_follows",
    "Reply" => "replies"
  }

  def self.find_by_id
    data = QuestionsDatabase.instance.execute(<<-SQL)
      SELECT
        *
      FROM
        #{TABLE_NAMES[self.to_s]}
      WHERE
        id = #{@id}
    SQL

    data.map do |datum|
      self.new(datum)
    end
  end

  def self.all
    byebug
    data = QuestionsDatabase.instance.execute(<<-SQL)
      SELECT
        *
      FROM
        #{TABLE_NAMES[self.to_s]}
    SQL

    data.map do |datum|
      self.new(datum)
    end
  end

  def save
    byebug
    instance_variable_name = self.instance_variables.map(&:to_s).map { |command| command[1..-1] }[1..-1]
    ins ="#{TABLE_NAMES[self.class.to_s]} (#{instance_variable_name.join(", ")})"
    val = instance_variable_name.map(&:to_sym).map { |command| "'#{self.send(command)}'" }.join(", ")

    QuestionsDatabase.instance.execute(<<-SQL)
      INSERT INTO
        #{TABLE_NAMES[self.class.to_s]} (#{instance_variable_name.join(", ")})
      VALUES
        (#{val})
    SQL
  end

  @id = QuestionsDatabase.instance.last_insert_row_id
end

class User < ModelBase
  attr_accessor :id, :fname, :lname

  # def self.all
  #   data = QuestionsDatabase.instance.execute('SELECT * FROM users')
  #
  #   data.map do |datum|
  #     User.new(datum)
  #   end
  # end

  def self.find_by_author_id(author_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL

    data.map do |datum|
      User.new(datum)
    end
  end

  def self.find_by_name(fname, lname)
    # debugger
    data = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL

    data.map do |datum|
      User.new(datum)
    end
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end

  def average_karma
    data = QuestionsDatabase.instance.execute(<<-SQL, @id)
      SELECT
        AVG(ql.question_like_counts)
      FROM users
      JOIN (
        SELECT
          questions.user_id, count(question_likes.question_id) as question_like_counts
        FROM
          questions
        JOIN
          question_likes
          ON question_likes.question_id = questions.id
        GROUP BY
          questions.id
      ) as ql
      ON ql.user_id = users.id
      WHERE users.id = ?
    SQL
  end

  def update
    raise "Entry does not exist in table" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname, @id)
      UPDATE
        users
      SET
        fname = ?, lname = ?
      WHERE
        id = ?
    SQL
  end

  # def save
  #   raise "Entry already exists in table" if @id
  #   QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname)
  #     INSERT INTO
  #       users (fname, lname)
  #     VALUES
  #       (?, ?)
  #   SQL
  #
  #   @id = QuestionsDatabase.instance.last_insert_row_id
  # end

end

class Question < ModelBase
  attr_accessor :id, :title, :body, :user_id

  def self.all
    data = QuestionsDatabase.instance.execute('SELECT * FROM questions')
    data.map do |datum|
      Question.new(datum)
    end
  end

  def self.find_by_author_id(author_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        user_id = ?
    SQL

    data.map do |datum|
      Question.new(datum)
    end
  end

  def self.find_by_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        questions
      WHERE
        id = ?
    SQL

    data.map do |datum|
      Question.new(datum)
    end
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
  end

  def likers
    QuestionLike.likers_for_question_id(@id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(question_id)
  end

  def author
    data = QuestionsDatabase.instance.execute(<<-SQL, @user_id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL

    data.map do |datum|
      User.new(datum)
    end
  end

  def replies
    Reply.find_by_question_id(@id)
  end

  def followers
    QuestionFollow.followers_for_question_id(@id)
  end

  def update
    raise "Entry does not exist in table" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @user_id, @id)
      UPDATE
        questions
      SET
        title = ?, body = ?, user_id = ?
      WHERE
        id = ?
    SQL
  end

  def save
    raise "Entry already exists in table" if @id
    QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @user_id)
      INSERT INTO
        questions (title, body, user_id)
      VALUES
        (?, ?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end

end

class QuestionFollow < ModelBase
  attr_accessor :id, :user_id, :question_id
  def self.all
    data = QuestionsDatabase.instance.execute('SELECT * FROM question_follows')

    data.map do |datum|
      QuestionFollow.new(datum)
    end
  end

  def self.followers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)

    SELECT
      users.*
    FROM
      question_follows
    JOIN users
      ON question_follows.user_id = users.id
    WHERE
      question_follows.question_id = ?

    SQL

    data.map do |datum|
      User.new(datum)
    end
  end

  def self.followed_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id)

    SELECT
      questions.*
    FROM
      question_follows
    JOIN questions
      ON question_follows.question_id = questions.id
    WHERE
      question_follows.user_id = ?

    SQL

    data.map do |datum|
      Question.new(datum)
    end
  end

  def self.most_followed_questions(n)
    data = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        questions.*
      FROM
        question_follows
      JOIN
        questions
          ON questions.id = question_follows.question_id
      GROUP BY
        questions.id
      ORDER BY
        count(*) DESC
      LIMIT
        ?
    SQL

    data.map do |datum|
      Question.new(datum)
    end
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def update
    raise "Entry does not exist in table" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @user_id, @question_id,  @id)
      UPDATE
        question_follows
      SET
        user_id = ?, question_id = ?
      WHERE
        id = ?
    SQL
  end

  def save
    raise "Entry already exists in table" if @id
    QuestionsDatabase.instance.execute(<<-SQL, @user_id, @question_id)
      INSERT INTO
        question_follows (user_id, question_id)
      VALUES
        (?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end
end

class QuestionLike < ModelBase
  attr_accessor :id, :user_id, :question_id

  def self.all
    data = QuestionsDatabase.instance.execute('SELECT * FROM question_likes')

    data.map do |datum|
      QuestionLike.new(datum)
    end
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def self.likers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        users.*
      FROM
        users
      JOIN question_likes
        ON question_likes.user_id = users.id
      WHERE
        question_likes.question_id = ?
    SQL
    data.map do |datum|
      User.new(datum)
    end
  end

  def self.num_likes_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        count(*) AS user_count
      FROM
        users
      JOIN question_likes
        ON question_likes.user_id = users.id
      WHERE
        question_likes.question_id = ?
    SQL

    data.first['user_count']
  end

  def self.liked_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        questions.*
      FROM
        question_likes
      JOIN
        questions
        ON questions.id = question_likes.question_id
      WHERE
        question_likes.user_id = ?
    SQL

    data.map do |datum|
      Question.new(datum)
    end
  end

  def self.most_liked_questions(n)
    data = QuestionsDatabase.instance.execute(<<-SQL, n)

      SELECT
        questions.*
      FROM
        question_likes
      JOIN
        questions
        ON questions.id = question_likes.question_id
      GROUP BY
        questions.id
      ORDER BY
        count(questions.id) DESC
      LIMIT
        ?
    SQL

    data.map do |datum|
      Question.new(datum)
    end
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end

  def update
    raise "Entry does not exist in table" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @user_id, @question_id, @id)
      UPDATE
        question_likes
      SET
        user_id = ?, question_id = ?
      WHERE
        id = ?
    SQL
  end

  def save
    raise "Entry already exists in table" if @id
    QuestionsDatabase.instance.execute(<<-SQL, @user_id, @question_id)
      INSERT INTO
        question_likes (user_id, question_id)
      VALUES
        (?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end
end

class Reply < ModelBase
  attr_accessor :id, :body, :question_id, :user_id, :parent_id

  def self.all
    data = QuestionsDatabase.instance.execute('SELECT * FROM replies')

    data.map do |datum|
      Reply.new(datum)
    end
  end

  def self.find_by_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL

    data.map do |datum|
      Reply.new(datum)
    end
  end

  def self.find_by_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        replies
      WHERE
        question_id = ?
    SQL

    data.map do |datum|
      Reply.new(datum)
    end
  end

  def initialize(options)
    @id = options['id']
    @body = options['body']
    @question_id = options['question_id']
    @user_id = options['user_id']
    @parent_id = options['parent_id']
  end

  def author
    User.find_by_author_id(@user_id).first
  end

  def question
    Question.find_by_question_id(@question_id).first
  end

  def parent_reply
    raise 'This comment is parentless' unless @parent_id
    data = QuestionsDatabase.instance.execute(<<-SQL, @parent_id)
      SELECT
        *
      FROM
        replies
      WHERE
        id = ?
    SQL

    data.map do |datum|
      Reply.new(datum)
    end
  end

  def child_replies
    data = QuestionsDatabase.instance.execute(<<-SQL, @id)
      SELECT
        *
      FROM
        replies
      WHERE
        @parent_id = ?
    SQL

    data.map do |datum|
      Reply.new(datum)
    end
  end

  def update
    raise "Entry does not exist in table" unless @id
    QuestionsDatabase.instance.execute(<<-SQL, @body, @question_id, @user_id, @parent_id, @id)
      UPDATE
        replies
      SET
        body = ?, question_id = ?, user_id = ?, parent_id = ?
      WHERE
        id = ?
    SQL
  end

  def save
    raise "Entry already exists in table" if @id
    QuestionsDatabase.instance.execute(<<-SQL, @body, @question_id, @user_id, @parent_id)
      INSERT INTO
        replies (body, question_id, user_id, parent_id)
      VALUES
        (?, ?, ?, ?)
    SQL

    @id = QuestionsDatabase.instance.last_insert_row_id
  end
end
