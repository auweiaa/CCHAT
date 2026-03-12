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

% Join channel
handle(St = #client_st{server=Server, nick=Nick, channels=Channels}, {join, Channel}) ->        
    case catch server:joinChannel(Server, Channel, self(), Nick) of
        {ok, ChannelPid}                    ->  NewChannels = maps:put(Channel, ChannelPid, Channels),
                                                {reply, ok, St#client_st{channels = NewChannels}};
        
        {{error, ErrorAtom , ErrorMsg}, _}  ->  {reply, {error, ErrorAtom , ErrorMsg}, St};

        {'EXIT', _Reason}                   ->  {reply, {error, server_not_reached , "server not reached"}, St};
        
        timeout_error                       ->  {reply, {error, server_not_reached , "server not reached"}, St}
    end;

% Leave channel
handle(St = #client_st{channels=Channels}, {leave, Channel}) ->         
    case maps:find(Channel, Channels) of
        % elp:ignore W0052 (no_catch)
        {ok, ChannelPid}    ->  case catch channel:leave(ChannelPid, self()) of
                                    ok                              ->  NewChannels = maps:remove(Channel, Channels),
                                                                        {reply, ok, St#client_st{channels = NewChannels}};
                                    
                                    {error, ErrorAtom , ErrorMsg}   ->  {reply, {error, ErrorAtom , ErrorMsg}, St};

                                    {'EXIT', _Reason}               ->  {reply, {error, server_not_reached , "server not reached"}, St};
                                    
                                    timeout_error                   ->  {reply, {error, server_not_reached , "server not reached"}, St}
                                end;

    error                   ->  {reply, {error, user_not_joined, "not in channel"}, St}
    end;

% % old leave channel coordinated through server
% handle(St = #client_st{server = Server, channels=Channels}, {leave, Channel}) ->   
%     case catch server:leaveChannel(Server, Channel, self()) of of
%         ok                              ->  NewChannels = maps:remove(Channel, Channels),
%                                             {reply, ok, St#client_st{channels = NewChannels}};
        
%         {error, ErrorAtom , ErrorMsg}   ->  {reply, {error, ErrorAtom , ErrorMsg}, St};

%         {'EXIT', _Reason}               ->  {reply, {error, server_not_reached , "server not reached"}, St};
        
%         timeout_error                   ->  {reply, {error, server_not_reached , "server not reached"}, St}
%     end;


% Sending message (from GUI, to channel)
handle(St = #client_st{channels=Channels}, {message_send, Channel, Msg}) ->    
    % elp:ignore W0032 (maps_find_rather_than_syntax)
    case maps:find(Channel, Channels) of
        {ok, ChannelPid} -> case catch channel:sendMessage(ChannelPid, self(), Msg) of
                                ok                              ->  {reply, ok, St};
                                
                                {error, ErrorAtom , ErrorMsg}   ->  {reply, {error, ErrorAtom , ErrorMsg}, St};
                                
                                {'EXIT', _Reason}               ->  {reply, {error, server_not_reached , "server not reached"}, St}
                            end;

        error           ->  {reply, {error, user_not_joined, "not in channel"}, St}
    end;



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