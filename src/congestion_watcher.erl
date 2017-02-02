%%%----------------------------------------------------------------------
%%% Copyright (c) 2007-2017 Hibari developers.  All rights reserved.
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
%%% File    : congestion_watcher.erl
%%% Purpose : congestion watcher application
%%%----------------------------------------------------------------------

-module(congestion_watcher).

-behaviour(application).

%% application callbacks
-export([start/0, start/2, stop/1]).
-export([start_phase/3, prep_stop/1, config_change/3]).

%%%----------------------------------------------------------------------
%%% Callback functions from application
%%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%% Func: start/2
%% Returns: {ok, Pid}        |
%%          {ok, Pid, State} |
%%          {error, Reason}
%%----------------------------------------------------------------------
start() ->
    start(normal, []).

start(_Type, StartArgs) ->
    case congestion_watcher_sup:start_link(StartArgs) of
        {ok, _Pid} = Ok ->
            Ok;
        Error ->
            Error
    end.

%% Lesser-used callbacks....

start_phase(_Phase, _StartType, _PhaseArgs) ->
    ok.

prep_stop(State) ->
    State.

config_change(_Changed, _New, _Removed) ->
    ok.


%%----------------------------------------------------------------------
%% Func: stop/1
%% Returns: any
%%----------------------------------------------------------------------
stop(_State) ->
    ok.

%%%----------------------------------------------------------------------
%%% Internal functions
%%%----------------------------------------------------------------------
