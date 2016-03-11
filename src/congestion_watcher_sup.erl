%%%%----------------------------------------------------------------------
%%% Copyright (c) 2007-2016 Hibari developers.  All rights reserved.
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
%%% File    : congestion_watcher_sup.erl
%%% Purpose : congestion watcher supervisor
%%%----------------------------------------------------------------------

-module(congestion_watcher_sup).

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the supervisor
%%--------------------------------------------------------------------
start_link([]) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================
%%--------------------------------------------------------------------
%% Func: init(Args) -> {ok,  {SupFlags,  [ChildSpec]}} |
%%                     ignore                          |
%%                     {error, Reason}
%% Description: Whenever a supervisor is started using
%% supervisor:start_link/[2,3], this function is called by the new process
%% to find out about restart strategy, maximum restart frequency and child
%% specifications.
%%--------------------------------------------------------------------
init([]) ->
    %% Hint:
    %% Child_spec = [Name, {M, F, A},
    %%               Restart, Shutdown_time, Type, Modules_used]

    {ok, CWConfig} = application:get_env(congestion_watcher, congestion_watcher_config),
    if (CWConfig =:= []) ->
        throw({missing_argument, congestion_watcher_config});
    true ->
        ok
    end,

    %% In this example, we'll run congestion_watcher:server:start_link().
    Worker =
        {congestion_watcher_server, {congestion_watcher_server, start_link, [CWConfig]},
         permanent, 2000, worker, [congestion_watcher_server]},

    %% If Mnesia or the ticket server become unavailable, there's no
    %% use in a dozen or more retry attempts repeating in < 1 sec.
    {ok, {{one_for_one, 2, 10}, [
                                  Worker
                                 ]}}.

%%====================================================================
%% Internal functions
%%====================================================================
