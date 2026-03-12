-module(server).
-export([start/1,stop/1]).
-export([joinChannel/4]).
% -export([joinChannel/4, leaveChannel/3]).

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    genserver:start(ServerAtom, #{}, fun handler/2). % State as Map: #{}


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

% leaveChannel(ServerAtom, ChannelName, ClientPid) ->
%     genserver:request(ServerAtom, {leave_channel, ChannelName, ClientPid}).


% ---------------------------------------------------------
% handler functions:

handler(State, {join_channel, ChannelName, ClientPid, NickName}) ->
    case maps:find(ChannelName, State) of
        {ok, ChannelPid} -> Result = channel:join(ChannelPid, ClientPid, NickName), % Reply = ok or {error, errorAtom, ErrorString} -> replied to Client
                            Reply = {Result, ChannelPid}, % return ChannelPid so Client can save
                            {reply, Reply, State};

        error            -> ChannelPid = channel:create(ChannelName),                        
                            NewState = maps:put(ChannelName, ChannelPid, State),
                            Result = channel:join(ChannelPid, ClientPid, NickName),
                            Reply = {Result, ChannelPid}, % return ChannelPid so Client can save
                            {reply, Reply, NewState}
    end;

% handler(State, {leave_channel, ChannelName, ClientPid}) ->
%     case maps:find(ChannelName, State) of
%         {ok, ChannelPid} -> Reply = channel:leave(ChannelPid, ClientPid), % Reply = ok or {error, errorAtom, ErrorString} -> replied to Client
%                             {reply, Reply, State};

%         error            -> Reply = {error, user_not_joined, "channel not found"},
%                             {reply, Reply, State}
%     end;

handler(State, stop_channel_processes) ->
    maps:foreach(fun(_ChannelName, ChannelPid) -> channel:closeChannel(ChannelPid) end, State),
    {reply, ok, State}.


