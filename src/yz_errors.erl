%% -------------------------------------------------------------------
%%
%% Copyright (c) 2012 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc Functionality related to increasing visibility of errors previously
%% trackable in logs.

-module(yz_errors).
-behavior(gen_server).
-compile(export_all).
-export([code_change/3,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         init/1,
         terminate/2]).
-export([store_solr_error/2,
         setup_error_bucket/0]).
-include("yokozuna.hrl").

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%% @doc There are certain types of errors in Solr that cannot set _yz_err = 1 on the original index 
%%      because Solr cannot index the document. This function will store the encountered error message
%%      in a bucket type called "yz_err", the bucket and key will be the <original bucket type>.<original bucket>, 
%%      and the key will be the original key. This funciton is called from catch clause index/3.
store_solr_error({{?YZ_ERROR_INDEX,_},_}=BKey, Err) ->
    lager:debug("YZ_ERR_PATCH: Error encountered in yz_kv:index, first submission to error index failed. Preventing recursion by exiting, BKey = ~p, Err = ~p", [BKey, Err]),
    ok;
store_solr_error(BKey, Err) ->
    gen_server:cast(?MODULE, {store_error, BKey, Err}).

%% @doc Create an index and bucket type to hold errors encountered in index/3
setup_error_bucket() ->
    ok = maybe_setup_error_index(yz_index:exists(?YZ_ERROR_INDEX)),
    Type = riak_core_bucket_type:get(?YZ_ERROR_INDEX),
    ok = maybe_setup_error_bucket_type(Type),
    ok.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%%===================================================================
%%% Callbacks
%%%===================================================================

init([]) ->
    {ok, #state{}}.

handle_cast({store_error, BKey, Err}, S) ->
    try
        lager:debug("YZ_ERR_PATCH: Error encountered in yz_kv:index, submitting to yz_err index, BKey = ~p, Err = ~p", [BKey, Err]),

        ErrStr = list_to_binary(lists:flatten(io_lib:format("~p",[Err]))),
        {{OrigType, OrigBucket}, OrigKey} = BKey,
        Value = list_to_binary(mochijson2:encode([
            {"_yz_err_msg_s", ErrStr},
            {"_yz_err_rk_s", OrigKey},
            {"_yz_err_rt_s", OrigType},
            {"_yz_err_rb_s", OrigBucket}
        ])),

        lager:debug("YZ_ERR_PATCH: Attempting to write this obj to Riak, Value: ~p", [Value]),

        Client = yz_kv:client(),
        Bucket = <<OrigType/binary, <<".">>/binary, OrigBucket/binary>>,
        TypedBucket = {?YZ_ERROR_INDEX, Bucket},
        Key = OrigKey,
        ContentType = "application/json",

        ObjectExists = yz_kv:get(Client, TypedBucket, Key),

        case ObjectExists of
            {value, _} -> 
                lager:debug("YZ_ERR_PATCH: yz_err already has this error, please repair the original object and remove the yz_err entry.");
            _ -> 
                yz_kv:put(Client, TypedBucket, Key, Value, ContentType)
        end,

        lager:debug("YZ_ERR_PATCH: Submission to yz_err index complete")
    catch _:E ->
        Trace = erlang:get_stacktrace(),
        ?ERROR("failed to index object ~p with error ~p because ~p",
                                           [BKey, E, Trace])
    end,
    {noreply, S};

handle_cast(Msg, S) ->
    ?WARN("unknown message ~p", [Msg]),
    {noreply, S}.

handle_info(Msg, S) ->
    ?WARN("unknown message ~p", [Msg]),
    {noreply, S}.

handle_call(Req, _, S) ->
    ?WARN("unexpected request ~p", [Req]),
    {noreply, S}.

code_change(_, S, _) ->
    {ok, S}.

terminate(_Reason, _S) ->
    ok.

%%%===================================================================
%%% Private
%%%===================================================================

%% @private
%%
%% @doc Wait for `Check' for the given number of `Seconds'.
wait_for(_, 0) ->
    ok;
wait_for(Check={M,F,A}, Seconds) when Seconds > 0 ->
    case M:F(A) of
        true ->
            ok;
        false ->
            timer:sleep(1000),
            wait_for(Check, Seconds - 1)
    end.

%% @private
%%
%% @doc Create bucket type to hold errors encountered in index/3
maybe_setup_error_bucket_type(undefined) ->
    riak_core_bucket_type:create(?YZ_ERROR_INDEX, [{allow_mult, false},{?YZ_INDEX, ?YZ_ERROR_INDEX}]),
    riak_core_bucket_type:activate(?YZ_ERROR_INDEX);
maybe_setup_error_bucket_type(_) ->
    riak_core_bucket_type:update(?YZ_ERROR_INDEX, [{allow_mult, false},{?YZ_INDEX, ?YZ_ERROR_INDEX}]).

%% @private
%%
%% @doc Create an index to hold errors encountered in index/3
maybe_setup_error_index(true) ->
    ok;
maybe_setup_error_index(false) ->
    yz_index:create(?YZ_ERROR_INDEX, ?YZ_DEFAULT_SCHEMA_NAME),
    wait_for({yz_solr, ping, [?YZ_ERROR_INDEX]}, 10).