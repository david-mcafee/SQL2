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

class User
  attr_accessor :id, :fname, :lname

  def self.all
    data = QuestionsDatabase.instance.execute('SELECT * FROM users')

    data.map do |datum|
      User.new(datum)
    end
  end

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

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end

end

class Question
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

  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
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
end

class QuestionFollow
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
      QuestionFollow.new(datum)
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
      QuestionFollow.new(datum)
    end
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class QuestionLike
  attr_accessor :id, :user_id, :question_id

  def self.all
    data = QuestionsDatabase.instance.execute('SELECT * FROM question_likes')

    data.map do |datum|
      QuestionLike.new(datum)
    end
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class Reply
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
end
