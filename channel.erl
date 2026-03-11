% -module(channel).
% -export([create/1,join/3,leave/2]).


% create(ChannelName) -> 
%     spawn(fun() -> loop(ChannelName, #{}) end).

% % loop(ChannelName, State) ->
% %     receive
% %         {join, From, Ref, ClientPid, NickName}  ->  {NewState, Result} = handle_join(State, ClientPid, NickName),
% %                                                     From ! {reply, Ref, Result},
% %                                                     loop(ChannelName, NewState);
                                        
% %         {leave, From, Ref, ClientPid}           ->  {NewState, Result} = handle_leave(State, ClientPid),
% %                                                     From ! {reply, Ref, Result},
% %                                                     loop(ChannelName, NewState);            
        
% %         _Other                                   ->  loop(ChannelName, State)
% %     end.


% loop(ChannelName, State) ->
%     receive

%         {join, From, Ref, ClientPid, NickName} ->
%             {NewState, Result} = handle_join(State, ClientPid, NickName),
%             From ! {reply, Ref, Result},
%             loop(ChannelName, NewState);

%         {leave, From, Ref, ClientPid} ->
%             {NewState, Result} = handle_leave(State, ClientPid),
%             From ! {reply, Ref, Result},
%             loop(ChannelName, NewState);

%         {message, FromPid, Nick, Msg} ->
%             maps:foreach(
%                 fun(Pid, _) ->
%                     if
%                         Pid =/= FromPid ->
%                             Ref = make_ref(),
%                             Pid ! {request, self(), Ref,
%                                    {message_receive, ChannelName, Nick, Msg}};
%                         true ->
%                             ok
%                     end
%                 end,
%                 State),
%             loop(ChannelName, State);

%         _Other ->
%             loop(ChannelName, State)
%     end.

% % ---------------------------------------------------------
% % functions for client:

% join(ChannelPid, ClientPid, NickName) ->
%     Ref = make_ref(),
%     ChannelPid ! {join, self(), Ref, ClientPid, NickName},
%     receive
%         {reply, Ref, Result} -> Result
%     end.

% leave(ChannelPid, ClientPid) ->
%     Ref = make_ref(),
%     ChannelPid ! {leave, self(), Ref, ClientPid},
%     receive
%         {reply, Ref, Result} -> Result
%     end.

% % ---------------------------------------------------------
% % helper functions:

% handle_join(State, ClientPid, NickName) -> 
%     case maps:is_key(ClientPid, State) of
%         true    ->  Result = {error, user_already_joined, "already joined"},
%                     {State, Result};
                  
%         false   ->  NewState = maps:put(ClientPid, NickName, State), % alternative: State#{ClientPid => NickName};
%                     {NewState, ok}  
%     end.

% handle_leave(State, ClientPid) ->
%     case maps:is_key(ClientPid, State) of
%         true    ->  NewState = maps:remove(ClientPid, State), % removes if exists -> error handling in server
%                     {NewState, ok};

%         false   ->  Result = {error, user_not_joined, "not in channel"},
%                     {State, Result}
%     end.

% handle_message() -> 
%     % ToDo:
%     ok.
    











-module(channel).

-export([create/1, join/3, leave/2]).

%% ---------------------------------------------------------
%% Create channel process
%% ---------------------------------------------------------

create(ChannelName) ->
    spawn(fun() -> loop(ChannelName, #{}) end).


%% ---------------------------------------------------------
%% Channel process loop
%% State = #{ClientPid => Nick}
%% ---------------------------------------------------------

loop(ChannelName, State) ->
    receive

        %% Client joins channel
        {join, From, Ref, ClientPid, NickName} ->
            {NewState, Result} = handle_join(State, ClientPid, NickName),
            From ! {reply, Ref, Result},
            loop(ChannelName, NewState);


        %% Client leaves channel
        {leave, From, Ref, ClientPid} ->
            {NewState, Result} = handle_leave(State, ClientPid),
            From ! {reply, Ref, Result},
            loop(ChannelName, NewState);


        %% Message sent in channel
        {message, FromPid, Nick, Msg} ->
            handle_message(ChannelName, State, FromPid, Nick, Msg),
            loop(ChannelName, State);


        %% Ignore unknown messages
        _Other ->
            loop(ChannelName, State)
    end.


%% ---------------------------------------------------------
%% Client API
%% ---------------------------------------------------------

join(ChannelPid, ClientPid, NickName) ->
    Ref = make_ref(),
    ChannelPid ! {join, self(), Ref, ClientPid, NickName},
    receive
        {reply, Ref, Result} -> Result
    end.


leave(ChannelPid, ClientPid) ->
    Ref = make_ref(),
    ChannelPid ! {leave, self(), Ref, ClientPid},
    receive
        {reply, Ref, Result} -> Result
    end.


%% ---------------------------------------------------------
%% Helper functions
%% ---------------------------------------------------------

handle_join(State, ClientPid, NickName) ->
    case maps:is_key(ClientPid, State) of
        true ->
            {State, {error, user_already_joined, "already joined"}};

        false ->
            NewState = maps:put(ClientPid, NickName, State),
            {NewState, ok}
    end.


handle_leave(State, ClientPid) ->
    case maps:is_key(ClientPid, State) of
        true ->
            NewState = maps:remove(ClientPid, State),
            {NewState, ok};

        false ->
            {State, {error, user_not_joined, "not in channel"}}
    end.


handle_message(ChannelName, State, FromPid, Nick, Msg) ->
    maps:foreach(
        fun(Pid, _) ->
            if
                Pid =/= FromPid ->
                    Ref = make_ref(),
                    Pid ! {request, self(), Ref,
                           {message_receive, ChannelName, Nick, Msg}};
                true ->
                    ok
            end
        end,
        State).
















