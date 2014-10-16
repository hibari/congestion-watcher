%%%%----------------------------------------------------------------------
%%% Copyright (c) 2007-2014 Hibari developers.  All rights reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%
%%% File    : congestion_watcher_server.erl
%%% Purpose : congestion watcher server
%%%----------------------------------------------------------------------

%% This process reads a configuration file and watches different entities for
%% congestions. The entity is congested when the size of the entity reaches the
%% high water mark and will remain congested until the low water mark is reached.
%% The warn water mark is purely for logging purposes.
%%
%% When congested, the process will send a congested message to a named process
%% who is responsible for restriction. It will continue to send further congested
%% messages every interval after that until the entity is no longer congested. The
%% restriction process should remain restricted until a suggested timeout has passed
%% without it receiving further restriction messages.
%%
%% if low < warn < high
%%    alert logged at warn, then at high.
%% if warn < low < high
%%    alert logged at low, then at high.
%% if low < high < warn
%%    alert never logged at warn, log when high.

-module(congestion_watcher_server).

-behaviour(gen_server).

-include("gmt_elog.hrl").
-include_lib("kernel/include/file.hrl").

-define(SERVER, ?MODULE).

%% External exports
-export([start_link/1, reload_config/0, check_size/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-ifdef(namespaced_dict_and_queue).
-type cw_dict()  :: dict:dict().
-else.
-type cw_dict()  :: dict().
-endif.

-record(state, {
          config                    :: string(),
          timer_list                :: list({ok, reference()}),
          hlw_state = dict:new()    :: cw_dict()
         }).

-record(winfo, {
          level = low :: low|warn|high,
          last  = 0   :: non_neg_integer(),
          max   = 0   :: non_neg_integer()
         }).

-record(watchee_config, {
          label            :: atom(),             % mnesia:SIZEKIND:TABLE -or- gen_server:items:NAME (SIZEKIND is bytes or items)
                                                % -or- apply:module:function - a function that calculates the size
          interval         :: non_neg_integer(),  % congestion is checked every interval number of msec.
          low_mark         :: non_neg_integer(),
          warn_mark        :: non_neg_integer(),
          high_mark        :: non_neg_integer(),
          restrict_who     :: atom(),            % process needing to be told to restrict -or- undefined
          restrict_msec    :: non_neg_integer(), % restrict for how many msec before (longer than interval)
          restrict_what    :: string()           % name of that which to restrict (list of : separated strings)
         }).

%%%----------------------------------------------------------------------
%%% API
%%%----------------------------------------------------------------------
start_link(Config) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [Config], []).

%% @spec () -> ok | reload_error
reload_config() ->
    gen_server:call(?MODULE, reload_config).

%% This function may take time to complete depending on what get_size() does.
%% For example gen_server calls may block. This function is usually executed
%% in a process spawned by a timer. The CWPid is the pid of the
%% congestion_watcher_server process.
check_size(CWPid, WC) ->
    case WC#watchee_config.label of
        mark ->
            CWPid ! {mark, WC};
        Label ->
            Size = get_size(Label),
            CWPid ! {check_congestion, WC, Size}
    end.

%%%----------------------------------------------------------------------
%%% Callback functions from gen_server
%%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%%----------------------------------------------------------------------
init([Config]) ->
    reset(#state{config=Config}).

reset(State) ->
    Config = State#state.config,
    {ok, WatcheeConfigs} = parse_pseudo_csv(Config),
    TimerList = lists:map(
                  fun(WC) ->
                          Interval = WC#watchee_config.interval,
                          spawn(?MODULE, check_size, [self(), WC]),      % setup an immediate check
                          {ok, _Ref} = timer:apply_interval(Interval, ?MODULE, check_size, [self(), WC])
                  end, WatcheeConfigs),
    HLWDict = resetAllStates(WatcheeConfigs, #winfo{}, State#state.hlw_state, dict:new()),
    {ok, #state{config=Config, timer_list=TimerList, hlw_state=HLWDict}}.

%% use state in Dict or set it to specific default Level
resetAllStates([H|T], Level, OldDict, NewDict) ->
    Label = H#watchee_config.label,
    Value = case dict:is_key(Label, OldDict) of
                true ->
                    dict:fetch(Label, OldDict);
                false ->
                    Level
            end,
    resetAllStates(T, Level, OldDict, dict:store(Label, Value, NewDict));
resetAllStates([], _Level, _OldDict, NewDict) ->
    NewDict.

%%----------------------------------------------------------------------
%% Func: handle_call/3
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%%----------------------------------------------------------------------
handle_call(reload_config, _From, State) ->
    stop_timers(State#state.timer_list),
    try begin
            {ok, ReloadedState} = reset(State),
            ?ELOG_INFO("Reload ~p complete.", [State#state.config]),
            {reply, ok, ReloadedState}
        end
    catch
        _:Err ->
            ?ELOG_WARNING("Reload failed with '~p' for file ~p",
                          [Err, State#state.config]),
            {reply, reload_error, State}
    end;
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%----------------------------------------------------------------------
%% Func: handle_cast/2
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%%----------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%----------------------------------------------------------------------
%% Func: handle_info/2
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%%----------------------------------------------------------------------
handle_info({mark, WC}, State) ->
    NewState = do_mark(WC, State),
    {noreply, NewState};
handle_info({check_congestion, WC, Size}, State) ->
    NewState = do_check_congestion(WC, Size, State),
    {noreply, NewState};
handle_info(_Info, State) ->
    {noreply, State}.

%%----------------------------------------------------------------------
%% Func: terminate/2
%% Purpose: Shutdown the server
%% Returns: any (ignored by gen_server)
%%----------------------------------------------------------------------
terminate(_Reason, State) ->
    stop_timers(State#state.timer_list),
    ok.

%%----------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%%----------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%----------------------------------------------------------------------
%%% Internal functions
%%%----------------------------------------------------------------------

stop_timers(TimerList) ->
    lists:foreach(fun({ok, Ref}) -> timer:cancel(Ref) end, TimerList).

what_info(What, State) ->
    HLWDict = State#state.hlw_state,
    Labels = string:tokens(What, ";"),   %% YAS!
    what_info(Labels, HLWDict, []).

what_info([], _HLWDict, Acc) ->
    lists:reverse(Acc);
what_info([Label|T], HLWDict, Acc) ->
    case dict:find(list_to_atom(Label), HLWDict) of
        {ok, WInfo} ->
            what_info(T, HLWDict, [{WInfo#winfo.last, WInfo#winfo.max}|Acc]);
        _ ->
            what_info(T, HLWDict, [undefined|Acc])
    end.

do_mark(WC, State) ->
    %% Use timestamp in same format as logfile to monitor logging timeliness.
    Timestamp = gmt_util:cal_to_bignumstr(calendar:now_to_local_time(erlang:now())),
    What = WC#watchee_config.restrict_what,
    WhatInfo = what_info(What, State),
    ?ELOG_INFO("mark: ~s ~p", [Timestamp, WhatInfo]),
    State.

update_winfo(Size, WInfo) ->
    update_winfo(WInfo#winfo.level, Size, WInfo).

update_winfo(Level, Size, WInfo) ->
    Max = erlang:max(WInfo#winfo.max, Size),
    WInfo#winfo{level=Level, last=Size, max=Max}.

do_check_congestion(WC, Size, State) ->
    Label = WC#watchee_config.label,
    HLWDict = State#state.hlw_state,
    WInfo = dict:fetch(Label, HLWDict),
    HLWLevel = WInfo#winfo.level,
    Low = WC#watchee_config.low_mark,
    Warn = WC#watchee_config.warn_mark,
    High = WC#watchee_config.high_mark,
    if
        Size =< Low ->
            if HLWLevel =/= low ->
                    ?ELOG_ERROR("~p cleared, current_size=~p,low_water_mark=~p",
                                [Label, Size, Low]),
                    NewHLWDict = dict:store(Label, update_winfo(low, Size, WInfo), HLWDict),
                    State#state{hlw_state=NewHLWDict};
               true ->
                    NewHLWDict = dict:store(Label, update_winfo(Size, WInfo), HLWDict),
                    State#state{hlw_state=NewHLWDict}
            end;
        true ->
            {NewHLWLevel, NewState} =
                if
                    (Size >= Warn) and (Size < High) and (HLWLevel =:= low) ->
                        ?ELOG_ERROR("~p warning at size=~p,warning_water_mark=~p",
                                    [Label, Size, Warn]),
                        NewHLWDict = dict:store(Label, update_winfo(warn, Size, WInfo), HLWDict),
                        {warn, State#state{hlw_state=NewHLWDict}};
                    true ->
                        if
                            (Size >= High) and (HLWLevel =/= high) ->
                                ?ELOG_ERROR("~p is congested. current_size=~p,high_water_mark=~p",
                                            [Label, Size, High]),
                                NewHLWDict = dict:store(Label, update_winfo(high, Size, WInfo), HLWDict),
                                {high, State#state{hlw_state=NewHLWDict}};
                            true ->
                                NewHLWDict = dict:store(Label, update_winfo(Size, WInfo), HLWDict),
                                {HLWLevel, State#state{hlw_state=NewHLWDict}}
                        end
                end,

            %% If state is high, send restriction message
            Who = WC#watchee_config.restrict_who,
            if
                (NewHLWLevel =:= high) andalso (Who =/= undefined) ->
                    _ = case Who of
                            halt_vm ->
                                Slogan = io_lib:format("halt_vm: ~p congested. current_size=~p, high_water_mark=~p", [Label, Size, High]),
                                erlang:halt(lists:flatten(Slogan));
                            Who ->
                                What = WC#watchee_config.restrict_what,
                                TimeoutMS = WC#watchee_config.restrict_msec,
                                Msg = {restrict, What, TimeoutMS},
                                case global:whereis_name(Who) of
                                    undefined ->
                                        ?ELOG_ERROR("Cannot restrict '~p'. Process not available.",
                                                    [Who]);
                                    PidOrPort ->
                                        PidOrPort ! Msg
                                end
                        end,
                    ok;
                true ->
                    ok
            end,
            NewState
    end.

%% Returns the size of an entity identified by the Label
get_size(Label) ->
    OrigT = list_to_tuple(string:tokens(atom_to_list(Label), ":")),
    T = case tuple_size(OrigT) of
            2 ->
                %% convert oldstyle format: mnesia:table -> mnesia:items:table
                {element(1, OrigT), "items", element(2, OrigT)};
            3 ->
                %% Anything other than 3 should crash.
                OrigT
        end,
    Target = list_to_atom(element(3, T)),
    SizeKind = list_to_atom(element(2, T)),
    WordSize = erlang:system_info(wordsize),
    case list_to_atom(element(1, T)) of
        mnesia ->
            case SizeKind of
                %% crash if neither items/bytes
                items ->
                    mnesia:table_info(Target, size);
                bytes ->
                    mnesia:table_info(Target, memory) * WordSize  %% multiply by bytes-per-word
            end;
        gen_server ->
            case whereis(Target) of
                undefined ->
                                                % The gen_servers can be created dynamically so may not
                                                % be available. If not available, size should be 0.
                    0;
                _PidOrPort ->
                    case SizeKind of
                        %% currently only items is supported
                        items ->
                            gmt_genutil:server_call(Target, {get_info, size})
                    end
            end;
        'apply' ->
            try begin
                    %% SizeKind => module, Target => Function
                    Size = erlang:apply(SizeKind,Target,[]),
                    if
                        is_integer(Size) ->
                            Size;
                        true ->
                            throw(lists:flatten(io_lib:format("Bad return type: ~p", [Size])))
                    end
                end
            catch
                _:Ex ->
                    ?ELOG_WARNING("Apply failed with '~p' for function ~p:~p/0",
                                  [Ex, SizeKind, Target]),
                    0 % configuration errors shouldn't lead to congestion.
            end
    end.

%% returns {ok, list_of_configs}
parse_pseudo_csv(Path) ->
    {ok, F} = file:open(Path, [read]),
    try begin
            {ok, _Config} = parse_pseudo_csv(read_line(F), F, [])
        end
    catch
        _:Ex ->
            ?ELOG_WARNING("Parse error: ~p ~p",
                          [Ex, erlang:get_stacktrace()]),
            parse_error
    after
        ok = file:close(F)
    end.

parse_pseudo_csv(eof, _File, Acc) ->
    {ok, lists:reverse(Acc)};
parse_pseudo_csv([$#|_], File, Acc) ->
    parse_pseudo_csv(read_line(File), File, Acc);
parse_pseudo_csv([], File, Acc) ->
    parse_pseudo_csv(read_line(File), File, Acc);
parse_pseudo_csv(Line, File, Acc) ->
    T = list_to_tuple(string:tokens(Line, ",")),
    Label = list_to_atom(element(1, T)),
    Enabled = gmt_util:boolean_ify(list_to_atom(element(3, T))),
    if
        Enabled ->
            case tuple_size(T) of
                9 ->
                    B = #watchee_config{label          = Label,
                                        interval       = list_to_integer(element(2, T)),
                                                % skip enabled(3) as it's covered in this if
                                        low_mark       = gmt_util:list_to_bytes(element(4, T)),
                                        warn_mark      = gmt_util:list_to_bytes(element(5, T)),
                                        high_mark      = gmt_util:list_to_bytes(element(6, T)),
                                        restrict_who   = list_to_atom(element(7, T)),
                                        restrict_msec  = list_to_integer(element(8, T)),
                                        restrict_what  = element(9, T)},
                    parse_pseudo_csv(read_line(File), File, [B|Acc]);
                _ ->
                    throw(bad_field_count)
            end;
        true ->
            parse_pseudo_csv(read_line(File), File, Acc)
    end.

%% Read in a line and return list of characters (string)
read_line(File) ->
    read_line(file:read(File, 1), File, []).

read_line(eof, _, _) ->
    eof;
read_line({ok, "\n"}, _, Acc) ->
    lists:reverse(Acc);                         % Built-in "chomp"
read_line({ok, [C]},  File, Acc) ->
    read_line(file:read(File, 1), File, [C|Acc]).
