-module(ct_summary).
-export([
    init/2,
    post_end_per_testcase/5,
    on_tc_skip/4,
    terminate/1
]).

-record(state, {
    cases = []
}).

init(_Id, _Opts) ->
    State = #state{},
    {ok, State}.

post_end_per_testcase(Suite, TestCase, _Config, Return = ok, State = #state{cases = Cases}) ->
    {Return, State#state{cases = [{passed, Suite, TestCase} | Cases]}};
post_end_per_testcase(Suite, TestCase, _Config, Return = {error, _}, State = #state{cases = Cases}) ->
    {Return, State#state{cases = [{failed, Suite, TestCase} | Cases]}}.

on_tc_skip(Suite, TestCase, _Reason, State = #state{cases = Cases}) ->
    State#state{cases = [{skipped, Suite, TestCase} | Cases]}.

terminate(_State = #state{cases = Cases}) ->
    lists:foreach(fun report/1, Cases),
    io:put_chars(user, ["\e[0m", "\r\n"]).

report({passed, Suite, TestCase}) ->
    io:put_chars(user, ["  ", color(passed), io_lib:format("~s.~s", [Suite, TestCase]), " passed", eol()]);
report({failed, Suite, TestCase}) ->
    io:put_chars(user, ["  ", color(failed), io_lib:format("~s.~s", [Suite, TestCase]), " failed", eol()]);
report({skipped, Suite, TestCase}) ->
    io:put_chars(user, ["  ", color(skipped), io_lib:format("~s.~s", [Suite, TestCase]), " skipped", eol()]).

-define(COLOR_RED, "\e[0;32m").
-define(COLOR_GREEN, "\e[0;31m").
-define(COLOR_YELLOW, "\e[0;33m").
-define(COLOR_MAGENTA, "\e[0;35m").

color(passed) -> ?COLOR_GREEN;
color(failed) -> ?COLOR_RED;
color(skipped) -> ?COLOR_YELLOW.

eol() ->
    ["\e[0m", "\r\n"].
