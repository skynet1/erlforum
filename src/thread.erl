-module(thread).
-include("thread.hrl").
-include("post.hrl").
-include("user.hrl").
-include_lib("eunit/include/eunit.hrl").
-export([render_thread_head/1, get_all_threads/1, creat_thread_table/1, add_thread/2, get_thread/2, render_thread/1]).

creat_thread_table(Ref) ->
	odbc:sql_query(Ref, "CREATE TABLE threads(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE, uid INTEGER);").

add_thread(Ref, Thread) ->
	#thread{name=TName, user=User, posts=[Post1|_]} = Thread,
	#user{id=Uid} = User,
	TName2 = {{sql_char, length(TName)}, [TName]},
	Uid2 = {sql_integer, [Uid]},
	odbc:param_query(Ref, "INSERT INTO threads(name, uid) VALUES(?, ?);", [TName2, Uid2]),
	{selected, _, [{Tid}]} = odbc:param_query(Ref, "SELECT id FROM threads WHERE name == ?;", [TName2]),
	post:add_post(Ref, Post1, Tid).

get_thread(Ref, Id) when is_integer(Id) ->
	{selected, _, [{_, Name, Uid}]} = odbc:param_query(Ref, "SELECT * FROM threads WHERE id == ?;", [{sql_integer, [Id]}]),
	{selected, _, Posts} = odbc:param_query(Ref, "SELECT * FROM posts WHERE tid == ?;", [{sql_integer, [Id]}]),
	User = user:get_user(Ref, Uid),
	Posts2 = post:selected2posts(Ref, Posts),
	#thread{name=Name, user=User, posts=Posts2, id=Id};

get_thread(Ref, Name) when is_list(Name) ->
	{selected, _, [{Id, _, Uid}]} = odbc:param_query(Ref, "SELECT * FROM threads WHERE name == ?;", [{{sql_char, length(Name)}, [Name]}]),
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
	user:add_user(Ref, User1, "pass"),
	add_thread(Ref, Thread1),
	Thread2 = get_thread(Ref, 1),
	?assert(Thread1#thread.name =:= Thread2#thread.name),
	odbc:disconnect(Ref),
	odbc:stop(),
	file:delete("db/database.db").

render_thread(Thread) ->
	#thread{name=TName, posts=Posts} = Thread,
	{html, "<h1>" ++ TName ++ "</h1><br/>" ++ post:render_posts(Posts)}.

get_all_threads_intern([], _) -> [] ;
get_all_threads_intern([{Thread}|Tail], Ref) ->
	[get_thread(Ref, Thread)|get_all_threads_intern(Tail, Ref)].

get_all_threads(Ref) ->
	{selected, _, List} = odbc:sql_query(Ref, "SELECT id FROM threads;"),
	get_all_threads_intern(List, Ref).

get_all_threads_test() ->
	odbc:start(),
	{ok, Ref} = odbc:connect("DSN=erlforum", []),
	user:creat_user_table(Ref),
	post:creat_post_table(Ref),
	creat_thread_table(Ref),
	User1 = #user{id=1, name="nate", is_admin=true},
	Post1 = #post{user=User1, id=1, contents="hi", tid=1, is_deleted=false},
	Thread1 = #thread{name="hello", user=User1, posts=[Post1], id=1},
	user:add_user(Ref, User1, "word"),
	add_thread(Ref, Thread1),
	X = get_all_threads(Ref),
	?assert(length(X) =:= 1),
	odbc:disconnect(Ref),
	odbc:stop(),
	file:delete("db/database.db").

render_thread_head(Thread) when is_record(Thread, thread) ->
	#thread{name=Name, id=Id, user=User, posts=[Post1|_]} = Thread,
	UserName = User#user.name,
	"<tr><td>" ++ UserName ++ "</td><td><a href=\"/thread.yaws?tid=" ++ integer_to_list(Id) ++ "\" >" ++ Name ++ "</a></td></tr><tr><td><center>" ++ post:shorten(Post1) ++ "</center></td></tr></a>".
