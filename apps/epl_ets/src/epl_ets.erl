%%%-------------------------------------------------------------------
%% @doc epl_ets module.
%% It is a gen_server listening to messages from epl main application.
%% @end
%%%-------------------------------------------------------------------

-module(epl_ets).

-behaviour(gen_server).

%% API
-export([start_link/0,
         subscribe/0,
         subscribe/1,
         unsubscribe/0,
         unsubscribe/1]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

%% gen_server state
-record(state, {subscribers = []}).

%%====================================================================
%% API functions
%%====================================================================

%% @doc Stars epl_ets.
-spec start_link() -> {ok, Pid :: pid()} |
                      ignore |
                      {reason, Reason :: term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Add calling process to epl_ets subscribers.
-spec subscribe() -> ok.
subscribe() ->
    subscribe(self()).

%% @doc Add provided `Pid` to epl_ets subscribers.
-spec subscribe(Pid :: pid()) -> ok.
subscribe(Pid) ->
    gen_server:cast(?MODULE, {subscribe, Pid}).

%% @doc Remove calling process from epl_ets subscribers.
-spec unsubscribe() -> ok.
unsubscribe() ->
    unsubscribe(self()).

%% @doc Remove provided `Pid` from epl_ets subscribers.
-spec unsubscribe(Pid :: pid()) -> ok.
unsubscribe(Pid) ->
    gen_server:cast(?MODULE, {unsubscribe, Pid}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    epl:subscribe(),
    {ok, #state{}}.

handle_call(Request, _From, _State) ->
    exit({not_implemented, Request}).

handle_cast({subscribe, Pid}, State = #state{subscribers = Subs}) ->
    NewSubs = [Pid | Subs],
    NewState = State#state{subscribers = NewSubs},
    {noreply, NewState};
handle_cast({unsubscribe, Pid}, State = #state{subscribers = Subs}) ->
    NewSubs = lists:delete(Pid, Subs),
    NewState = State#state{subscribers = NewSubs},
    {noreply, NewState}.

handle_info({data, _Key, _Proplist}, State = #state{subscribers = Subs}) ->
    ETSCount = get_all_ets_count(),
    ETSMemUsage = get_ets_mem_usage(),
    JSON = epl_json:encode(#{ets_count => ETSCount,
                             mem_usage => lists:nth(1, ETSMemUsage),
                             ets_mem_usage => lists:nth(2, ETSMemUsage)},
                           <<"ets-node-info">>),
    [Pid ! {data, JSON} || Pid <- Subs],
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internals
%%====================================================================

get_all_ets_count() ->
    {ok, AllETS} = epl_tracer:command(fun ets:all/0, []),
    erlang:length(AllETS).

get_ets_mem_usage() ->
    {ok, MemoryData} = epl_tracer:command(fun erlang:memory/0, []),
    [proplists:get_value(Key, MemoryData) || Key <- [total, ets]].