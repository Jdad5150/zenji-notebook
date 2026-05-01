//! HTTP middleware for the zenji-notebook server.
//!
//! Each middleware follows the httpz convention: a struct with a pub Config,
//! an init(Config) function, and an execute(req, res, executor) method.
//! Calling executor.next() passes the request to the next middleware in the
//! chain, or to the route handler if none remain.
//!
//! Logger  - logs method, path, status, and elapsed time for every request.
//! Auth    - enforces token authentication via query param or session cookie.

const std = @import("std");
const httpz = @import("httpz");
const Token = @import("../auth/token.zig").Token;

const log = std.log.scoped(.request);

pub const Logger = struct {
    pub const Config = struct {};

    pub fn init(_: Config) !Logger {
        return .{};
    }

    pub fn execute(self: *const Logger, req: *httpz.Request, res: *httpz.Response, executor: anytype) !void {
        _ = self;
        try executor.next();
        log.info("{s} {s} {d}", .{ @tagName(req.method), req.url.path, res.status });
    }
};

pub const Auth = struct {
    token: *const Token,
    no_auth: bool,

    pub const Config = struct {
        token: *const Token,
        no_auth: bool,
    };

    pub fn init(config: Config) !Auth {
        return .{
            .token = config.token,
            .no_auth = config.no_auth,
        };
    }

    pub fn execute(self: *const Auth, req: *httpz.Request, res: *httpz.Response, executor: anytype) !void {
        if (self.no_auth) {
            return executor.next();
        }

        // Check session cookie first
        const cookies = req.cookies();
        if (cookies.get("token")) |cookie_token| {
            if (self.token.validate(cookie_token)) {
                return executor.next();
            }
        }

        // Check ?token= query param
        const query = try req.query();
        if (query.get("token")) |query_token| {
            if (self.token.validate(query_token)) {
                try res.setCookie("token", query_token, .{ .http_only = true });
                return executor.next();
            }
        }

        res.status = 401;
        res.body = "Unauthorized";
    }
};
