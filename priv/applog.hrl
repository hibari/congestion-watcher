%%%----------------------------------------------------------------------
%%% Copyright (c) 2007-2010 Gemini Mobile Technologies, Inc.  All rights reserved.
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
%%% File    : applog.erl
%%% Purpose : application log events
%%%----------------------------------------------------------------------

-include("gmt_event_h.hrl").


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
%% @doc MNESIA DISKMON appm class
%%
-define(APPLOG_ERRORCODE_APPM(X),
        ?APPLOG_013 + ?APPLOG_CLASS_APPM + X).

%%
%% @doc cause      The size of the item being monitored has returned under the low water mark.
%% @doc effect     The item is no longer congested.
%% @doc action     No action required.
%% @doc monitor    Yes
%%
-define(APPLOG_APPM_001, ?APPLOG_ERRORCODE_APPM(1)).

%%
%% @doc cause      The size of the item being monitored has grown above the warning water mark.
%% @doc effect     If the item continues to grow, the service will reach the high water mark.
%% @doc action     The configured water mark is too low or the external servers are too slow for the current load.
%% @doc monitor    Yes
%%
-define(APPLOG_APPM_002, ?APPLOG_ERRORCODE_APPM(2)).

%%
%% @doc cause      The size of the item being monitored has grown above the high water mark and is congested.
%% @doc effect     The item will run in restricted mode until the size returns below the low water mark.
%% @doc action     The configured water mark is too low or the external servers are too slow for the current load.
%% @doc monitor    Yes
%%
-define(APPLOG_APPM_003, ?APPLOG_ERRORCODE_APPM(3)).

%%
%% @doc cause      The configuration file could not be reloaded for some reason.
%% @doc effect     The previous configuration will continue to be used.
%% @doc action     Update the configuration file as required and retry.
%% @doc monitor    Yes
%%
-define(APPLOG_APPM_004, ?APPLOG_ERRORCODE_APPM(4)).

%%
%% @doc cause      The process to restrict is currently unavailable.
%% @doc effect     No restriction is possible this check.
%% @doc action     Confirm the correct name of the process if problem persists.
%% @doc monitor    Yes
%%
-define(APPLOG_APPM_005, ?APPLOG_ERRORCODE_APPM(5)).

%%
%% @doc cause      An error was encountered checking congestion using a configured function.
%% @doc effect     A size of 0 is assumed for this entry.
%% @doc action     Check the configuration is using the correct function or contact gemini support
%% @doc monitor    Yes
%%
-define(APPLOG_APPM_006, ?APPLOG_ERRORCODE_APPM(6)).

%%
%% @doc cause      An error was encountered parsing the configuration file
%% @doc effect     Server will not start or old configuration will be kept
%% @doc action     Check the configuration is correct
%% @doc monitor    Yes
%%
-define(APPLOG_APPM_007, ?APPLOG_ERRORCODE_APPM(7)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
%% @doc MNESIA DISKMON info class
%%
-define(APPLOG_ERRORCODE_INFO(X),
        ?APPLOG_013 + ?APPLOG_CLASS_INFO + X).

%%
%% @doc cause      The congestion_watcher reloaded its configuration file.
%% @doc effect     Congestion will use new configuration.
%% @doc action     Informational
%%
-define(APPLOG_INFO_001, ?APPLOG_ERRORCODE_INFO(1)).

%%
%% @doc cause      Mark messages are enabled
%% @doc effect     Informational
%% @doc action     Informational
%%
-define(APPLOG_INFO_002, ?APPLOG_ERRORCODE_INFO(2)).
