-module(client).
-export([handle/2, initial_state/3]).

% This record defines the structure of the state of a client.
% Add whatever other fields you need.
-record(client_st, {
    gui, % atom of the GUI process
    nick, % nick/username of the client
    server, % atom of the chat server
    channels = #{}
}).

% Return an initial state record. This is called from GUI.
% Do not change the signature of this function.
initial_state(Nick, GUIAtom, ServerAtom) ->
    #client_st{
        gui = GUIAtom,
        nick = Nick,
        server = ServerAtom
    }.

% handle/2 handles each kind of request from GUI
% Parameters:
%   - the current state of the client (St)
%   - request data from GUI
% Must return a tuple {reply, Data, NewState}, where:
%   - Data is what is sent to GUI, either the atom `ok` or a tuple {error, Atom, "Error message"}
%   - NewState is the updated state of the client




%client → server
%server → returns ChannelPid


% Join channel 
% {reply, ok, St} ;

%handle(St, {join, Channel}) ->
handle(St = #client_st{server=Server, nick=Nick, channels=Channels}, {join, Channel}) ->
    case maps:is_key(Channel, Channels) of
        true ->
            {reply, {error, user_already_joined, "already joined"}, St};

        false ->
           
            try server:joinChannel(Server, Channel, self(), Nick) of
                {ok, ChannelPid} ->
                    NewChannels = maps:put(Channel, ChannelPid, Channels), %Key, Value, Map1) -> Map2
                    {reply, ok, St#client_st{channels = NewChannels}}
            catch
                _:_ -> %any error type : any reason
                    {reply, {error, server_not_reached, "server unreachable"}, St}
            end
    end;


%client → channel

% Leave channel
handle(St = #client_st{channels=Channels}, {leave, Channel}) ->
    % {reply, ok, St} ;

    case maps:find(Channel,Channels) of

            error ->
                {reply, {error, user_not_joined, "not joined"}, St};

            {ok, ChannelPid} -> % no try and catch as sending a message can never fail
                % ChannelPid ! {leave, self()},
                channel:leave(ChannelPid, self()),
                    NewChannels = maps:remove(Channel, Channels),
                    {reply, ok, St#client_st{channels = NewChannels}}


    end;





handle(St = #client_st{server=Server, channels=Channels, nick=Nick},
       {message_send, Channel, Msg}) ->

    case maps:find(Channel, Channels) of

        % Client already joined channel
        {ok, ChannelPid} ->
            ChannelPid ! {message, self(), Nick, Msg},
            {reply, ok, St};

        % Client not in channel
        error ->
            case whereis(Server) of

                % Server never reached
                undefined ->
                    {reply, {error, server_not_reached, "server unreachable"}, St};

                % Server exists but user not in channel
                _ ->
                    {reply, {error, user_not_joined, "user not joined"}, St}

            end
    end;


% write_not_joined3

% Error:

% Expected: {error,server_not_reached,_}
% Got: {error,user_not_joined,"user not joined"}

% Scenario of the test:

% Client created
% Client sends message to channel
% Channel has NEVER been joined

% Important detail:

% The client has never contacted the server yet, so the server might not exist.

% Correct behavior:

% Client tries to contact server

% Server is unreachable

% Return
% {error, server_not_reached, ...}


% messages_no_server2

% Error:

% Expected: {error,server_not_reached,_}
% Got: ok

% Scenario:

% Client joins channel
% Server stops intentionally
% Client sends message

% Expected behaviour:

% Client tries to send message to server.

% Server does not reply.

% Client should timeout and return:

% {error,server_not_reached,...}



% handle(St = #client_st{server=Server, channels=Channels, nick=Nick},
%        {message_send, Channel, Msg}) ->

%     case maps:find(Channel, Channels) of

%         {ok, ChannelPid} ->
%             case whereis(Server) of
%                 undefined ->
%                     {reply, {error, server_not_reached, "server unreachableee"}, St};
%                 _ ->
%                     ChannelPid ! {message, self(), Nick, Msg},
%                     {reply, ok, St}
%             end;

%         error ->
%             case maps:size(Channels) of

%                 0 ->
%                     case whereis(Server) of
%                         undefined ->
%                             {reply, {error, server_not_reached, "server unreachable"}, St};
%                         _ ->
%                             {reply, {error, user_not_joined, "user not joined"}, St}
%                     end;

%                 _ ->
%                     {reply, {error, user_not_joined, "user not joined"}, St}

%             end
%     end;






% This case is only relevant for the distinction assignment!
% Change nick (no check, local only)
handle(St, {nick, NewNick}) ->
    {reply, ok, St#client_st{nick = NewNick}} ;

% ---------------------------------------------------------------------------
% The cases below do not need to be changed...
% But you should understand how they work!

% Get current nick
handle(St, whoami) ->
    {reply, St#client_st.nick, St} ;

% Incoming message (from channel, to GUI)
handle(St = #client_st{gui = GUI}, {message_receive, Channel, Nick, Msg}) ->
    gen_server:call(GUI, {message_receive, Channel, Nick++"> "++Msg}),
    {reply, ok, St} ;

% Quit client via GUI
handle(St, quit) ->
    % Any cleanup should happen here, but this is optional
    {reply, ok, St} ;

% Catch-all for any unhandled requests
handle(St, Data) ->
    {reply, {error, not_implemented, "Client does not handle this command"}, St} .