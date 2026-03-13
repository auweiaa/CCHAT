-module(server).
-export([start/1,stop/1]).
-export([joinChannel/4, changeNick/3]).

-record(server_st, {
    channels = #{}, % ChannelName -> ChannelPid
    clients = #{},  % ClientPid -> Nick
    nicks = #{} % Nick -> ClientPid
}).

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    genserver:start(ServerAtom, #server_st{}, fun handler/2).


% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    _ = catch genserver:request(ServerAtom, stop_channel_processes),
    _ = catch genserver:stop(ServerAtom),
    ok.


% ---------------------------------------------------------
% request functions for client:

joinChannel(ServerAtom, ChannelName, ClientPid, NickName) ->
    genserver:request(ServerAtom, {join_channel, ChannelName, ClientPid, NickName}).


changeNick(ServerAtom, ClientPid, NewNickName) ->
    genserver:request(ServerAtom, {change_nick, ClientPid, NewNickName}).

% ---------------------------------------------------------
% handler functions:

handler(State0, {join_channel, ChannelName, ClientPid, NickName}) ->    
    State1 = addClientAndNicks(State0, ClientPid, NickName),
    Channels = State1#server_st.channels,
    case maps:find(ChannelName, Channels) of
        {ok, ChannelPid} -> Result = channel:join(ChannelPid, ClientPid, NickName), % Reply = ok or {error, errorAtom, ErrorString} -> replied to Client
                            Reply = {Result, ChannelPid}, % return ChannelPid so Client can save it
                            {reply, Reply, State1};

        error            -> ChannelPid = channel:create(ChannelName),                       
                            Result = channel:join(ChannelPid, ClientPid, NickName),
                            case Result of
                                ok      ->  Reply = {ok, ChannelPid}, % return ChannelPid so Client can save it
                                            NewChannels = maps:put(ChannelName, ChannelPid, Channels),
                                            NewState = State1#server_st{channels = NewChannels},
                                            {reply, Reply, NewState};

                                Error   ->  Reply = {Error, ChannelPid},
                                            {reply, Reply, State1}
                            end
    end;

handler(State = #server_st{nicks = Nicks, clients = Clients, channels = Channels}, {change_nick, ClientPid, NewNickName}) ->
    case maps:find(NewNickName, Nicks) of
        {ok, ClientPid} ->  {reply, ok, State}; % nick alreday taken by same client

        {ok, _OtherPid} ->  {reply,{error, nick_taken, "nick already existing"}, State};

        error           ->  case maps:find(ClientPid, Clients) of
                                {ok, _OldNick}  ->  {NewClients, NewNicks} = updateClientsAndNicks(Clients, Nicks, ClientPid, NewNickName),
                                                    broadcastChangeNicks(Channels, ClientPid, NewNickName),
                                                    {reply, ok, State#server_st{clients = NewClients, nicks = NewNicks}};

                                error           ->  NewClients = maps:put(ClientPid, NewNickName, Clients),
                                                    NewNicks = maps:put(NewNickName, ClientPid, Nicks),
                                                    {reply, ok, State#server_st{clients = NewClients, nicks = NewNicks}}
                            end
    end;


handler(St = #server_st{channels = Channels}, stop_channel_processes) ->
    maps:foreach(fun(_ChannelName, ChannelPid) -> channel:closeChannel(ChannelPid) end, Channels),
    {reply, ok, St}.


% ---------------------------------------------------------
% helper functions:
addClientAndNicks(St = #server_st{clients = Clients, nicks = Nicks}, ClientPid, NickName) -> 
    case maps:find(ClientPid, Clients) of
        {ok, _Nick} ->  St;
        error       ->  NewClients = maps:put(ClientPid, NickName, Clients),
                        NewNicks = maps:put(NickName, ClientPid, Nicks),
                        St#server_st{clients = NewClients, nicks = NewNicks}
    end.

updateClientsAndNicks(Clients, Nicks, ClientPid, NewNickName) ->
    OldNick = maps:get(ClientPid, Clients),
    NewClients = maps:put(ClientPid, NewNickName, Clients), % replace OldNick
    TmpNicks = maps:remove(OldNick, Nicks),
    NewNicks = maps:put(NewNickName, ClientPid, TmpNicks),
    {NewClients, NewNicks}.

broadcastChangeNicks(Channels, ClientPid, NewNickName) ->
    ChannelPids = maps:values(Channels),
    lists:foreach(fun(ChannelPid) ->
        ChannelPid ! {change_nick, ClientPid, NewNickName} end,
    ChannelPids).