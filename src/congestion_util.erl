%%%----------------------------------------------------------------------
%%% Copyright (c) 2009-2017 Hibari developers.  All rights reserved.
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
%%% File    : congestion_util.erl
%%% Purpose : congestion utilities
%%%----------------------------------------------------------------------

-module(congestion_util).

%% External exports
-export([process_count/0,mbox_count/0,process_maxmem/0]).

%% return the current erlang vm process count
process_count() ->
    erlang:system_info(process_count).

%% return the max mbox size of all erlang processes
mbox_count() ->
    lists:foldl(fun(P, AccIn) ->
                                case process_info(P,message_queue_len) of
                                    {message_queue_len, ML} when ML > AccIn ->
                                            ML;
                                    _ ->
                                            AccIn
                                end
                        end,
                        0,
                        processes()).

%% return the max memory size of all erlang processes in this vm
process_maxmem() ->
    lists:foldl(fun(P, AccIn) ->
                    case process_info(P, memory) of
                        {memory, Size} when Size > AccIn ->
                            Size;
                        _ ->
                            AccIn
                    end
                end,
                0,
                processes()).
