-module(server).
-export([start/1,stop/1]).

% Start a new server process with the given name
% Do not change the signature of this function.
start(ServerAtom) ->
    % TODO Implement function
    % - Spawn a new process which waits for a message, handles it, then loops infinitely
    % - Register this process to ServerAtom
    % - Return the process ID
    
    case whereis(ServerAtom) of
        undefined ->
                    ServerPid = spawn(fun() -> msgLoop() end),
                    true = register(ServerAtom, ServerPid),
                    ServerPid;

        _Pid -> {error, already_exists}
    end.


% Stop the server process registered to the given name,
% together with any other associated processes
stop(ServerAtom) ->
    % TODO Implement function
    % Return ok
    not_implemented.

%ToDo: implement handling of incoming messages:
msgLoop() ->
    receive
        _ -> io:format("New Message~n")
    end, msgLoop().
