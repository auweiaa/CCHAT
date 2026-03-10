-module(server).
-export([start/1,stop/1]).
-export([joinChannel/4, leaveChannel/3]).

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    genserver:start(ServerAtom, #{}, fun handler/2). % State as Map: #{}


% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    genserver:stop(ServerAtom),
    ok.


% ---------------------------------------------------------
% functions for client:

joinChannel(ServerAtom, ChannelName, ClientPid, NickName) ->
    genserver:request(ServerAtom, {join_channel, ChannelName, ClientPid, NickName}).

leaveChannel(ServerAtom, ChannelName, ClientPid) ->
    genserver:request(ServerAtom, {leave_channel, ChannelName, ClientPid}).


% ---------------------------------------------------------
% handler functions:

handler(State, {join_channel, ChannelName, ClientPid, NickName}) ->
    case maps:find(ChannelName, State) of
        {ok, ChannelPid} -> Reply = channel:join(ChannelPid, ClientPid, NickName), % Reply = {ok, ChannelPid}
                            {reply, Reply, State};

        error            -> ChannelPid = channel:create(ChannelName),                        
                            NewState = maps:put(ChannelName, ChannelPid, State), % alternative: NewState = State#{ChannelName => ChannelPid}  
                            Reply = channel:join(ChannelPid, ClientPid, NickName), % Reply = {ok, ChannelPid}
                            {reply, Reply, NewState}

    end;

handler(State, {leave_channel, ChannelName, ClientPid}) ->
    case maps:find(ChannelName, State) of
        {ok, ChannelPid} -> Reply = channel:leave(ChannelPid, ClientPid),
                            {reply, Reply, State};

        error            -> Reply = {error, user_not_joined, "user not in channel"},
                            {reply, Reply, State}

    end.
