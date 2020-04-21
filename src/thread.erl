-module(thread).
-include("include/thread.hrl").
-include("include/post.hrl").
-include("include/user.hrl").
-include_lib("eunit/include/eunit.hrl").
-export([creat_thread_table/1, add_thread/2, get_thread/2]).

creat_thread_table(Ref) ->
	odbc:sql_query(Ref, "CREATE TABLE threads(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, uid INTEGER);").

add_thread(Ref, Thread) ->
	#thread{name=TName, user=User, posts=[Post1|_]} = Thread,
	#user{id=Uid} = User,
	post:add_post(Ref, Post1),
	TName2 = {{sql_char, length(TName)}, [TName]},
	Uid2 = {sql_integer, [Uid]},
	odbc:param_query(Ref, "INSERT INTO threads(name, uid) VALUES(?, ?);", [TName2, Uid2]).

get_thread(Ref, Id) when is_integer(Id) ->
	{selected, _, [{_, Name, Uid}]} = odbc:param_query(Ref, "SELECT * FROM threads WHERE id == ?;", [{sql_integer, [Id]}]),
	{selected, _, Posts} = odbc:param_query(Ref, "SELECT * FROM posts WHERE tid == ?;", [{sql_integer, [Id]}]),
	User = user:get_user(Ref, Uid),
	Posts2 = post:selected2posts(Ref, Posts),
	#thread{name=Name, user=User, posts=Posts2, id=Id}.

add_thread_test() ->
	odbc:start(),
	{ok, Ref} = odbc:connect("DSN=erlforum", []),
	user:creat_user_table(Ref),
	post:creat_post_table(Ref),
	creat_thread_table(Ref),
	User1 = #user{id=1, name="noah", is_admin=true},
	Post1 = #post{user=User1, id=1, contents="hi", tid=1, is_deleted=false},
	Thread1 = #thread{name="hi", user=User1, posts=[Post1], id=1},
	user:add_user(Ref, User1),
	add_thread(Ref, Thread1),
	Thread2 = get_thread(Ref, 1),
	?assert(Thread1 =:= Thread2),
	odbc:disconnect(Ref),
	odbc:stop(),
	file:delete("db/database.db").