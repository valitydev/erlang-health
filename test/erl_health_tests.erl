-module(erl_health_tests).
-include_lib("eunit/include/eunit.hrl").

%%

-export([handle_event/2]).

%%

-type testcase() :: {_, fun()}.

-spec test() ->
    _.

-spec empty_test_() ->
    testcase().
empty_test_() ->
    _ = application:ensure_all_started(erl_health),
    ?_assertEqual(
        {passing, #{}},
        erl_health:check(#{})
    ).

-spec service_name_test_() ->
    testcase().
service_name_test_() ->
    ?_assertEqual(
        {passing, #{service => <<?MODULE_STRING>>}},
        erl_health:check(#{
            service => {erl_health, service, [<<?MODULE_STRING>>]}
        })
    ).

-spec memory_test_() ->
    [testcase()].
memory_test_() ->
    [
        ?_assertMatch(
            {critical, #{mem := #{free := _, total := _, limit := 0}}},
            erl_health:check(#{
                mem => {erl_health, memory, [0]}
            })
        ),
        ?_assertMatch(
            {passing, #{mem := #{free := _, total := _, limit := 100}}},
            erl_health:check(#{
                mem => {erl_health, memory, [100]}
            })
        )
    ].

-spec disk_test_() ->
    [testcase()].
disk_test_() ->
    [
        ?_assertMatch(
            {passing, #{dsk := #{path := <<"/">>, limit := 100}}},
            erl_health:check(#{
                dsk => {erl_health, disk, ["/", 100]}
            })
        )
    ].

-spec compose_test_() ->
    [testcase()].
compose_test_() ->
    Passing = fun () -> {passing, 31337} end,
    Warning = fun () -> {warning, 420} end,
    Critical = fun () -> {critical, 69} end,
    [
        ?_assertMatch(
            {passing, #{check1 := _, check2 := _, check3 := _}},
            erl_health:check(#{check1 => Passing, check2 => Passing, check3 => Passing})
        ),
        ?_assertMatch(
            {warning, #{check1 := _, check2 := _, check3 := _}},
            erl_health:check(#{check1 => Passing, check2 => Warning, check3 => Passing})
        ),
        ?_assertMatch(
            {critical, #{check1 := _, check2 := _, check3 := _}},
            erl_health:check(#{check1 => Passing, check2 => Critical, check3 => Warning})
        )
    ].

-spec event_handler_test_() ->
    [testcase()].
event_handler_test_() ->
    Passing = fun () -> {passing, 31337} end,
    Failing = fun () -> erlang:apply(?MODULE, nonexistent, []) end,
    [
        ?_test(begin
            ?assertMatch({passing, _}, erl_health:check(#{
                ?FUNCTION_NAME => #{runner => Passing, event_handler => {?MODULE, []}}
            })),
            ?assertEqual(
                [
                    {?FUNCTION_NAME, started},
                    {?FUNCTION_NAME, {finished, {passing, 31337}}}
                ],
                flush()
            )
        end),
        ?_test(begin
            ?assertError(_, erl_health:check(#{
                ?FUNCTION_NAME => #{runner => Failing, event_handler => {?MODULE, []}}
            })),
            ?assertMatch(
                [
                    {?FUNCTION_NAME, started},
                    {?FUNCTION_NAME, {failed, {error, undef, _}}}
                ],
                flush()
            )
        end)
    ].

flush() ->
    receive Msg ->
        [Msg | flush()]
    after 0 ->
        []
    end.

-spec default_event_handler_test_() ->
    [testcase()].
default_event_handler_test_() ->
    Passing = fun () -> {critical, 31337} end,
    Failing = fun () -> erlang:apply(?MODULE, nonexistent, []) end,
    EvHandler = {erl_health_event_handler, []},
    [
        ?_assertMatch(
            {critical, _},
            erl_health:check(#{?FUNCTION_NAME => #{runner => Passing, event_handler => EvHandler}})
        ),
        ?_assertError(
            _,
            erl_health:check(#{?FUNCTION_NAME => #{runner => Failing, event_handler => EvHandler}})
        )
    ].

%%

-spec handle_event(erl_health:event(), _) ->
    _.
handle_event(Event, _) ->
    self() ! Event.
