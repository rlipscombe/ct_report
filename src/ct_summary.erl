-module(ct_summary).
-export([
    init/2,
    pre_init_per_testcase/4,
    post_end_per_testcase/5,
    on_tc_skip/4,
    terminate/1
]).

-include("colors.hrl").
-include("glyphs.hrl").

-record(state, {
    % erlang:monotonic_time, native units.
    case_started_at,
    % list of completed test cases, with results
    cases = []
}).

-define(APPLICATION, ct_report).

init(_Id, _Opts) ->
    % Load application environment.
    application:load(?APPLICATION),

    % For some reason, Erlang doesn't output Unicode correctly when -noinput or -noshell are specified.
    % Fix that by setting the option back.
    io:setopts(standard_io, [{encoding, unicode}]),
    State = #state{},
    {ok, State}.

pre_init_per_testcase(_Suite, _TestCase, InitData, State) ->
    {InitData, State#state{case_started_at = erlang:monotonic_time()}}.

post_end_per_testcase(
    Suite,
    TestCase,
    _Config,
    Return = ok,
    State = #state{case_started_at = StartedAt, cases = Cases}
) ->
    EndedAt = erlang:monotonic_time(),
    {Return, State#state{cases = [{passed, Suite, TestCase, StartedAt, EndedAt} | Cases]}};
post_end_per_testcase(
    Suite,
    TestCase,
    _Config,
    Return = {error, _},
    State = #state{case_started_at = StartedAt, cases = Cases}
) ->
    EndedAt = erlang:monotonic_time(),
    {Return, State#state{cases = [{failed, Suite, TestCase, StartedAt, EndedAt} | Cases]}}.

on_tc_skip(Suite, TestCase, _Reason, State = #state{case_started_at = StartedAt, cases = Cases}) ->
    EndedAt = erlang:monotonic_time(),
    State#state{cases = [{skipped, Suite, TestCase, StartedAt, EndedAt} | Cases]}.

terminate(_State = #state{cases = Cases}) ->
    lists:foreach(fun report/1, Cases),
    io:put_chars(user, ["\e[0m", "\r\n"]).

report({passed, Suite, TestCase, StartedAt, EndedAt}) ->
    report_test_case(
        color(passed), ?TEST_PASSED_GLYPH, Suite, TestCase, " passed", StartedAt, EndedAt
    );
report({failed, Suite, TestCase, StartedAt, EndedAt}) ->
    report_test_case(
        color(failed), ?TEST_FAILED_GLYPH, Suite, TestCase, " failed", StartedAt, EndedAt
    );
report({skipped, Suite, TestCase, StartedAt, EndedAt}) ->
    report_test_case(
        color(skipped), ?TEST_SKIPPED_GLYPH, Suite, TestCase, " skipped", StartedAt, EndedAt
    ).

report_test_case(Color, Glyph, Suite, TestCase, Suffix, StartedAt, EndedAt) ->
    io:put_chars(user, [
        "  ",
        Color,
        Glyph,
        " ",
        io_lib:format("~s.~s", [Suite, TestCase]),
        Suffix,
        format_elapsed_time(EndedAt - StartedAt),
        eol()
    ]).

color(passed) -> get_env_color(passed, ?COLOR_DARK_GREEN);
color(failed) -> get_env_color(failed, ?COLOR_DARK_RED);
color(skipped) -> get_env_color(skipped, ?COLOR_DARK_YELLOW).

get_env_color(Key, Default) ->
    proplists:get_value(Key, application:get_env(ct_report, colors, []), Default).

format_elapsed_time(Elapsed) ->
    ElapsedMs = erlang:convert_time_unit(Elapsed, native, millisecond),
    [?COLOR_BRIGHT_BLACK, " (", format_elapsed_time_ms(ElapsedMs), ")"].

format_elapsed_time_ms(ElapsedMs) ->
    % TODO: Human readable timestamps for longer periods.
    io_lib:format("~Bms", [ElapsedMs]).

eol() ->
    ["\e[0m", "\r\n"].
