require "kemal"

require "jennifer"
require "jennifer/adapter/postgres"

# I18n.load_path += ["./config/locales"]
I18n.init

# env = "postgres" # ENV["environment"]
Jennifer::Config.read("./database.yml", "postgres")

class User < Jennifer::Model::Base
  mapping(
    id: Primary32, # is an alias for Int32? primary key
    email: String,
    name: String,
    student_number: String?,
    admin: Bool,
    mentor: Bool,
  )

  has_many :meetings, Meeting
end

class Meeting < Jennifer::Model::Base
  table_name :meetings
  mapping(
    id: Primary32,
    user_id: Int32,
    at: Time
  )

  belongs_to :user, User
end

struct Time
  def at_nearest_hour
    t1 = at_beginning_of_hour
    t2 = at_end_of_hour.shift(seconds: 1)
    if (t1 - self).abs < (t2 - self).abs
      t1
    else
      t2
    end
  end
end

get "/" do |env|
  puts env.request.headers.inspect
  "Hello World!"
end

get "/mentors" do
  mentors = User.where { _mentor == true }
  m = mentors.eager_load(:meetings).includes(:meetings).results
  m.to_json
end

get "/checkedin" do |env|
  id = env.request.headers["User"].to_i
  today_start = Time.local.at_beginning_of_day
  today_end = Time.local.at_end_of_day
  m = Meeting.where { (_user_id == id) & (_at.between(today_start, today_end)) }
  (m.count > 0).to_json
end

post "/checkin" do |env|
  id = env.request.headers["User"].to_i
  m = Meeting.create(user_id: id, at: Time.local.at_nearest_hour)
  m.to_json
end

get "/students" do |env|
  s = User.where { (_mentor == false) }

  s.to_a.to_json
end

get "/user" do |env|
  email = env.params.query["email"]?
  id = env.params.query["student_number"]?
  mentor = env.params.query["mentor"]?

  mentor = case mentor
           when Nil
             false
           when .empty?
             false
           else
             mentor.downcase[0] == 't'
           end

  if email.nil? || id.nil? && !mentor
    halt env, status_code: 403, response: "not found"
  end

  s = if mentor
        User.where { (_email == email) & (_mentor == true) }
      else
        User.where { (_email == email) & (_student_number == id) & (_mentor == false) }
      end

  num = s.count
  if num == 0
    halt env, status_code: 403, response: "not found"
  end
  if num > 1
    halt env, status_code: 500, response: "this should never happen"
  end

  s.to_a.first.id.to_json
end

Kemal.run
