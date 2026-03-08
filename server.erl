-module(server).
-export([start/1,stop/1]).
-export([joinChannel/3, leaveChannel/3]).

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    genserver:start(ServerAtom, [], fun handler/2).


% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    genserver:stop(ServerAtom),
    ok.


% ---------------------------------------------------------
% methods for client:

joinChannel(ServerAtom, ChannelName, UserName) ->
    genserver:request(ServerAtom, {join_channel, ChannelName, UserName}).

leaveChannel(ServerAtom, ChannelName, UserName) ->
    genserver:request(ServerAtom, {leave_channel, ChannelName, UserName}).


% ToDo:
% changed Nickname in channels


% ---------------------------------------------------------
% handler methods:

handler(State, {join_channel, ChannelName, UserName}) ->
    case findChannel(State, ChannelName) of
        {ChannelName, UserList} ->  case isUserInChannel(UserList, UserName) of
                                        true  -> {Result, NewState} = {user_already_joined, State};
                                        false -> {Result, NewState} = addUserToChannel(State, {ChannelName, UserList}, UserName)
                                    end;

        empty                   ->  NewState = [ {ChannelName, [UserName]} | State],
                                    Result = ok
    end,
    {reply, Result, NewState};

handler(State, {leave_channel, ChannelName, UserName}) ->
    case findChannel(State, ChannelName) of
        {ChannelName, UserList} ->  case isUserInChannel(UserList, UserName) of
                                        true  -> {Result, NewState} = removeUserFromChannel(State, {ChannelName, UserList}, UserName);
                                        false -> {Result, NewState} = {user_not_joined, State}
                                    end;

        empty                   ->  {Result, NewState} = {user_not_joined, State}
    end,
    {reply, Result, NewState}.


% ---------------------------------------------------------
% Helper functions:

findChannel([], _)                                          -> empty;
findChannel([ {ChannelName, UserList} | _ ], ChannelName)   -> {ChannelName, UserList};
findChannel([ _ | T], ChannelName)                          -> findChannel(T, ChannelName).


isUserInChannel([], _)                      -> false;
isUserInChannel([UserName | _ ], UserName)  -> true;
isUserInChannel([ _ | T], UserName)         -> isUserInChannel(T, UserName).


addUserToChannel(State, {ChannelName, UserList}, UserName)  ->
    ChannelList = State -- [{ChannelName, UserList}],
    NewList = [UserName|UserList],
    NewState = [ {ChannelName, NewList} | ChannelList],
    {ok, NewState}.


removeUserFromChannel(State, {ChannelName, UserList}, UserName) ->
    ChannelList = State -- [{ChannelName, UserList}],
    NewList = UserList -- [UserName],
    NewState = [ {ChannelName, NewList} | ChannelList],
    {ok, NewState}. 