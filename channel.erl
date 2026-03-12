-module(channel).
-export([create/1, join/3, leave/2, sendMessage/3, closeChannel/1]).

% ---------------------------------------------------------
% start and stop for server:

create(ChannelName) -> 
    spawn(fun() -> loop(ChannelName, #{}) end).


closeChannel(ChannelPid) ->
    ChannelPid ! stop,
    ok.

% ---------------------------------------------------------
% loop
loop(ChannelName, State) ->
    receive
        {join, From, Ref, ClientPid, NickName}          ->  {NewState, Result} = handle_join(State, ClientPid, NickName),
                                                            From ! {reply, Ref, Result},
                                                            loop(ChannelName, NewState);
                                        
        {leave, From, Ref, ClientPid}                   ->  {NewState, Result} = handle_leave(State, ClientPid),
                                                            From ! {reply, Ref, Result},
                                                            loop(ChannelName, NewState);

        {msg, From, Ref, ClientPid, Msg}                -> {NewState, Result} = handle_message(State, ChannelName, ClientPid, Msg),
                                                            From ! {reply, Ref, Result},
                                                            loop(ChannelName, NewState);
        
        {change_nick, ClientPid, NickName}              ->  {NewState, _Result} = handle_changeNick(State, ClientPid, NickName),
                                                            loop(ChannelName, NewState);
                                                
        stop                                            ->  ok;

        {result, _Ref, _Result}                         ->  loop(ChannelName, State); % ignore reply-messages after broadcasting

        _Other                                          ->  loop(ChannelName, State) % unknown messages
    end.


% ---------------------------------------------------------
% request functions for client:

join(ChannelPid, ClientPid, NickName) ->
    Ref = make_ref(),
    ChannelPid ! {join, self(), Ref, ClientPid, NickName},
    receive
        {reply, Ref, Result} -> Result
    after 3000 ->
        {error, server_not_reached, "server not reached"}
    end.

leave(ChannelPid, ClientPid) ->
    Ref = make_ref(),
    ChannelPid ! {leave, self(), Ref, ClientPid},
    receive
        {reply, Ref, Result} -> Result
    after 3000 ->
        {error, server_not_reached, "server not reached"}
    end.

sendMessage(ChannelPid, ClientPid, Msg) -> 
    Ref = make_ref(),
    ChannelPid ! {msg, self(), Ref, ClientPid, Msg},
    receive
        {reply, Ref, Result} -> Result
    after 3000 ->
        {error, server_not_reached, "server not reached"}
    end.


% ---------------------------------------------------------
% handle functions:

handle_join(State, ClientPid, NickName) -> 
    case maps:is_key(ClientPid, State) of
        true    ->  Result = {error, user_already_joined, "already joined"},
                    {State, Result};
                  
        false   ->  NewState = maps:put(ClientPid, NickName, State), % alternative: State#{ClientPid => NickName};
                    {NewState, ok}  
    end.


handle_leave(State, ClientPid) ->
    case maps:is_key(ClientPid, State) of
        true    ->  NewState = maps:remove(ClientPid, State), % removes if exists -> error handling in server
                    {NewState, ok};

        false   ->  Result = {error, user_not_joined, "not in channel"},
                    {State, Result}
    end.


handle_message(State, ChannelName, ClientPid, Msg) -> 
    case maps:is_key(ClientPid, State) of
        true    ->  broadcastMessage(State, ChannelName, ClientPid, Msg),
                    {State, ok};

        false   ->  Result = {error, user_not_joined, "not in channel"},
                    {State, Result}
    end.

broadcastMessage(State, ChannelName, ClientPid, Msg) ->
    SenderName = maps:get(ClientPid, State),
    Receivers = maps:remove(ClientPid, State), % remove the sending Client
    maps:foreach(fun(ReceiverPid, _Name) ->
        Ref = make_ref(),
        ReceiverPid ! {request, self(), Ref, {message_receive, ChannelName, SenderName, Msg}}
    end, Receivers).



handle_changeNick(State, ClientPid, NickName) -> 
    case maps:is_key(ClientPid, State) of
        true    ->  NewState = maps:put(ClientPid, NickName, State),
                    {NewState, ok};
        false   ->  {State, ok} % ignore the broadcast
    end.