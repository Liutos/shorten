:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).

:- http_handler('/api/shorten', shorten_url, [methods([post])]).

server(Port) :-
        http_server(http_dispatch, [port(Port)]).

shorten_url(Request) :-
        http_parameters(Request, [
          url(Url, [string])
        ]),
        format('Content-type: text/plain~n~n'),
        format('url is ~s', [Url]).
