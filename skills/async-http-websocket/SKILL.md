---
name: async-http-websocket
description: Build HTTP and websocket servers/clients with cohttp-async and async_websocket in the Jane Street Async stack, including same-port websocket upgrades. Use when a project depends on cohttp-async or async_websocket, or needs a websocket feed next to a JSON API in OCaml.
---

# cohttp-async + async_websocket (verified on the ox switch)

## HTTP server with websocket upgrade on the same port

```ocaml
Cohttp_async.Server.create_expert
  ~on_handler_error:(`Call (fun _ exn -> ...))
  (Tcp.Where_to_listen.of_port port)
  (fun ~body addr req ->
    if is_upgrade req then
      let headers = Http.Header.of_list
        [ "upgrade", "websocket"; "connection", "Upgrade"
        ; "sec-websocket-accept",
          Websocket.sec_websocket_accept_header_value ~sec_websocket_key ] in
      (* Http.Response.make, not Cohttp.Response.make: the latter adds
         transfer-encoding: chunked, invalid on a 101 *)
      return (`Expert (Http.Response.make ~status:`Switching_protocols ~headers (),
        fun reader writer ->
          let ws = Websocket.create ~opcode:`Text ~role:Server reader writer in
          let from_client, to_client = Websocket.pipes ws in
          ...))
    else ... `Response (Cohttp_async.Server.respond_string ~status ~headers body))
```

- Needs `http` and `cohttp-async` and `async_websocket` in `(libraries)`.
- `Cohttp_async.Server.listening_on` returns the bound port (use port 0 in tests).
- The `Reader.t` handed over in `Expert` still holds already-buffered bytes.
- `async_websocket` only frames; it has no client handshake. For a client,
  write the HTTP upgrade request by hand over `Tcp.connect`, then
  `Websocket.create ~role:Client`.

## Client

```ocaml
let%bind resp, body = Cohttp_async.Client.post ~headers ~body:(Body.of_string s) uri in
let code = Cohttp.Code.code_of_status (Cohttp.Response.status resp) in
let%bind s = Cohttp_async.Body.to_string body in ...
```

## Logging and tests

- `Log.Global` writes to stdout by default and pollutes expect tests. In tests
  `Log.Global.set_output []`; in binaries `Log.Global.set_output [Log.Output.stderr ()]`.
- `let%expect_test` works with `open Async` returning a `unit Deferred.t`.
- Decode errors from ppx_yojson_conv arrive as
  `Ppx_yojson_conv_lib.Yojson_conv.Of_yojson_error (Failure msg, _)` or
  `Yojson.Json_error`; catch both for 400 responses (needs `ppx_yojson_conv_lib`).
- An executable module named like the library (`hl_sim.ml` vs library
  `hl_sim`) clashes with the wrapper module; name it `main.ml` and set
  `(public_name hl-sim)`.
