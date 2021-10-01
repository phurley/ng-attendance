require "pg"
require "db"
require "kemal"

if !ENV.has_key?("DATABASE_URI")
  puts "Environment variable DATABASE_URI must be initialized"
  exit -1
end

Db = DB.open ENV["DATABASE_URI"]
db = Db

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
  {:version => "1.0.0", :description => "A simple time logging API"}.to_json
end

get "/mentors" do
  result = {} of String => Array(String)
  db.query "SELECT name, at FROM users LEFT JOIN meetings ON users.id = meetings.user_id WHERE at IS NOT NULL ORDER BY users.name, meetings.at DESC" do |rs|
    rs.each do
      name = rs.read(String)
      at = rs.read(Time).to_local.to_s("%F")

      if result.has_key?(name)
        result[name] << at
      else
        result[name] = [at]
      end
    end
  end
  result.to_json
end

get "/checkedin" do |env|
  id = env.request.headers["User"].to_i
  today_start = Time.local.at_beginning_of_day
  today_end = Time.local.at_end_of_day

  found = false
  db.query "SELECT FROM meetings WHERE user_id = $1 AND at BETWEEN $2 AND $3 LIMIT 1", id, today_start, today_end do |rs|
    rs.each do
      found = true
    end
  end
  found.to_json
end

post "/checkin" do |env|
  id = env.request.headers["User"].to_i
  new_id = 0
  Log.info { "Process check in for #{id}" }
  db.exec "INSERT INTO meetings (user_id, at) VALUES ($1, $2) RETURNING id", id, Time.local.at_nearest_hour

  today_start = Time.local.at_beginning_of_day
  today_end = Time.local.at_end_of_day
  result = [] of String

  db.query "SELECT name FROM users LEFT JOIN meetings ON users.id = meetings.user_id WHERE at BETWEEN $1 AND $2 ORDER BY users.name", today_start, today_end do |rs|
    rs.each do
      name = rs.read(String)
      result << name
    end
  end
  result.to_json
rescue ex : PQ::PQError
  Log.error { "Error processing insert: #{ex.message}" }
  halt env, status_code: 409, response: ex.message
end

def get_students
  result = [] of NamedTuple(id: Int32, name: String)
  Db.query "SELECT id, name FROM users WHERE mentor = 'f' ORDER BY users.name" do |rs|
    rs.each do
      result << {id: rs.read(Int32), name: rs.read(String)}
    end
  end
  result
end

post "/register" do |env|
  name = env.params.json["name"].as(String)
  email = env.params.json["email"].as(String)
  studid = env.params.json["student_id"].as(String)
  studid = nil if studid.strip.empty?
  db.exec "INSERT INTO users (name, email, student_number) VALUES ($1, $2, $3)", name, email, studid
  get_students.to_json
rescue ex : PQ::PQError
  halt env, status_code: 409, response: ex.message
end

get "/students" do |env|
  get_students.to_json
end

get "/today" do |env|
  today_start = Time.local.at_beginning_of_day
  today_end = Time.local.at_end_of_day
  result = [] of String

  db.query "SELECT name FROM users LEFT JOIN meetings ON users.id = meetings.user_id WHERE at BETWEEN $1 AND $2 ORDER BY users.name", today_start, today_end do |rs|
    rs.each do
      name = rs.read(String)
      result << name
    end
  end
  result.to_json
end

Signal::INT.trap do
  puts "Shutting down!"
  db.close
end

Kemal.run do |config|
  # config.server.not_nil!.bind_tcp 1234
  config.server.not_nil!.bind_unix "/tmp/attendance.socket"
end
