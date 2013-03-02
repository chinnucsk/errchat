-module(communication_handler).

-behaviour(cowboy_http_handler).
-behaviour (cowboy_websocket_handler).

%% cowboy_http_handler
-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

%% cowboy_websocket_handle
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

%% cowboy_http_handler

%% New connection  
init({tcp, http}, Req, _Opts) ->  
    lager:debug("Request: ~p", [Req]),
    % "upgrade" every request to websocket,  
    % we're not interested in serving any other content.  
    {upgrade, protocol, cowboy_websocket}.  
  
%% Handles http requests  
handle(Req, State) ->
	lager:debug("Unexpected request: ~p", [Req]), 
	{ok, Req2} = cowboy_http_req:reply(404, [  
        {'Content-Type', <<"text/html">>}  
    ]),  
    {ok, Req2, State}.  
  
%% Terminate connection
terminate(_Reason, _Req, _State) ->  
    errchat_server:unregister(self()),
    ok.  

%% cowboy_http_websocket_handler

% Called for every new websocket connection.  
websocket_init(TransportName, Req, []) ->  
    lager:debug("New client ~p~n ~p~n~n~n", [TransportName, Req]),  

    % register new user in chat server
    errchat_server:register(self()),

    erlang:start_timer(500, self(), <<"{\"event\": \"welcome\", \"data\": {\"text\": \"Welcome!\"}}">>),
    {ok, Req, undefined_state}. 
  
% Called when a text message arrives.  

%% Interface client <-> server

% { 
%   event: "eventName",
%   data:  object
% }

websocket_handle({text, Msg}, Req, State) ->  
    lager:debug("Received: ~p", [Msg]), 

    {JsonList} = jiffy:decode(Msg),

    _Event = {<<"event">>, EventName} = lists:keyfind(<<"event">>, 1, JsonList),
    _Data = {<<"data">>, DataJson} = lists:keyfind(<<"data">>, 1, JsonList),

    case EventName of
        <<"new_message">> ->
            errchat_server:new_message(self(), DataJson);
        <<"me">> ->
            errchat_server:me(self(), DataJson)
    end,

    {ok, Req, State};
  
% With this callback we can handle other kind of  
% messages, like binary.  
websocket_handle(_Any, Req, State) -> 
    {ok, Req, State}.  
  
websocket_info({timeout, _Pid, Msg}, Req, State) ->
    lager:debug("Sending message after timeout: ~p~n~n", [Msg]),  

    {reply, {text, Msg}, Req, State};
websocket_info({new_message, _Pid, Msg}, Req, State) ->

    lager:debug("Sending message to client"),

    {reply, {text, Msg, Req, State};

% Other messages from the system are handled here.  
websocket_info(_Info, Req, State) ->  

    lager:debug("Kom ikke..!"),

    {ok, Req, State}.  
  
websocket_terminate(_Reason, _Req, _State) ->  
    ok. 