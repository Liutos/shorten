#!/usr/bin/env swipl

:- use_module(library(http/http_server)).
:- use_module(library(http/json)).
:- use_module(library(odbc)).
:- use_module(library(redis)).

:- initialization(main, main).

% 声明为动态的以便允许使用 asserta 修改。
:- dynamic odbc_driver_string/1.

% 定义非接口 hanndler 的谓词。
% 将 16 进制的字符转换为十进制整数。
hex_to_int(['0'], 0).
hex_to_int(['1'], 1).
hex_to_int(['2'], 2).
hex_to_int(['3'], 3).
hex_to_int(['4'], 4).
hex_to_int(['5'], 5).
hex_to_int(['6'], 6).
hex_to_int(['7'], 7).
hex_to_int(['8'], 8).
hex_to_int(['9'], 9).
hex_to_int(['a'], 10).
hex_to_int(['b'], 11).
hex_to_int(['c'], 12).
hex_to_int(['d'], 13).
hex_to_int(['e'], 14).
hex_to_int(['f'], 15).
hex_to_int(String, Integer) :-
    append(Prefix, [Char], String),
    hex_to_int(Prefix, N),
    hex_to_int([Char], M),
    Integer is 16 * N + M.

% 将 JSON 对象格式的 MySQL ODBC 连接参数转换为 atom。
key_values_to_driver_string([], [], '').
key_values_to_driver_string([Key], [Value], Result) :-
    atom_concat(Key, '=', Prefix),
    atom_concat(Prefix, Value, Result).
key_values_to_driver_string([Key|Keys], [Value|Values], Result) :-
    key_values_to_driver_string([Key], [Value], Head),
    key_values_to_driver_string(Keys, Values, Tail),
    atom_concat(Head, ';', Prefix),
    atom_concat(Prefix, Tail, Result).

mysql_config_to_driver_string(MysqlConfig, DriverString) :-
    dict_pairs(MysqlConfig, _, Pairs),
    pairs_keys_values(Pairs, Keys, Values),
    key_values_to_driver_string(Keys, Values, DriverString).

% 定义接口的处理函数。
home_page(_Request) :-
    reply_html_page(
        title('Demo server'),
        [ h1('Hello world!')
        ]).

lengthen_url(_Request) :-
    http_parameters(_Request, [
        id(HexId, [string])
    ]),
    % 如果缓存中存在就不需要查询数据库了。
    (   redis(default, get(HexId), Location)
    ->  % 输出 302 的 HTTP 响应。
        % 这里的返回状态码的写法参考自[这里](https://www.swi-prolog.org/pldoc/man?section=html-body)。
        format('Status: 302~n'),
        format('Location: ~s~n', [Location]),
        format('Content-type: text/plain~n~n')
    ;   % 将十六进制还原为数据库主键。
        string_chars(HexId, Chars),
        hex_to_int(Chars, Id),
        % 读写数据库，找出原始 URL。
        odbc_driver_string(DriverString),
        odbc_driver_connect(DriverString, Connection, []),
        % 构造 SQL。
        format(atom(Sql), 'SELECT `url` FROM `localhost`.`t_url` WHERE `id` = ~d', Id),
        findall(Url, odbc_query(Connection, Sql, row(Url)), Rows),
        odbc_disconnect(Connection),
        (   length(Rows, 1)
        ->  nth0(0, Rows, Url),
            % 输出 302 的 HTTP 响应。
            % 这里的返回状态码的写法参考自[这里](https://www.swi-prolog.org/pldoc/man?section=html-body)。
            format('Status: 302~n'),
            format('Location: ~s~n', [Url]),
            format('Content-type: text/plain~n~n')
        ;   % 输出 404 的响应。
            format('Status: 404~n'),
            format('Content-type: text/plain~n~n')
        )
    ).
    

shorten_url(_Request) :-
    http_parameters(_Request, [
        url(Url, [string])
    ]),
    % 读写数据库。
    odbc_driver_string(DriverString),
    odbc_driver_connect(DriverString, Connection, []),
    % 插入 URL 前需要检查该链接是否已经存在。
    %% 构造 SQL。
    format(atom(Sql), 'SELECT `id` FROM `localhost`.`t_url` WHERE `url` = "~s"', Url),
    findall(Id, odbc_query(Connection, Sql, row(Id)), Rows),
    (   length(Rows, 1)
    ->  nth0(0, Rows, LastInsertId),
        odbc_disconnect(Connection)
    ;   odbc_prepare(Connection, 'INSERT INTO `localhost`.`t_url` SET `url` = ?', [default], Statement),
        odbc_execute(Statement, [Url]),
        %% 获取刚才写入的行的主键。
        odbc_query(Connection, 'SELECT LAST_INSERT_ID()', row(LastInsertId)),
        odbc_disconnect(Connection)
    ),
    % 将数字转换为十六进制。
    format(atom(HexLastInsertId), "~16r", LastInsertId),
    % 将短链接和实际链接之间的关系记录到 Redis 中。
    redis(default, set(HexLastInsertId, Url)),
    % 最后才输出 HTTP 响应内容。
    format('Content-type: application/json~n~n'),
    format('{"code": 200, "data": {"short_url": "http://localhost:8080/api/lengthen?id=~s"}}', [HexLastInsertId]).

% 程序入口。
main(_) :- 
    % 解析配置文件。
    %% 读取文件内容。
    open("./config.json", read, Stream),
    json_read_dict(Stream, TopConfig),
    close(Stream),
    %% 解析出 MySQL 和 Redis 的连接配置并保存起来。
    MysqlConfig = TopConfig.mysql,
    mysql_config_to_driver_string(MysqlConfig, DriverString),
    asserta(odbc_driver_string(DriverString)),
    % 连接 Redis。
    RedisConfig = TopConfig.redis,
    write(RedisConfig),
    atom_string(RedisHostname, RedisConfig.hostname),
    number_string(RedisPort, RedisConfig.port),
    redis_server(default, RedisHostname:RedisPort, []),
    % 注册路由。
    http_handler(root(.),
                 http_redirect(moved, location_by_id(home_page)),
                 []),
    http_handler(root(home), home_page, []),
    http_handler('/api/lengthen', lengthen_url, [
        methods([get])
    ]),
    http_handler('/api/shorten', shorten_url, [
        methods([post])
    ]),
    % 监听端口，启动服务器。
    http_server([port(8080)]),
    sleep(10000),
    writeln("睡眠结束").
