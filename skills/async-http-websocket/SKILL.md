---
name: async-http-websocket
description: Build HTTP and websocket servers/clients with cohttp-async and async_websocket in the Jane Street Async stack, including same-port websocket upgrades. Use when a project depends on cohttp-async or async_websocket, or needs a websocket feed next to a JSON API in OCaml.
---

# cohttp-async + async_websocket (verified on the ox switch)

## Outcomes

1. Serve a JSON API and a websocket feed on one port, testable on port 0.
2. Write a websocket client: handshake over `Tcp.connect`, frames via
   `Websocket.create ~role:Client`, ping watchdog, reconnect with backoff.
3. Test both ends in-process with expect tests that stay deterministic
   (no logging to stdout, no wall-clock timing in the output).

## Reference modules (org repos)

| File | Shows |
|------|-------|
| `hl-sim/lib/server.ml` | `create_expert` with same-port websocket upgrade and JSON routes |
| `hl-sim/test/test_server.ml` | Server driven over real HTTP and websocket in expect tests |
| `venue-net/src/ws_client.mli` | Client contract: reconnect, backoff, watchdog, `Time_source` |
| `venue-net/test/test_ws_loopback.ml` | In-process websocket server for client tests |
| `hl-client/lib/ws.ml` | Venue client on top of `venue-net`, subscriptions resent on reconnect |

## Exercises

1. Add a `GET /health` route to a copy of `hl-sim/lib/server.ml` and test it on
   port 0 (expected: `200` and a body printed by the expect test).
2. In the `venue-net` loopback test, make the server drop the connection after the
   first frame and show that the client reconnects and `reconnects t` is 1.
3. Explain why `Http.Response.make`, not `Cohttp.Response.make`, is used for the
   101 response (answer: the latter adds `transfer-encoding: chunked`).

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
