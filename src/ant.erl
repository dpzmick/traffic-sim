-module(ant).
-export([start/2, wakeup_and_move/1, tell_neighbors/2, you_moved/2, ant_id/1]).

%% pick one of these randomly and try to move to it
priv_pick_neighbor(Neighbors) ->
    Cells = lists:map(fun({_,Cell}) -> Cell end, dict:to_list(Neighbors)),
    Index = random:uniform(length(Cells)),
    lists:nth(Index, Cells).

priv_got_neighbors(Neighbors) ->
    Choice = priv_pick_neighbor(Neighbors),
    cell:move_ant_to(Choice, self()).

priv_statify(Id, CurrentCell, Reporter) -> {Id, CurrentCell, Reporter}.

outer_loop(State = {Id,_,_}) ->
    receive
        stop -> io:format("Ant ~p stopping", [Id]), ok
    after
        0 -> loop(State)
    end.

loop(State = {Id, undefined, Reporter}) ->
    receive
        wakeup_and_move -> loop(State);

        {move_to, Cell} ->
            reporter:report_move(Reporter, os:timestamp(), cell:cell_id(Cell)),
            outer_loop(priv_statify(Id, Cell, Reporter));

        {tell_id, To} -> To ! {told_id, Id}, loop(State)
    end;

loop(State = {Id, CurrentCell, Reporter}) ->
    receive
        wakeup_and_move -> cell:tell_neighbors(CurrentCell, self()), loop(State);

        {neighbors, Neighbors} ->
            priv_got_neighbors(Neighbors),
            outer_loop(State);

        {move_to, Cell} ->
            reporter:report_move(Reporter, os:timestamp(), cell:cell_id(Cell)),
            cell:ant_leaving(CurrentCell, self()),
            outer_loop(priv_statify(Id, Cell, Reporter));

        {tell_id, To} -> To ! {told_id, Id}, outer_loop(State)
    end.

%% public api
start(Id, Reporter) ->
    spawn(fun () -> outer_loop({Id, undefined, Reporter}) end).

wakeup_and_move(Ant) ->
    Ant ! wakeup_and_move.

tell_neighbors(Ant, Neighbors) ->
    Ant ! {neighbors, Neighbors}.

you_moved(Ant, ToCell) ->
    Ant ! {move_to, ToCell}.

ant_id(Ant) ->
    Ant ! {tell_id, self()},
    receive
        {told_id, Id} -> Id
    end.
